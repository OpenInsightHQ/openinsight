"""Detailed Metrics Service.

Provides extended metrics tracking with:
- Per-API-key usage tracking
- Per-language breakdown
- Container pool metrics
- Hourly/daily aggregation with Redis storage
"""

import json
from datetime import datetime, timezone, timedelta
from typing import Optional, List, Dict, Any

import redis.asyncio as redis
import structlog

from ..config import settings
from ..core.pool import redis_pool
from ..models.metrics import (
    DetailedExecutionMetrics,
    LanguageMetrics,
    ApiKeyUsageMetrics,
    PoolMetricsSummary,
    AggregatedMetrics,
    MetricsSummary,
)

logger = structlog.get_logger(__name__)


class DetailedMetricsService:
    """Service for collecting and querying detailed execution metrics."""

    # Redis key prefixes
    BUFFER_KEY = "metrics:detailed:buffer"
    HOURLY_PREFIX = "metrics:detailed:hourly:"
    DAILY_PREFIX = "metrics:detailed:daily:"
    POOL_STATS_KEY = "metrics:pool:stats"
    API_KEY_HOURLY_PREFIX = "metrics:api_key:"

    # Buffer and retention settings
    MAX_BUFFER_SIZE = 10000
    HOURLY_TTL = 7 * 24 * 3600  # 7 days
    DAILY_TTL = 30 * 24 * 3600  # 30 days

    def __init__(self, redis_client: Optional[redis.Redis] = None):
        """Initialize the detailed metrics service.

        Args:
            redis_client: Optional Redis client, uses shared pool if not provided
        """
        self._redis = redis_client
        self._in_memory_buffer: List[DetailedExecutionMetrics] = []

    def register_event_handlers(self) -> None:
        """Register event handlers for pool metrics."""
        from ..core.events import (
            event_bus,
            ContainerAcquiredFromPool,
            ContainerCreatedFresh,
            PoolExhausted,
        )

        @event_bus.subscribe(ContainerAcquiredFromPool)
        async def handle_pool_hit(event: ContainerAcquiredFromPool):
            await self.record_pool_event(
                event_type="hit",
                language=event.language,
                acquire_time_ms=event.acquire_time_ms,
            )

        @event_bus.subscribe(ContainerCreatedFresh)
        async def handle_pool_miss(event: ContainerCreatedFresh):
            if event.reason in ("pool_empty", "pool_disabled"):
                await self.record_pool_event(event_type="miss", language=event.language)

        @event_bus.subscribe(PoolExhausted)
        async def handle_pool_exhaustion(event: PoolExhausted):
            await self.record_pool_event(
                event_type="exhaustion", language=event.language
            )

        logger.info("Registered pool event handlers for metrics")

    @property
    def redis(self) -> redis.Redis:
        """Get Redis client, initializing if needed."""
        if self._redis is None:
            self._redis = redis_pool.get_client()
        return self._redis

    async def record_execution(self, metrics: DetailedExecutionMetrics) -> None:
        """Record a detailed execution metric.

        Args:
            metrics: The execution metrics to record
        """
        if not settings.detailed_metrics_enabled:
            return

        try:
            # Add to Redis buffer
            await self.redis.lpush(self.BUFFER_KEY, json.dumps(metrics.to_dict()))

            # Trim buffer to max size
            await self.redis.ltrim(self.BUFFER_KEY, 0, self.MAX_BUFFER_SIZE - 1)

            # Update hourly aggregates
            await self._update_hourly_aggregates(metrics)

            # Update per-API-key metrics
            if metrics.api_key_hash:
                await self._update_api_key_metrics(metrics)

            # Forward to SQLite for persistent storage
            if settings.sqlite_metrics_enabled:
                try:
                    from .sqlite_metrics import sqlite_metrics_service

                    await sqlite_metrics_service.record_execution(metrics)
                except Exception as sqlite_err:
                    logger.warning(
                        "Failed to record metrics to SQLite",
                        error=str(sqlite_err),
                    )

            logger.debug(
                "Recorded detailed metrics",
                execution_id=metrics.execution_id,
                language=metrics.language,
                api_key_hash=(
                    metrics.api_key_hash[:8] if metrics.api_key_hash else "unknown"
                ),
            )

        except Exception as e:
            logger.warning("Failed to record detailed metrics", error=str(e))
            # Fall back to in-memory buffer
            self._in_memory_buffer.append(metrics)
            if len(self._in_memory_buffer) > self.MAX_BUFFER_SIZE:
                self._in_memory_buffer = self._in_memory_buffer[-self.MAX_BUFFER_SIZE :]

    async def _update_hourly_aggregates(
        self, metrics: DetailedExecutionMetrics
    ) -> None:
        """Update hourly aggregate counters."""
        hour_key = self._get_hour_key(metrics.timestamp)
        redis_key = f"{self.HOURLY_PREFIX}{hour_key}"

        pipe = self.redis.pipeline(transaction=False)

        # Increment counters
        pipe.hincrby(redis_key, "execution_count", 1)
        pipe.hincrbyfloat(
            redis_key, "total_execution_time_ms", metrics.execution_time_ms
        )

        if metrics.status == "completed":
            pipe.hincrby(redis_key, "success_count", 1)
        elif metrics.status == "failed":
            pipe.hincrby(redis_key, "failure_count", 1)
        elif metrics.status == "timeout":
            pipe.hincrby(redis_key, "timeout_count", 1)

        if metrics.memory_peak_mb:
            pipe.hincrbyfloat(redis_key, "total_memory_mb", metrics.memory_peak_mb)

        # Per-language counters
        lang_key = f"lang:{metrics.language}:count"
        lang_time_key = f"lang:{metrics.language}:time_ms"
        pipe.hincrby(redis_key, lang_key, 1)
        pipe.hincrbyfloat(redis_key, lang_time_key, metrics.execution_time_ms)

        if metrics.status != "completed":
            lang_error_key = f"lang:{metrics.language}:errors"
            pipe.hincrby(redis_key, lang_error_key, 1)

        # Container pool tracking
        if metrics.container_source == "pool_hit":
            pipe.hincrby(redis_key, "pool_hits", 1)
        elif metrics.container_source == "pool_miss":
            pipe.hincrby(redis_key, "pool_misses", 1)

        # Set TTL
        pipe.expire(redis_key, self.HOURLY_TTL)

        await pipe.execute()

    async def _update_api_key_metrics(self, metrics: DetailedExecutionMetrics) -> None:
        """Update per-API-key metrics."""
        hour_key = self._get_hour_key(metrics.timestamp)
        redis_key = (
            f"{self.API_KEY_HOURLY_PREFIX}{metrics.api_key_hash[:16]}:hour:{hour_key}"
        )

        pipe = self.redis.pipeline(transaction=False)
        pipe.hincrby(redis_key, "execution_count", 1)
        pipe.hincrbyfloat(
            redis_key, "total_execution_time_ms", metrics.execution_time_ms
        )

        if metrics.status == "completed":
            pipe.hincrby(redis_key, "success_count", 1)
        else:
            pipe.hincrby(redis_key, "failure_count", 1)

        if metrics.memory_peak_mb:
            pipe.hincrbyfloat(redis_key, "total_memory_mb", metrics.memory_peak_mb)

        file_ops = metrics.files_uploaded + metrics.files_generated
        if file_ops > 0:
            pipe.hincrby(redis_key, "file_operations", file_ops)

        pipe.expire(redis_key, 7200)  # 2 hours TTL

        await pipe.execute()

    async def record_pool_event(
        self, event_type: str, language: str, acquire_time_ms: Optional[float] = None
    ) -> None:
        """Record a container pool event.

        Args:
            event_type: Type of event (hit, miss, exhaustion)
            language: Language of container
            acquire_time_ms: Time to acquire container
        """
        try:
            pipe = self.redis.pipeline(transaction=False)

            if event_type == "hit":
                pipe.hincrby(self.POOL_STATS_KEY, "pool_hits", 1)
            elif event_type == "miss":
                pipe.hincrby(self.POOL_STATS_KEY, "pool_misses", 1)
            elif event_type == "exhaustion":
                pipe.hincrby(self.POOL_STATS_KEY, "exhaustion_events", 1)
                pipe.hset(
                    self.POOL_STATS_KEY,
                    "last_exhaustion",
                    datetime.now(timezone.utc).isoformat(),
                )

            pipe.hincrby(self.POOL_STATS_KEY, "total_acquisitions", 1)

            if acquire_time_ms:
                pipe.hincrbyfloat(
                    self.POOL_STATS_KEY, "total_acquire_time_ms", acquire_time_ms
                )

            await pipe.execute()

        except Exception as e:
            logger.warning("Failed to record pool event", error=str(e))

    async def get_hourly_metrics(
        self, hour: Optional[datetime] = None
    ) -> Optional[AggregatedMetrics]:
        """Get aggregated metrics for a specific hour.

        Args:
            hour: The hour to get metrics for (default: current hour)

        Returns:
            AggregatedMetrics or None if no data
        """
        if hour is None:
            hour = datetime.now(timezone.utc)

        hour_key = self._get_hour_key(hour)
        redis_key = f"{self.HOURLY_PREFIX}{hour_key}"

        try:
            data = await self.redis.hgetall(redis_key)
            if not data:
                return None

            return self._parse_hourly_data(data, hour_key, "hourly")

        except Exception as e:
            logger.error("Failed to get hourly metrics", error=str(e))
            return None

    async def get_metrics_range(
        self, start: datetime, end: datetime, period_type: str = "hourly"
    ) -> List[AggregatedMetrics]:
        """Get aggregated metrics for a time range.

        Args:
            start: Start of range
            end: End of range
            period_type: hourly or daily

        Returns:
            List of AggregatedMetrics
        """
        results = []

        if period_type == "hourly":
            current = start.replace(minute=0, second=0, microsecond=0)
            while current <= end:
                metrics = await self.get_hourly_metrics(current)
                if metrics:
                    results.append(metrics)
                current += timedelta(hours=1)

        return results

    async def get_language_stats(self, hours: int = 24) -> Dict[str, LanguageMetrics]:
        """Get per-language statistics for the last N hours.

        Args:
            hours: Number of hours to aggregate

        Returns:
            Dict mapping language code to LanguageMetrics
        """
        now = datetime.now(timezone.utc)
        language_stats: Dict[str, LanguageMetrics] = {}

        for i in range(hours):
            hour = now - timedelta(hours=i)
            hour_key = self._get_hour_key(hour)
            redis_key = f"{self.HOURLY_PREFIX}{hour_key}"

            try:
                data = await self.redis.hgetall(redis_key)
                if not data:
                    continue

                # Parse language-specific fields
                for key, value in data.items():
                    key_str = key.decode() if isinstance(key, bytes) else key
                    value_str = value.decode() if isinstance(value, bytes) else value

                    if key_str.startswith("lang:") and ":count" in key_str:
                        lang = key_str.split(":")[1]
                        if lang not in language_stats:
                            language_stats[lang] = LanguageMetrics(language=lang)

                        count = int(value_str)
                        language_stats[lang].execution_count += count

                        # Get corresponding time and error counts
                        time_key = f"lang:{lang}:time_ms"
                        error_key = f"lang:{lang}:errors"

                        time_data = data.get(
                            time_key.encode() if isinstance(key, bytes) else time_key
                        )
                        if time_data:
                            language_stats[lang].total_execution_time_ms += float(
                                time_data.decode()
                                if isinstance(time_data, bytes)
                                else time_data
                            )

                        error_data = data.get(
                            error_key.encode() if isinstance(key, bytes) else error_key
                        )
                        if error_data:
                            language_stats[lang].failure_count += int(
                                error_data.decode()
                                if isinstance(error_data, bytes)
                                else error_data
                            )

            except Exception as e:
                logger.warning(
                    "Failed to get language stats for hour", hour=hour_key, error=str(e)
                )

        # Calculate derived values
        for stats in language_stats.values():
            stats.success_count = stats.execution_count - stats.failure_count
            if stats.execution_count > 0:
                stats.avg_execution_time_ms = (
                    stats.total_execution_time_ms / stats.execution_count
                )
                stats.error_rate = (stats.failure_count / stats.execution_count) * 100

        return language_stats

    async def get_api_key_stats(
        self, api_key_hash: str, hours: int = 24
    ) -> ApiKeyUsageMetrics:
        """Get usage statistics for a specific API key.

        Args:
            api_key_hash: Hash of the API key
            hours: Number of hours to aggregate

        Returns:
            ApiKeyUsageMetrics
        """
        stats = ApiKeyUsageMetrics(api_key_hash=api_key_hash[:16])
        now = datetime.now(timezone.utc)

        for i in range(hours):
            hour = now - timedelta(hours=i)
            hour_key = self._get_hour_key(hour)
            redis_key = (
                f"{self.API_KEY_HOURLY_PREFIX}{api_key_hash[:16]}:hour:{hour_key}"
            )

            try:
                data = await self.redis.hgetall(redis_key)
                if not data:
                    continue

                for key, value in data.items():
                    key_str = key.decode() if isinstance(key, bytes) else key
                    value_str = value.decode() if isinstance(value, bytes) else value

                    if key_str == "execution_count":
                        stats.execution_count += int(value_str)
                    elif key_str == "success_count":
                        stats.success_count += int(value_str)
                    elif key_str == "failure_count":
                        stats.failure_count += int(value_str)
                    elif key_str == "total_execution_time_ms":
                        stats.total_execution_time_ms += float(value_str)
                    elif key_str == "total_memory_mb":
                        stats.total_memory_mb += float(value_str)
                    elif key_str == "file_operations":
                        stats.file_operations += int(value_str)

            except Exception as e:
                logger.warning("Failed to get API key stats", error=str(e))

        # Calculate success rate
        if stats.execution_count > 0:
            stats.success_rate = (stats.success_count / stats.execution_count) * 100

        return stats

    async def get_pool_stats(self) -> PoolMetricsSummary:
        """Get container pool statistics.

        Returns:
            PoolMetricsSummary
        """
        stats = PoolMetricsSummary()

        try:
            data = await self.redis.hgetall(self.POOL_STATS_KEY)
            if data:
                for key, value in data.items():
                    key_str = key.decode() if isinstance(key, bytes) else key
                    value_str = value.decode() if isinstance(value, bytes) else value

                    if key_str == "total_acquisitions":
                        stats.total_acquisitions = int(value_str)
                    elif key_str == "pool_hits":
                        stats.pool_hits = int(value_str)
                    elif key_str == "pool_misses":
                        stats.pool_misses = int(value_str)
                    elif key_str == "exhaustion_events":
                        stats.exhaustion_events = int(value_str)
                    elif key_str == "total_acquire_time_ms":
                        if stats.total_acquisitions > 0:
                            stats.avg_acquire_time_ms = (
                                float(value_str) / stats.total_acquisitions
                            )

                # Calculate hit rate
                if stats.total_acquisitions > 0:
                    stats.hit_rate = (stats.pool_hits / stats.total_acquisitions) * 100

        except Exception as e:
            logger.warning("Failed to get pool stats", error=str(e))

        return stats

    async def get_summary(self) -> MetricsSummary:
        """Get high-level metrics summary.

        Returns:
            MetricsSummary for dashboard display
        """
        summary = MetricsSummary()
        now = datetime.now(timezone.utc)

        try:
            # Get current hour stats
            current_hour = await self.get_hourly_metrics(now)
            if current_hour:
                summary.total_executions_hour = current_hour.execution_count
                summary.avg_execution_time_ms = current_hour.avg_execution_time_ms

            # Get today's stats (last 24 hours)
            for i in range(24):
                hour = now - timedelta(hours=i)
                hour_metrics = await self.get_hourly_metrics(hour)
                if hour_metrics:
                    summary.total_executions_today += hour_metrics.execution_count
                    summary.total_executions += hour_metrics.execution_count

            # Get language breakdown
            language_stats = await self.get_language_stats(hours=24)
            sorted_languages = sorted(
                language_stats.values(), key=lambda x: x.execution_count, reverse=True
            )[:5]
            summary.top_languages = [
                {"language": s.language, "count": s.execution_count}
                for s in sorted_languages
            ]

            # Get pool stats
            pool_stats = await self.get_pool_stats()
            summary.pool_hit_rate = pool_stats.hit_rate

            # Calculate overall success rate
            total_success = sum(s.success_count for s in language_stats.values())
            total_all = sum(s.execution_count for s in language_stats.values())
            if total_all > 0:
                summary.success_rate = (total_success / total_all) * 100

        except Exception as e:
            logger.error("Failed to get metrics summary", error=str(e))

        return summary

    def _get_hour_key(self, dt: datetime) -> str:
        """Get Redis key suffix for hourly period."""
        return dt.strftime("%Y-%m-%d-%H")

    def _get_day_key(self, dt: datetime) -> str:
        """Get Redis key suffix for daily period."""
        return dt.strftime("%Y-%m-%d")

    def _parse_hourly_data(
        self, data: Dict[bytes, bytes], period: str, period_type: str
    ) -> AggregatedMetrics:
        """Parse Redis hash data into AggregatedMetrics."""
        metrics = AggregatedMetrics(period=period, period_type=period_type)

        for key, value in data.items():
            key_str = key.decode() if isinstance(key, bytes) else key
            value_str = value.decode() if isinstance(value, bytes) else value

            if key_str == "execution_count":
                metrics.execution_count = int(value_str)
            elif key_str == "success_count":
                metrics.success_count = int(value_str)
            elif key_str == "failure_count":
                metrics.failure_count = int(value_str)
            elif key_str == "timeout_count":
                metrics.timeout_count = int(value_str)
            elif key_str == "total_execution_time_ms":
                metrics.total_execution_time_ms = float(value_str)
            elif key_str == "total_memory_mb":
                metrics.total_memory_mb = float(value_str)
            elif key_str == "pool_hits":
                if metrics.pool_stats is None:
                    metrics.pool_stats = PoolMetricsSummary()
                metrics.pool_stats.pool_hits = int(value_str)
            elif key_str == "pool_misses":
                if metrics.pool_stats is None:
                    metrics.pool_stats = PoolMetricsSummary()
                metrics.pool_stats.pool_misses = int(value_str)

        # Calculate averages
        if metrics.execution_count > 0:
            metrics.avg_execution_time_ms = (
                metrics.total_execution_time_ms / metrics.execution_count
            )
            metrics.avg_memory_mb = metrics.total_memory_mb / metrics.execution_count

        return metrics


# Global service instance
_detailed_metrics_service: Optional[DetailedMetricsService] = None


def get_detailed_metrics_service() -> DetailedMetricsService:
    """Get or create detailed metrics service instance."""
    global _detailed_metrics_service

    if _detailed_metrics_service is None:
        _detailed_metrics_service = DetailedMetricsService()
        _detailed_metrics_service.register_event_handlers()
        logger.info("Initialized detailed metrics service with event handlers")

    return _detailed_metrics_service
