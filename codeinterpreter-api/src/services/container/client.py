"""Docker client factory and initialization."""

import os
from typing import Optional

import docker
import structlog
from docker.errors import DockerException

from ...config import settings

logger = structlog.get_logger(__name__)


class DockerClientFactory:
    """Factory for creating Docker clients with proper initialization."""

    def __init__(self):
        """Initialize Docker client manager without blocking operations."""
        self.client: Optional[docker.DockerClient] = None
        self._initialization_error: Optional[str] = None
        self._initialization_attempted: bool = False
        logger.info(
            "DockerClientFactory initialized (client will be created on first use)"
        )

    def _ensure_client(self) -> bool:
        """Ensure Docker client is initialized. Returns True if successful."""
        if self.client is not None:
            return True

        if self._initialization_attempted and self._initialization_error:
            return False

        try:
            logger.info("Initializing Docker client on first use")
            self._initialization_attempted = True

            socket_path = "/var/run/docker.sock"
            if not os.path.exists(socket_path):
                raise DockerException(f"Docker socket not found at {socket_path}")

            if not os.access(socket_path, os.R_OK | os.W_OK):
                raise DockerException(
                    f"No permission to access Docker socket at {socket_path}"
                )

            client_created = False
            last_error = None

            # Approach 1: Try with requests-unixsocket session
            try:
                logger.info(
                    "Attempting Docker client creation with requests-unixsocket"
                )
                import requests_unixsocket

                session = requests_unixsocket.Session()
                self.client = docker.DockerClient(
                    base_url="unix://var/run/docker.sock",
                    timeout=settings.docker_timeout,
                )
                self.client.api._session = session

                version_info = self.client.version()
                logger.info(
                    f"Docker connection successful. Server version: {version_info.get('ServerVersion', 'unknown')}"
                )
                client_created = True

            except Exception as e:
                logger.warning(f"requests-unixsocket approach failed: {e}")
                last_error = e

            # Approach 2: Try with environment variables
            if not client_created:
                try:
                    logger.info(
                        "Attempting Docker client creation with environment override"
                    )
                    old_docker_host = os.environ.get("DOCKER_HOST")
                    os.environ["DOCKER_HOST"] = "unix:///var/run/docker.sock"

                    try:
                        self.client = docker.from_env(timeout=settings.docker_timeout)
                        version_info = self.client.version()
                        logger.info(
                            f"Docker connection successful. Server version: {version_info.get('ServerVersion', 'unknown')}"
                        )
                        client_created = True
                    finally:
                        if old_docker_host is not None:
                            os.environ["DOCKER_HOST"] = old_docker_host
                        elif "DOCKER_HOST" in os.environ:
                            del os.environ["DOCKER_HOST"]

                except Exception as e:
                    logger.warning(f"Environment override approach failed: {e}")
                    last_error = e

            # Approach 3: Direct socket connection
            if not client_created:
                try:
                    logger.info("Attempting Docker client creation with direct socket")
                    self.client = docker.DockerClient(
                        base_url="unix:///var/run/docker.sock"
                    )
                    self.client.ping()
                    logger.info("Docker connection successful with direct socket")
                    client_created = True
                except Exception as e:
                    logger.warning(f"Direct socket approach failed: {e}")
                    last_error = e

            if not client_created:
                error_msg = f"All Docker client initialization approaches failed. Last error: {last_error}"
                logger.error(error_msg)
                raise DockerException(error_msg)

            # Test connection
            logger.info("Testing Docker connection...")
            try:
                self.client.ping()
                logger.info("Docker connection test successful")
            except Exception as ping_error:
                logger.error(f"Docker ping failed: {ping_error}")
                try:
                    info = self.client.info()
                    logger.info(
                        f"Docker info retrieved: {info.get('ServerVersion', 'unknown')}"
                    )
                except Exception as info_error:
                    logger.error(f"Docker info failed: {info_error}")
                    raise ping_error

            logger.info("Docker client initialized and tested successfully")
            return True

        except Exception as e:
            logger.error(f"Failed to create Docker client: {e}")
            self._initialization_error = str(e)
            self.client = None
            return False

    def is_available(self) -> bool:
        """Check if Docker is available."""
        return self._ensure_client()

    def get_initialization_error(self) -> Optional[str]:
        """Get Docker initialization error if any."""
        return self._initialization_error

    def reset_initialization(self) -> None:
        """Reset initialization state to allow retry."""
        self._initialization_attempted = False
        self._initialization_error = None
        if self.client:
            try:
                self.client.close()
            except Exception:
                pass
            self.client = None
        logger.info("Docker client initialization state reset")

    def get_client(self) -> Optional[docker.DockerClient]:
        """Get the Docker client, ensuring it's initialized."""
        if self._ensure_client():
            return self.client
        return None

    def close(self):
        """Close Docker client connection."""
        try:
            if self.client is not None:
                self.client.close()
        except Exception as e:
            logger.error(f"Error closing Docker client: {e}")
