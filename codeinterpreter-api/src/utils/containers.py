"""Container utilities for Docker operations.

DEPRECATED: This module is maintained for backward compatibility.
New code should import from src.services.container instead.

The ContainerManager class has been split into:
- src/services/container/client.py: Docker client factory
- src/services/container/executor.py: Command execution
- src/services/container/manager.py: Container lifecycle management
"""

# Re-export from new location for backward compatibility
from ..services.container import (
    ContainerManager,
    DockerClientFactory,
    ContainerExecutor,
)

# Also re-export error handler for existing imports
from .error_handlers import handle_docker_error

__all__ = [
    "ContainerManager",
    "DockerClientFactory",
    "ContainerExecutor",
    "handle_docker_error",
]
