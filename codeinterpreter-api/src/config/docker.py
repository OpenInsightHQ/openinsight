"""Docker configuration."""

from typing import Dict, List, Optional
from pydantic import Field
from pydantic_settings import BaseSettings


class DockerConfig(BaseSettings):
    """Docker execution settings."""

    base_url: str | None = Field(default=None, alias="docker_base_url")
    timeout: int = Field(default=60, ge=10, alias="docker_timeout")
    network_mode: str = Field(default="none", alias="docker_network_mode")
    security_opt: List[str] = Field(
        default_factory=lambda: ["no-new-privileges:true"], alias="docker_security_opt"
    )
    cap_drop: List[str] = Field(
        default_factory=lambda: ["ALL"], alias="docker_cap_drop"
    )
    read_only: bool = Field(default=True, alias="docker_read_only")
    tmpfs: Dict[str, str] = Field(
        default_factory=lambda: {"/tmp": "rw,noexec,nosuid,size=100m"},
        alias="docker_tmpfs",
    )
    seccomp_profile: Optional[str] = Field(
        default="docker/seccomp-sandbox.json",
        alias="docker_seccomp_profile",
        description="Path to seccomp profile JSON file (None to disable)",
    )

    # Container lifecycle
    container_ttl_minutes: int = Field(default=5, ge=1, le=1440)
    container_cleanup_interval_minutes: int = Field(default=5, ge=1, le=60)

    # Container labeling for isolation
    container_label_prefix: str = Field(default="com.code-interpreter")

    class Config:
        env_prefix = ""
        extra = "ignore"
