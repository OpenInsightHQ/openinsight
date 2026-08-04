"""Authentication middleware for API key validation."""

import time
from typing import Callable, Optional

import structlog
from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse

from ..services.auth import get_auth_service

logger = structlog.get_logger(__name__)


class AuthenticationMiddleware:
    """Middleware for API key authentication.

    This middleware handles:
    - API key extraction from headers
    - API key validation
    - Rate limiting on authentication failures
    - Setting authenticated state on request
    """

    def __init__(self, app: Callable):
        self.app = app
        self.excluded_paths = {"/health", "/docs", "/redoc", "/openapi.json"}

    async def __call__(self, scope: dict, receive: Callable, send: Callable):
        """Process request through authentication middleware."""
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        request = Request(scope, receive)

        # Skip auth for excluded paths and OPTIONS
        if self._should_skip_auth(request):
            await self.app(scope, receive, send)
            return

        try:
            await self._authenticate_request(request, scope)
        except HTTPException as e:
            response = JSONResponse(
                status_code=e.status_code,
                content={"error": e.detail, "timestamp": time.time()},
            )
            await response(scope, receive, send)
            return
        except Exception as e:
            logger.error("Authentication middleware error", error=str(e))
            response = JSONResponse(
                status_code=500,
                content={
                    "error": "Internal authentication error",
                    "timestamp": time.time(),
                },
            )
            await response(scope, receive, send)
            return

        await self.app(scope, receive, send)

    def _should_skip_auth(self, request: Request) -> bool:
        """Check if authentication should be skipped."""
        return request.url.path in self.excluded_paths or request.method == "OPTIONS"

    async def _authenticate_request(self, request: Request, scope: dict):
        """Handle API key authentication."""
        # Extract API key
        api_key = self._extract_api_key(request)

        # Get authentication service
        auth_service = await get_auth_service()

        # Check rate limiting
        client_ip = self._get_client_ip(request)
        if not await auth_service.check_rate_limit(client_ip):
            raise HTTPException(
                status_code=429,
                detail="Too many authentication failures. Please try again later.",
            )

        # Validate API key
        if not await auth_service.validate_api_key(api_key):
            raise HTTPException(status_code=401, detail="Invalid or missing API key")

        # Add authenticated state
        scope["state"] = scope.get("state", {})
        scope["state"]["authenticated"] = True
        scope["state"]["api_key"] = api_key

    def _extract_api_key(self, request: Request) -> Optional[str]:
        """Extract API key from request headers."""
        # Check x-api-key header first
        api_key = request.headers.get("x-api-key")
        if api_key:
            return api_key

        # Check Authorization header
        auth_header = request.headers.get("authorization")
        if auth_header:
            if auth_header.startswith("Bearer "):
                return auth_header[7:]
            elif auth_header.startswith("ApiKey "):
                return auth_header[7:]

        return None

    def _get_client_ip(self, request: Request) -> str:
        """Get client IP address."""
        # Check forwarded headers
        forwarded_for = request.headers.get("x-forwarded-for")
        if forwarded_for:
            return forwarded_for.split(",")[0].strip()

        real_ip = request.headers.get("x-real-ip")
        if real_ip:
            return real_ip

        return request.client.host if request.client else "unknown"
