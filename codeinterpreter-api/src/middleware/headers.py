"""Security headers middleware."""

from typing import Callable

import structlog

logger = structlog.get_logger(__name__)


class SecurityHeadersMiddleware:
    """Middleware for adding security headers to responses.

    This middleware adds standard security headers to all responses:
    - X-Content-Type-Options: nosniff
    - X-Frame-Options: DENY
    - X-XSS-Protection: 1; mode=block
    - Strict-Transport-Security: max-age=31536000; includeSubDomains
    - Content-Security-Policy: default-src 'self'
    - Referrer-Policy: strict-origin-when-cross-origin
    - Permissions-Policy: geolocation=(), microphone=(), camera=()
    """

    # Default security headers
    SECURITY_HEADERS = {
        b"x-content-type-options": b"nosniff",
        b"x-frame-options": b"DENY",
        b"x-xss-protection": b"1; mode=block",
        b"strict-transport-security": b"max-age=31536000; includeSubDomains",
        b"content-security-policy": b"default-src 'self'",
        b"referrer-policy": b"strict-origin-when-cross-origin",
        b"permissions-policy": b"geolocation=(), microphone=(), camera=()",
    }

    def __init__(self, app: Callable):
        self.app = app

    async def __call__(self, scope: dict, receive: Callable, send: Callable):
        """Process request and add security headers to response."""
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        async def send_wrapper(message):
            if message["type"] == "http.response.start":
                headers = dict(message.get("headers", []))

                # Add security headers
                for key, value in self.SECURITY_HEADERS.items():
                    headers[key] = value

                message["headers"] = list(headers.items())

            await send(message)

        await self.app(scope, receive, send_wrapper)
