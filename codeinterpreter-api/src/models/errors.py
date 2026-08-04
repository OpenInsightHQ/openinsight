"""Error models and exception classes for the Code Interpreter API."""

import time
from typing import Optional, List
from pydantic import BaseModel, Field
from enum import Enum


class ErrorType(str, Enum):
    """Error type enumeration."""

    AUTHENTICATION = "authentication"
    AUTHORIZATION = "authorization"
    VALIDATION = "validation"
    RESOURCE_NOT_FOUND = "resource_not_found"
    RESOURCE_CONFLICT = "resource_conflict"
    RESOURCE_EXHAUSTED = "resource_exhausted"
    EXECUTION_FAILED = "execution_failed"
    TIMEOUT = "timeout"
    RATE_LIMITED = "rate_limited"
    INTERNAL_SERVER = "internal_server"
    SERVICE_UNAVAILABLE = "service_unavailable"
    EXTERNAL_SERVICE = "external_service"


class ErrorDetail(BaseModel):
    """Detailed error information."""

    field: Optional[str] = Field(None, description="Field name for validation errors")
    message: str = Field(..., description="Human-readable error message")
    code: Optional[str] = Field(None, description="Machine-readable error code")


class ErrorResponse(BaseModel):
    """Standardized error response model."""

    error: str = Field(..., description="Main error message")
    error_type: ErrorType = Field(..., description="Error category")
    details: Optional[List[ErrorDetail]] = Field(
        None, description="Additional error details"
    )
    request_id: Optional[str] = Field(
        None, description="Request identifier for tracking"
    )
    timestamp: float = Field(default_factory=time.time, description="Error timestamp")

    class Config:
        use_enum_values = True


# Custom Exception Classes


class CodeInterpreterException(Exception):
    """Base exception for Code Interpreter API."""

    def __init__(
        self,
        message: str,
        error_type: ErrorType = ErrorType.INTERNAL_SERVER,
        status_code: int = 500,
        details: Optional[List[ErrorDetail]] = None,
        request_id: Optional[str] = None,
    ):
        self.message = message
        self.error_type = error_type
        self.status_code = status_code
        self.details = details or []
        self.request_id = request_id
        super().__init__(message)

    def to_response(self) -> ErrorResponse:
        """Convert exception to error response model."""
        return ErrorResponse(
            error=self.message,
            error_type=self.error_type,
            details=self.details if self.details else None,
            request_id=self.request_id,
        )


class AuthenticationError(CodeInterpreterException):
    """Authentication related errors."""

    def __init__(self, message: str = "Authentication failed", **kwargs):
        super().__init__(
            message=message,
            error_type=ErrorType.AUTHENTICATION,
            status_code=401,
            **kwargs,
        )


class AuthorizationError(CodeInterpreterException):
    """Authorization related errors."""

    def __init__(self, message: str = "Access denied", **kwargs):
        super().__init__(
            message=message,
            error_type=ErrorType.AUTHORIZATION,
            status_code=403,
            **kwargs,
        )


class ValidationError(CodeInterpreterException):
    """Request validation errors."""

    def __init__(self, message: str = "Validation failed", **kwargs):
        super().__init__(
            message=message, error_type=ErrorType.VALIDATION, status_code=400, **kwargs
        )


class ResourceNotFoundError(CodeInterpreterException):
    """Resource not found errors."""

    def __init__(self, resource: str, resource_id: str = None, **kwargs):
        message = f"{resource} not found"
        if resource_id:
            message += f": {resource_id}"
        super().__init__(
            message=message,
            error_type=ErrorType.RESOURCE_NOT_FOUND,
            status_code=404,
            **kwargs,
        )


class ResourceConflictError(CodeInterpreterException):
    """Resource conflict errors."""

    def __init__(self, message: str = "Resource conflict", **kwargs):
        super().__init__(
            message=message,
            error_type=ErrorType.RESOURCE_CONFLICT,
            status_code=409,
            **kwargs,
        )


class ResourceExhaustedError(CodeInterpreterException):
    """Resource exhaustion errors."""

    def __init__(self, resource: str, **kwargs):
        super().__init__(
            message=f"{resource} limit exceeded",
            error_type=ErrorType.RESOURCE_EXHAUSTED,
            status_code=429,
            **kwargs,
        )


class ExecutionError(CodeInterpreterException):
    """Code execution related errors."""

    def __init__(self, message: str = "Code execution failed", **kwargs):
        super().__init__(
            message=message,
            error_type=ErrorType.EXECUTION_FAILED,
            status_code=422,
            **kwargs,
        )


class TimeoutError(CodeInterpreterException):
    """Timeout related errors."""

    def __init__(self, operation: str, timeout: int, **kwargs):
        super().__init__(
            message=f"{operation} timed out after {timeout} seconds",
            error_type=ErrorType.TIMEOUT,
            status_code=408,
            **kwargs,
        )


class RateLimitError(CodeInterpreterException):
    """Rate limiting errors."""

    def __init__(self, message: str = "Rate limit exceeded", **kwargs):
        super().__init__(
            message=message,
            error_type=ErrorType.RATE_LIMITED,
            status_code=429,
            **kwargs,
        )


class ServiceUnavailableError(CodeInterpreterException):
    """Service unavailable errors."""

    def __init__(self, service: str, message: str = None, **kwargs):
        error_message = message or f"{service} service is currently unavailable"
        super().__init__(
            message=error_message,
            error_type=ErrorType.SERVICE_UNAVAILABLE,
            status_code=503,
            **kwargs,
        )


class ExternalServiceError(CodeInterpreterException):
    """External service integration errors."""

    def __init__(self, service: str, message: str = None, **kwargs):
        error_message = message or f"External service error: {service}"
        super().__init__(
            message=error_message,
            error_type=ErrorType.EXTERNAL_SERVICE,
            status_code=502,
            **kwargs,
        )
