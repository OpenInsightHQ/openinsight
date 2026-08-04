"""Redis configuration."""

from pydantic import Field
from pydantic_settings import BaseSettings


class RedisConfig(BaseSettings):
    """Redis connection settings."""

    host: str = Field(default="localhost", alias="redis_host")
    port: int = Field(default=6379, ge=1, le=65535, alias="redis_port")
    password: str | None = Field(default=None, alias="redis_password")
    db: int = Field(default=0, ge=0, le=15, alias="redis_db")
    url: str | None = Field(default=None, alias="redis_url")
    max_connections: int = Field(default=20, ge=1, alias="redis_max_connections")
    socket_timeout: int = Field(default=5, ge=1, alias="redis_socket_timeout")
    socket_connect_timeout: int = Field(
        default=5, ge=1, alias="redis_socket_connect_timeout"
    )

    def get_url(self) -> str:
        """Get Redis connection URL."""
        if self.url:
            return self.url
        password_part = f":{self.password}@" if self.password else ""
        return f"redis://{password_part}{self.host}:{self.port}/{self.db}"

    class Config:
        env_prefix = ""
        extra = "ignore"
