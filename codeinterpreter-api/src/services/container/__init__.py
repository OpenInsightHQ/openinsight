"""Container management services.

This package provides Docker container management functionality split into:
- client.py: Docker client factory and initialization
- executor.py: Command execution in containers
- manager.py: Container lifecycle management
"""

from .manager import ContainerManager
from .client import DockerClientFactory
from .executor import ContainerExecutor

__all__ = ["ContainerManager", "DockerClientFactory", "ContainerExecutor"]
