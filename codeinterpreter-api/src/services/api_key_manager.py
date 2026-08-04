"""API Key Manager Service.

Manages API keys stored in Redis with support for:
- Creating and revoking keys
- Rate limiting (hourly, daily, monthly)
- Usage tracking
- Backward compatibility with API_KEY env var
"""

import hashlib
import hmac
import secrets
from datetime import datetime, timezone, timedelta
from typing import Optional, Tuple, List, Dict

import redis.asyncio as redis
import structlog

from ..config import settings
from ..core.pool import redis_pool
from ..models.api_key import (
    ApiKeyRecord,
    RateLimits,
    RateLimitStatus,
    KeyValidationResult,
)

logger = structlog.get_logger(__name__)


class ApiKeyManagerService:
    """Manages API keys stored in Redis."""

    # Redis key prefixes
    RECORD_PREFIX = "api_keys:records:"
    VALID_CACHE_PREFIX = "api_keys:valid:"
    USAGE_PREFIX = "api_keys:usage:"
    INDEX_KEY = "api_keys:index"
    ENV_KEYS_INDEX = "api_keys:env_index"  # Separate index for env keys

    # Cache TTL
    VALIDATION_CACHE_TTL = 300  # 5 minutes

    def __init__(self, redis_client: Optional[redis.Redis] = None):
        """Initialize the API key manager.

        Args:
            redis_client: Optional Redis client, uses shared pool if not provided
        """
        self._redis = redis_client

    @property
    def redis(self) -> redis.Redis:
        """Get Redis client, initializing if needed."""
        if self._redis is None:
            self._redis = redis_pool.get_client()
        return self._redis

    def _hash_key(self, api_key: str) -> str:
        """Hash an API key using SHA256."""
        return hashlib.sha256(api_key.encode()).hexdigest()

    def _short_hash(self, key_hash: str) -> str:
        """Get short version of hash for caching."""
        return key_hash[:16]

    async def ensure_env_key_records(self) -> List[ApiKeyRecord]:
        """Ensure env key records exist in Redis for visibility.

        Creates or updates records for API_KEY and API_KEYS env vars.
        These are read-only records for dashboard visibility.

        Returns:
            List of env key records
        """
        env_records = []

        # Primary API_KEY
        primary_key = settings.api_key
        if primary_key and primary_key != "test-api-key":
            record = await self._ensure_single_env_key_record(
                primary_key, "Environment Key (API_KEY)"
            )
            if record:
                env_records.append(record)

        # Additional API_KEYS
        additional_keys = settings.get_valid_api_keys()
        for idx, key in enumerate(additional_keys):
            name = f"Environment Key (API_KEYS #{idx + 1})"
            record = await self._ensure_single_env_key_record(key, name)
            if record:
                env_records.append(record)

        return env_records

    async def _ensure_single_env_key_record(
        self, api_key: str, name: str
    ) -> Optional[ApiKeyRecord]:
        """Create or update a single env key record.

        Args:
            api_key: The actual API key value
            name: Human-readable name for the key

        Returns:
            ApiKeyRecord or None on error
        """
        try:
            key_hash = self._hash_key(api_key)
            record_key = f"{self.RECORD_PREFIX}{key_hash}"

            # Check if record already exists
            existing = await self.redis.hgetall(record_key)

            if existing:
                # Update existing record to ensure it has correct source
                record = ApiKeyRecord.from_redis_hash(existing)
                if record.source != "environment":
                    record.source = "environment"
                    record.name = name
                    await self.redis.hset(record_key, mapping=record.to_redis_hash())
                return record

            # Create new record
            record = ApiKeyRecord(
                key_hash=key_hash,
                key_prefix=api_key[:11] if len(api_key) >= 11 else api_key,
                name=name,
                created_at=datetime.now(timezone.utc),
                enabled=True,
                rate_limits=RateLimits(),  # Unlimited
                metadata={"type": "environment"},
                source="environment",
            )

            # Store in Redis
            pipe = self.redis.pipeline(transaction=True)
            pipe.hset(record_key, mapping=record.to_redis_hash())
            pipe.sadd(self.ENV_KEYS_INDEX, key_hash)
            await pipe.execute()

            logger.info(
                "Created env key record for visibility",
                name=name,
                key_prefix=record.key_prefix,
            )

            return record

        except Exception as e:
            logger.warning("Failed to ensure env key record", name=name, error=str(e))
            return None

    async def get_env_key_records(self) -> List[ApiKeyRecord]:
        """Get all env key records.

        Returns:
            List of env key records
        """
        try:
            key_hashes = await self.redis.smembers(self.ENV_KEYS_INDEX)
            records = []

            for key_hash in key_hashes:
                hash_str = (
                    key_hash.decode() if isinstance(key_hash, bytes) else key_hash
                )
                record = await self.get_key(hash_str)
                if record:
                    records.append(record)

            return records
        except Exception as e:
            logger.warning("Failed to get env key records", error=str(e))
            return []

    async def increment_env_key_usage(self, key_hash: str) -> None:
        """Increment usage counters for an env key.

        Similar to increment_usage but handles env keys that may not have
        a record yet (creates minimal tracking).

        Args:
            key_hash: Full SHA256 hash of the key
        """
        now = datetime.now(timezone.utc)
        record_key = f"{self.RECORD_PREFIX}{key_hash}"

        try:
            # Check if record exists
            exists = await self.redis.exists(record_key)

            if exists:
                # Update usage count and last_used_at
                pipe = self.redis.pipeline(transaction=False)
                pipe.hincrby(record_key, "usage_count", 1)
                pipe.hset(record_key, "last_used_at", now.isoformat())
                await pipe.execute()
            else:
                # Record doesn't exist yet - ensure it gets created
                await self.ensure_env_key_records()
                # Try to update again
                exists = await self.redis.exists(record_key)
                if exists:
                    pipe = self.redis.pipeline(transaction=False)
                    pipe.hincrby(record_key, "usage_count", 1)
                    pipe.hset(record_key, "last_used_at", now.isoformat())
                    await pipe.execute()

        except Exception as e:
            logger.warning("Failed to increment env key usage", error=str(e))

    async def create_key(
        self,
        name: str,
        rate_limits: Optional[RateLimits] = None,
        metadata: Optional[Dict[str, str]] = None,
    ) -> Tuple[str, ApiKeyRecord]:
        """Create a new API key.

        Args:
            name: Human-readable name for the key
            rate_limits: Optional rate limits (default: unlimited)
            metadata: Optional metadata dict

        Returns:
            Tuple of (full_api_key, ApiKeyRecord)
        """
        # Generate secure API key: sk-{32 random chars}
        random_part = secrets.token_urlsafe(24)  # 32 chars base64
        full_key = f"sk-{random_part}"

        # Create record
        key_hash = self._hash_key(full_key)
        record = ApiKeyRecord(
            key_hash=key_hash,
            key_prefix=full_key[:11],  # "sk-" + first 8 chars
            name=name,
            created_at=datetime.now(timezone.utc),
            enabled=True,
            rate_limits=rate_limits or RateLimits(),
            metadata=metadata or {},
        )

        # Store in Redis
        record_key = f"{self.RECORD_PREFIX}{key_hash}"
        pipe = self.redis.pipeline(transaction=True)
        pipe.hset(record_key, mapping=record.to_redis_hash())
        pipe.sadd(self.INDEX_KEY, key_hash)
        await pipe.execute()

        logger.info(
            "Created API key",
            name=name,
            key_prefix=record.key_prefix,
            rate_limits=rate_limits.to_dict() if rate_limits else "unlimited",
        )

        return full_key, record

    async def get_key(self, key_hash: str) -> Optional[ApiKeyRecord]:
        """Get API key record by hash.

        Args:
            key_hash: Full SHA256 hash of the key

        Returns:
            ApiKeyRecord or None if not found
        """
        record_key = f"{self.RECORD_PREFIX}{key_hash}"
        data = await self.redis.hgetall(record_key)

        if not data:
            return None

        return ApiKeyRecord.from_redis_hash(data)

    async def list_keys(self, include_env_keys: bool = True) -> List[ApiKeyRecord]:
        """List all API keys (without the actual key values).

        Args:
            include_env_keys: Whether to include environment key records

        Returns:
            List of ApiKeyRecord objects
        """
        key_hashes = await self.redis.smembers(self.INDEX_KEY)
        records = []

        for key_hash in key_hashes:
            hash_str = key_hash.decode() if isinstance(key_hash, bytes) else key_hash
            record = await self.get_key(hash_str)
            if record:
                records.append(record)

        # Include env keys if requested
        if include_env_keys:
            env_records = await self.get_env_key_records()
            # Add env records that aren't already in the list
            existing_hashes = {r.key_hash for r in records}
            for env_record in env_records:
                if env_record.key_hash not in existing_hashes:
                    records.append(env_record)

        # Sort by source (env keys first), then created_at descending
        records.sort(
            key=lambda r: (r.source != "environment", r.created_at), reverse=False
        )
        records.sort(key=lambda r: r.created_at, reverse=True)
        return records

    async def update_key(
        self,
        key_hash: str,
        enabled: Optional[bool] = None,
        rate_limits: Optional[RateLimits] = None,
        name: Optional[str] = None,
    ) -> bool:
        """Update API key properties.

        Args:
            key_hash: Full SHA256 hash of the key
            enabled: New enabled state (optional)
            rate_limits: New rate limits (optional)
            name: New name (optional)

        Returns:
            True if key was updated, False if key not found
        """
        record = await self.get_key(key_hash)
        if not record:
            return False

        # Update fields
        if enabled is not None:
            record.enabled = enabled
        if rate_limits is not None:
            record.rate_limits = rate_limits
        if name is not None:
            record.name = name

        # Save back to Redis
        record_key = f"{self.RECORD_PREFIX}{key_hash}"
        await self.redis.hset(record_key, mapping=record.to_redis_hash())

        # Invalidate validation cache
        await self.redis.delete(
            f"{self.VALID_CACHE_PREFIX}{self._short_hash(key_hash)}"
        )

        logger.info("Updated API key", key_prefix=record.key_prefix)
        return True

    async def revoke_key(self, key_hash: str) -> bool:
        """Revoke (delete) an API key.

        Args:
            key_hash: Full SHA256 hash of the key

        Returns:
            True if key was revoked, False if key not found
        """
        record_key = f"{self.RECORD_PREFIX}{key_hash}"

        # Check if key exists
        exists = await self.redis.exists(record_key)
        if not exists:
            return False

        # Delete from Redis
        pipe = self.redis.pipeline(transaction=True)
        pipe.delete(record_key)
        pipe.srem(self.INDEX_KEY, key_hash)
        pipe.delete(f"{self.VALID_CACHE_PREFIX}{self._short_hash(key_hash)}")
        await pipe.execute()

        logger.info("Revoked API key", key_hash=key_hash[:16])
        return True

    async def find_key_by_prefix(self, prefix: str) -> Optional[str]:
        """Find a key hash by its prefix.

        Args:
            prefix: Key prefix (e.g., "sk-abc123")

        Returns:
            Full key hash or None if not found
        """
        key_hashes = await self.redis.smembers(self.INDEX_KEY)

        for key_hash in key_hashes:
            hash_str = key_hash.decode() if isinstance(key_hash, bytes) else key_hash
            record = await self.get_key(hash_str)
            if record and record.key_prefix == prefix:
                return hash_str

        return None

    async def validate_key(self, api_key: str) -> KeyValidationResult:
        """Validate an API key.

        Checks Redis-managed keys first, then falls back to env var.

        Args:
            api_key: The API key to validate

        Returns:
            KeyValidationResult with validation details
        """
        if not api_key:
            return KeyValidationResult(
                is_valid=False, error_message="API key is required"
            )

        key_hash = self._hash_key(api_key)
        short_hash = self._short_hash(key_hash)

        # Check validation cache first
        cache_key = f"{self.VALID_CACHE_PREFIX}{short_hash}"
        try:
            cached = await self.redis.get(cache_key)
            if cached is not None:
                if cached == b"1" or cached == "1":
                    # Cache hit - key is valid, get record
                    record = await self.get_key(key_hash)
                    if record and record.enabled:
                        return KeyValidationResult(
                            is_valid=True,
                            key_hash=key_hash,
                            key_record=record,
                            is_env_key=False,
                        )
                elif cached == b"env" or cached == "env":
                    # Cache hit - this is the env var key
                    return KeyValidationResult(
                        is_valid=True, key_hash=key_hash, is_env_key=True
                    )
        except Exception as e:
            logger.warning("Failed to check validation cache", error=str(e))

        # Check Redis-managed keys
        record = await self.get_key(key_hash)
        if record:
            if record.enabled:
                # Cache the validation result
                await self._cache_validation(short_hash, "1")
                return KeyValidationResult(
                    is_valid=True,
                    key_hash=key_hash,
                    key_record=record,
                    is_env_key=False,
                )
            else:
                return KeyValidationResult(
                    is_valid=False,
                    key_hash=key_hash,
                    error_message="API key is disabled",
                )

        # Fall back to env var API_KEY (backward compatibility)
        env_key = settings.api_key
        if env_key and hmac.compare_digest(api_key, env_key):
            # Cache that this is the env key
            await self._cache_validation(short_hash, "env")
            return KeyValidationResult(
                is_valid=True, key_hash=key_hash, is_env_key=True
            )

        # Also check API_KEYS env var if set
        additional_keys = settings.get_valid_api_keys()
        for valid_key in additional_keys:
            if hmac.compare_digest(api_key, valid_key):
                await self._cache_validation(short_hash, "env")
                return KeyValidationResult(
                    is_valid=True, key_hash=key_hash, is_env_key=True
                )

        return KeyValidationResult(is_valid=False, error_message="Invalid API key")

    async def _cache_validation(self, short_hash: str, value: str) -> None:
        """Cache validation result."""
        try:
            cache_key = f"{self.VALID_CACHE_PREFIX}{short_hash}"
            await self.redis.setex(cache_key, self.VALIDATION_CACHE_TTL, value)
        except Exception as e:
            logger.warning("Failed to cache validation", error=str(e))

    async def check_rate_limits(
        self, key_hash: str
    ) -> Tuple[bool, Optional[RateLimitStatus]]:
        """Check if an API key has exceeded any rate limits.

        Args:
            key_hash: Full SHA256 hash of the key

        Returns:
            Tuple of (is_allowed, exceeded_status)
            If is_allowed is False, exceeded_status contains the exceeded limit
        """
        record = await self.get_key(key_hash)
        if not record:
            return True, None  # Key not found in Redis = env var key = unlimited

        if record.rate_limits.is_unlimited():
            return True, None

        now = datetime.now(timezone.utc)

        # Check each rate limit period (shortest first for fail-fast)
        checks = []
        if record.rate_limits.per_second is not None:
            checks.append(
                ("per_second", record.rate_limits.per_second, self._get_second_key(now))
            )
        if record.rate_limits.per_minute is not None:
            checks.append(
                ("per_minute", record.rate_limits.per_minute, self._get_minute_key(now))
            )
        if record.rate_limits.hourly is not None:
            checks.append(
                ("hourly", record.rate_limits.hourly, self._get_hour_key(now))
            )
        if record.rate_limits.daily is not None:
            checks.append(("daily", record.rate_limits.daily, self._get_day_key(now)))
        if record.rate_limits.monthly is not None:
            checks.append(
                ("monthly", record.rate_limits.monthly, self._get_month_key(now))
            )

        short_hash = self._short_hash(key_hash)

        for period, limit, period_key in checks:
            usage_key = f"{self.USAGE_PREFIX}{short_hash}:{period_key}"
            try:
                used_bytes = await self.redis.get(usage_key)
                used = int(used_bytes.decode()) if used_bytes else 0

                if used >= limit:
                    resets_at = self._get_reset_time(period, now)
                    return False, RateLimitStatus(
                        period=period,
                        limit=limit,
                        used=used,
                        remaining=0,
                        resets_at=resets_at,
                        is_exceeded=True,
                    )
            except Exception as e:
                logger.warning(
                    "Failed to check rate limit", period=period, error=str(e)
                )

        return True, None

    async def get_rate_limit_status(self, key_hash: str) -> List[RateLimitStatus]:
        """Get current rate limit status for all periods.

        Args:
            key_hash: Full SHA256 hash of the key

        Returns:
            List of RateLimitStatus for each configured limit
        """
        record = await self.get_key(key_hash)
        if not record:
            return []

        now = datetime.now(timezone.utc)
        short_hash = self._short_hash(key_hash)
        statuses = []

        periods = [
            ("per_second", record.rate_limits.per_second, self._get_second_key(now)),
            ("per_minute", record.rate_limits.per_minute, self._get_minute_key(now)),
            ("hourly", record.rate_limits.hourly, self._get_hour_key(now)),
            ("daily", record.rate_limits.daily, self._get_day_key(now)),
            ("monthly", record.rate_limits.monthly, self._get_month_key(now)),
        ]

        for period, limit, period_key in periods:
            usage_key = f"{self.USAGE_PREFIX}{short_hash}:{period_key}"
            try:
                used_bytes = await self.redis.get(usage_key)
                used = int(used_bytes.decode()) if used_bytes else 0
            except Exception:
                used = 0

            remaining = None if limit is None else max(0, limit - used)
            resets_at = self._get_reset_time(period, now)

            statuses.append(
                RateLimitStatus(
                    period=period,
                    limit=limit,
                    used=used,
                    remaining=remaining,
                    resets_at=resets_at,
                    is_exceeded=limit is not None and used >= limit,
                )
            )

        return statuses

    async def increment_usage(self, key_hash: str) -> None:
        """Increment usage counters for all periods.

        Args:
            key_hash: Full SHA256 hash of the key
        """
        now = datetime.now(timezone.utc)
        short_hash = self._short_hash(key_hash)

        # Update counters for all periods
        periods = [
            (self._get_second_key(now), 2),  # 2 seconds TTL
            (self._get_minute_key(now), 120),  # 2 minutes TTL
            (self._get_hour_key(now), 7200),  # 2 hours TTL
            (self._get_day_key(now), 172800),  # 2 days TTL
            (self._get_month_key(now), 2764800),  # 32 days TTL
        ]

        pipe = self.redis.pipeline(transaction=False)
        for period_key, ttl in periods:
            usage_key = f"{self.USAGE_PREFIX}{short_hash}:{period_key}"
            pipe.incr(usage_key)
            pipe.expire(usage_key, ttl)

        # Also update the record's usage_count and last_used_at
        record_key = f"{self.RECORD_PREFIX}{key_hash}"
        pipe.hincrby(record_key, "usage_count", 1)
        pipe.hset(record_key, "last_used_at", now.isoformat())

        try:
            await pipe.execute()
        except Exception as e:
            logger.warning("Failed to increment usage", error=str(e))

    async def get_usage(self, key_hash: str) -> Dict[str, int]:
        """Get current usage for all periods.

        Args:
            key_hash: Full SHA256 hash of the key

        Returns:
            Dict with per_second, per_minute, hourly, daily, monthly usage counts
        """
        now = datetime.now(timezone.utc)
        short_hash = self._short_hash(key_hash)

        result = {
            "per_second": 0,
            "per_minute": 0,
            "hourly": 0,
            "daily": 0,
            "monthly": 0,
        }

        periods = [
            ("per_second", self._get_second_key(now)),
            ("per_minute", self._get_minute_key(now)),
            ("hourly", self._get_hour_key(now)),
            ("daily", self._get_day_key(now)),
            ("monthly", self._get_month_key(now)),
        ]

        for period, period_key in periods:
            usage_key = f"{self.USAGE_PREFIX}{short_hash}:{period_key}"
            try:
                used = await self.redis.get(usage_key)
                if used:
                    # Handle both bytes and string responses
                    if isinstance(used, bytes):
                        result[period] = int(used.decode())
                    else:
                        result[period] = int(used)
            except Exception:
                pass

        return result

    def _get_second_key(self, dt: datetime) -> str:
        """Get Redis key suffix for per-second period."""
        return f"second:{dt.strftime('%Y-%m-%d-%H:%M:%S')}"

    def _get_minute_key(self, dt: datetime) -> str:
        """Get Redis key suffix for per-minute period."""
        return f"minute:{dt.strftime('%Y-%m-%d-%H:%M')}"

    def _get_hour_key(self, dt: datetime) -> str:
        """Get Redis key suffix for hourly period."""
        return f"hour:{dt.strftime('%Y-%m-%d-%H')}"

    def _get_day_key(self, dt: datetime) -> str:
        """Get Redis key suffix for daily period."""
        return f"day:{dt.strftime('%Y-%m-%d')}"

    def _get_month_key(self, dt: datetime) -> str:
        """Get Redis key suffix for monthly period."""
        return f"month:{dt.strftime('%Y-%m')}"

    def _get_reset_time(self, period: str, now: datetime) -> datetime:
        """Get the reset time for a rate limit period."""
        if period == "per_second":
            return now.replace(microsecond=0) + timedelta(seconds=1)
        elif period == "per_minute":
            return now.replace(second=0, microsecond=0) + timedelta(minutes=1)
        elif period == "hourly":
            return now.replace(minute=0, second=0, microsecond=0) + timedelta(hours=1)
        elif period == "daily":
            return now.replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(
                days=1
            )
        elif period == "monthly":
            # First day of next month
            if now.month == 12:
                return now.replace(
                    year=now.year + 1,
                    month=1,
                    day=1,
                    hour=0,
                    minute=0,
                    second=0,
                    microsecond=0,
                )
            else:
                return now.replace(
                    month=now.month + 1,
                    day=1,
                    hour=0,
                    minute=0,
                    second=0,
                    microsecond=0,
                )
        return now


# Global service instance
_api_key_manager: Optional[ApiKeyManagerService] = None


async def get_api_key_manager() -> ApiKeyManagerService:
    """Get or create API key manager instance."""
    global _api_key_manager

    if _api_key_manager is None:
        redis_client = redis_pool.get_client()
        _api_key_manager = ApiKeyManagerService(redis_client)
        logger.info("Initialized API key manager service")

        # Ensure env key records exist for dashboard visibility
        try:
            await _api_key_manager.ensure_env_key_records()
        except Exception as e:
            logger.warning("Failed to ensure env key records on startup", error=str(e))

    return _api_key_manager
