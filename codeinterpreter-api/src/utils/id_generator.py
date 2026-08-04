"""ID generation utilities for LibreChat compatibility."""

import secrets
import string


def generate_nanoid(length: int = 21) -> str:
    """
    Generate a nanoid-style ID compatible with LibreChat validation.

    LibreChat expects IDs that are exactly 21 characters long and contain
    only letters (A-Z, a-z), numbers (0-9), underscores (_), and hyphens (-).

    Args:
        length: Length of the ID to generate (default: 21 for LibreChat compatibility)

    Returns:
        A string ID that matches LibreChat's validation pattern: /^[A-Za-z0-9_-]{21}$/
    """
    alphabet = string.ascii_letters + string.digits + "_-"
    return "".join(secrets.choice(alphabet) for _ in range(length))


def generate_session_id() -> str:
    """Generate a session ID compatible with LibreChat."""
    return generate_nanoid(21)


def generate_file_id() -> str:
    """Generate a file ID compatible with LibreChat."""
    return generate_nanoid(21)


def generate_execution_id() -> str:
    """Generate an execution ID compatible with LibreChat."""
    return generate_nanoid(21)


def generate_request_id() -> str:
    """Generate a request ID for error tracking."""
    return generate_nanoid(21)
