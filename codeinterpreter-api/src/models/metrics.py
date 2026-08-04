"""Extended metrics data models for detailed usage tracking.

These models extend the basic metrics with additional dimensions:
- Per-API-key tracking
- Per-language breakdown
- Container pool metrics
- Detailed resource consumption
"""

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Dict, Any, Optional, List
from enum import Enum


class AggregationPeriod(str, Enum):
    """Time period for metrics aggregation."""

    HOURLY = "hourly"
    DAILY = "daily"
    MONTHLY = "monthly"


class ContainerSource(str, Enum):
    """Source of container for execution."""

    POOL_HIT = "pool_hit"  # Container from warm pool
    POOL_MISS = "pool_miss"  # Created fresh (pool exhausted or disabled)
    POOL_DISABLED = "pool_disabled"  # Pool is disabled


class ExecutionStatus(str, Enum):
    """Execution result status."""

    COMPLETED = "completed"
    FAILED = "failed"
    TIMEOUT = "timeout"


@dataclass
class DetailedExecutionMetrics:
    """Per-execution metrics with all dimensions for tracking.

    This extends the basic ExecutionMetrics with additional fields
    for per-key and per-language analytics.
    """

    execution_id: str
    session_id: str
    api_key_hash: str  # SHA256 hash (first 16 chars) for grouping
    user_id: Optional[str]  # From request
    entity_id: Optional[str]  # From request
    language: str
    status: str  # completed, failed, timeout
    execution_time_ms: float
    memory_peak_mb: Optional[float] = None
    cpu_time_ms: Optional[float] = None
    container_source: str = "pool_hit"  # pool_hit, pool_miss, pool_disabled
    repl_mode: bool = False
    files_uploaded: int = 0
    files_generated: int = 0
    output_size_bytes: int = 0
    state_size_bytes: Optional[int] = None
    timestamp: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "execution_id": self.execution_id,
            "session_id": self.session_id,
            "api_key_hash": self.api_key_hash,
            "user_id": self.user_id,
            "entity_id": self.entity_id,
            "language": self.language,
            "status": self.status,
            "execution_time_ms": self.execution_time_ms,
            "memory_peak_mb": self.memory_peak_mb,
            "cpu_time_ms": self.cpu_time_ms,
            "container_source": self.container_source,
            "repl_mode": self.repl_mode,
            "files_uploaded": self.files_uploaded,
            "files_generated": self.files_generated,
            "output_size_bytes": self.output_size_bytes,
            "state_size_bytes": self.state_size_bytes,
            "timestamp": self.timestamp.isoformat(),
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "DetailedExecutionMetrics":
        """Create from dictionary."""
        timestamp = data.get("timestamp")
        if isinstance(timestamp, str):
            timestamp = datetime.fromisoformat(timestamp)
        elif timestamp is None:
            timestamp = datetime.now(timezone.utc)

        return cls(
            execution_id=data["execution_id"],
            session_id=data["session_id"],
            api_key_hash=data.get("api_key_hash", "unknown"),
            user_id=data.get("user_id"),
            entity_id=data.get("entity_id"),
            language=data["language"],
            status=data["status"],
            execution_time_ms=data["execution_time_ms"],
            memory_peak_mb=data.get("memory_peak_mb"),
            cpu_time_ms=data.get("cpu_time_ms"),
            container_source=data.get("container_source", "pool_hit"),
            repl_mode=data.get("repl_mode", False),
            files_uploaded=data.get("files_uploaded", 0),
            files_generated=data.get("files_generated", 0),
            output_size_bytes=data.get("output_size_bytes", 0),
            state_size_bytes=data.get("state_size_bytes"),
            timestamp=timestamp,
        )


@dataclass
class LanguageMetrics:
    """Per-language aggregated metrics."""

    language: str
    execution_count: int = 0
    success_count: int = 0
    failure_count: int = 0
    timeout_count: int = 0
    total_execution_time_ms: float = 0
    total_memory_mb: float = 0
    avg_execution_time_ms: float = 0
    avg_memory_mb: float = 0
    error_rate: float = 0.0  # Percentage (0-100)
    repl_mode_count: int = 0  # Executions using REPL

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "language": self.language,
            "execution_count": self.execution_count,
            "success_count": self.success_count,
            "failure_count": self.failure_count,
            "timeout_count": self.timeout_count,
            "total_execution_time_ms": self.total_execution_time_ms,
            "total_memory_mb": self.total_memory_mb,
            "avg_execution_time_ms": self.avg_execution_time_ms,
            "avg_memory_mb": self.avg_memory_mb,
            "error_rate": self.error_rate,
            "repl_mode_count": self.repl_mode_count,
        }


@dataclass
class ApiKeyUsageMetrics:
    """Per-API-key aggregated metrics."""

    api_key_hash: str
    execution_count: int = 0
    success_count: int = 0
    failure_count: int = 0
    total_execution_time_ms: float = 0
    total_memory_mb: float = 0
    file_operations: int = 0
    success_rate: float = 100.0  # Percentage (0-100)

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "api_key_hash": self.api_key_hash,
            "execution_count": self.execution_count,
            "success_count": self.success_count,
            "failure_count": self.failure_count,
            "total_execution_time_ms": self.total_execution_time_ms,
            "total_memory_mb": self.total_memory_mb,
            "file_operations": self.file_operations,
            "success_rate": self.success_rate,
        }


@dataclass
class PoolMetricsSummary:
    """Container pool metrics."""

    total_acquisitions: int = 0
    pool_hits: int = 0
    pool_misses: int = 0
    hit_rate: float = 0.0  # Percentage (0-100)
    avg_acquire_time_ms: float = 0
    exhaustion_events: int = 0  # Times pool was empty when needed

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "total_acquisitions": self.total_acquisitions,
            "pool_hits": self.pool_hits,
            "pool_misses": self.pool_misses,
            "hit_rate": self.hit_rate,
            "avg_acquire_time_ms": self.avg_acquire_time_ms,
            "exhaustion_events": self.exhaustion_events,
        }


@dataclass
class AggregatedMetrics:
    """Aggregated metrics for a time period."""

    period: str  # ISO format: "2025-12-20T14:00:00Z"
    period_type: str  # hourly, daily, monthly
    execution_count: int = 0
    success_count: int = 0
    failure_count: int = 0
    timeout_count: int = 0
    total_execution_time_ms: float = 0
    avg_execution_time_ms: float = 0
    p50_execution_time_ms: float = 0
    p95_execution_time_ms: float = 0
    p99_execution_time_ms: float = 0
    total_memory_mb: float = 0
    avg_memory_mb: float = 0
    by_language: Dict[str, LanguageMetrics] = field(default_factory=dict)
    by_api_key: Dict[str, ApiKeyUsageMetrics] = field(default_factory=dict)
    pool_stats: Optional[PoolMetricsSummary] = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "period": self.period,
            "period_type": self.period_type,
            "execution_count": self.execution_count,
            "success_count": self.success_count,
            "failure_count": self.failure_count,
            "timeout_count": self.timeout_count,
            "total_execution_time_ms": self.total_execution_time_ms,
            "avg_execution_time_ms": self.avg_execution_time_ms,
            "p50_execution_time_ms": self.p50_execution_time_ms,
            "p95_execution_time_ms": self.p95_execution_time_ms,
            "p99_execution_time_ms": self.p99_execution_time_ms,
            "total_memory_mb": self.total_memory_mb,
            "avg_memory_mb": self.avg_memory_mb,
            "by_language": {k: v.to_dict() for k, v in self.by_language.items()},
            "by_api_key": {k: v.to_dict() for k, v in self.by_api_key.items()},
            "pool_stats": self.pool_stats.to_dict() if self.pool_stats else None,
        }


@dataclass
class MetricsSummary:
    """High-level metrics summary for dashboard/status."""

    total_executions: int = 0
    total_executions_today: int = 0
    total_executions_hour: int = 0
    success_rate: float = 100.0
    avg_execution_time_ms: float = 0
    active_api_keys: int = 0
    top_languages: List[Dict[str, Any]] = field(default_factory=list)
    pool_hit_rate: float = 0.0

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "total_executions": self.total_executions,
            "total_executions_today": self.total_executions_today,
            "total_executions_hour": self.total_executions_hour,
            "success_rate": self.success_rate,
            "avg_execution_time_ms": self.avg_execution_time_ms,
            "active_api_keys": self.active_api_keys,
            "top_languages": self.top_languages,
            "pool_hit_rate": self.pool_hit_rate,
        }
