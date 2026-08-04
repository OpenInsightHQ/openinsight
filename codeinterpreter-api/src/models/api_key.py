"""API key data models for key management and rate limiting."""

import json
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional, Dict, Any


@dataclass
class RateLimits:
    """Rate limits configuration for an API key.

    None values indicate unlimited (no rate limit for that period).
    """

    per_second: Optional[int] = None
    per_minute: Optional[int] = None
    hourly: Optional[int] = None
    daily: Optional[int] = None
    monthly: Optional[int] = None

    def is_unlimited(self) -> bool:
        """Check if all rate limits are unlimited."""
        return (
            self.per_second is None
            and self.per_minute is None
            and self.hourly is None
            and self.daily is None
            and self.monthly is None
        )

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for serialization."""
        return {
            "per_second": self.per_second,
            "per_minute": self.per_minute,
            "hourly": self.hourly,
            "daily": self.daily,
            "monthly": self.monthly,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "RateLimits":
        """Create from dictionary."""
        return cls(
            per_second=data.get("per_second"),
            per_minute=data.get("per_minute"),
            hourly=data.get("hourly"),
            daily=data.get("daily"),
            monthly=data.get("monthly"),
        )


@dataclass
class ApiKeyRecord:
    """API key record stored in Redis.

    Note: The actual API key value is never stored - only its hash.
    """

    key_hash: str  # SHA256 hash of the full key
    key_prefix: str  # First 8 chars for display (e.g., "sk-abc123")
    name: str  # Human-readable name
    created_at: datetime
    enabled: bool = True
    rate_limits: RateLimits = field(default_factory=RateLimits)
    metadata: Dict[str, str] = field(default_factory=dict)
    last_used_at: Optional[datetime] = None
    usage_count: int = 0
    source: str = (
        "managed"  # "managed" for Redis-managed, "environment" for env var keys
    )

    def to_redis_hash(self) -> Dict[str, str]:
        """Convert to Redis hash format (all string values)."""
        return {
            "key_hash": self.key_hash,
            "key_prefix": self.key_prefix,
            "name": self.name,
            "created_at": self.created_at.isoformat(),
            "enabled": "true" if self.enabled else "false",
            "rate_limits_per_second": (
                str(self.rate_limits.per_second)
                if self.rate_limits.per_second is not None
                else ""
            ),
            "rate_limits_per_minute": (
                str(self.rate_limits.per_minute)
                if self.rate_limits.per_minute is not None
                else ""
            ),
            "rate_limits_hourly": (
                str(self.rate_limits.hourly)
                if self.rate_limits.hourly is not None
                else ""
            ),
            "rate_limits_daily": (
                str(self.rate_limits.daily)
                if self.rate_limits.daily is not None
                else ""
            ),
            "rate_limits_monthly": (
                str(self.rate_limits.monthly)
                if self.rate_limits.monthly is not None
                else ""
            ),
            "metadata": json.dumps(self.metadata),
            "last_used_at": self.last_used_at.isoformat() if self.last_used_at else "",
            "usage_count": str(self.usage_count),
            "source": self.source,
        }

    @classmethod
    def from_redis_hash(cls, data: Dict[bytes, bytes]) -> "ApiKeyRecord":
        """Create from Redis hash data (bytes keys/values)."""
        # Decode bytes to strings
        decoded = {
            k.decode() if isinstance(k, bytes) else k: (
                v.decode() if isinstance(v, bytes) else v
            )
            for k, v in data.items()
        }

        # Parse rate limits
        rate_limits = RateLimits(
            per_second=(
                int(decoded["rate_limits_per_second"])
                if decoded.get("rate_limits_per_second")
                else None
            ),
            per_minute=(
                int(decoded["rate_limits_per_minute"])
                if decoded.get("rate_limits_per_minute")
                else None
            ),
            hourly=(
                int(decoded["rate_limits_hourly"])
                if decoded.get("rate_limits_hourly")
                else None
            ),
            daily=(
                int(decoded["rate_limits_daily"])
                if decoded.get("rate_limits_daily")
                else None
            ),
            monthly=(
                int(decoded["rate_limits_monthly"])
                if decoded.get("rate_limits_monthly")
                else None
            ),
        )

        # Parse timestamps
        created_at = datetime.fromisoformat(decoded["created_at"])
        last_used_at = None
        if decoded.get("last_used_at"):
            last_used_at = datetime.fromisoformat(decoded["last_used_at"])

        # Parse metadata
        metadata = {}
        if decoded.get("metadata"):
            metadata = json.loads(decoded["metadata"])

        return cls(
            key_hash=decoded["key_hash"],
            key_prefix=decoded["key_prefix"],
            name=decoded["name"],
            created_at=created_at,
            enabled=decoded.get("enabled", "true").lower() == "true",
            rate_limits=rate_limits,
            metadata=metadata,
            last_used_at=last_used_at,
            usage_count=int(decoded.get("usage_count", "0")),
            source=decoded.get("source", "managed"),
        )

    def to_display_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for display (CLI/API output)."""
        return {
            "prefix": self.key_prefix,
            "name": self.name,
            "enabled": self.enabled,
            "created_at": self.created_at.isoformat(),
            "last_used_at": (
                self.last_used_at.isoformat() if self.last_used_at else None
            ),
            "usage_count": self.usage_count,
            "rate_limits": {
                "hourly": self.rate_limits.hourly,
                "daily": self.rate_limits.daily,
                "monthly": self.rate_limits.monthly,
            },
            "source": self.source,
        }


@dataclass
class RateLimitStatus:
    """Current rate limit status for an API key."""

    period: str  # "hourly", "daily", "monthly"
    limit: Optional[int]  # None = unlimited
    used: int
    remaining: Optional[int]  # None = unlimited
    resets_at: datetime
    is_exceeded: bool

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for API response."""
        return {
            "period": self.period,
            "limit": self.limit,
            "used": self.used,
            "remaining": self.remaining,
            "resets_at": self.resets_at.isoformat(),
            "is_exceeded": self.is_exceeded,
        }


@dataclass
class KeyValidationResult:
    """Result of API key validation."""

    is_valid: bool
    key_hash: Optional[str] = None
    key_record: Optional[ApiKeyRecord] = None
    is_env_key: bool = False  # True if validated against API_KEY env var
    rate_limit_exceeded: bool = False
    exceeded_limit: Optional[RateLimitStatus] = None
    error_message: Optional[str] = None
