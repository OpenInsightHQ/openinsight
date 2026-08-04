"""Models for state management API endpoints."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class StateInfo(BaseModel):
    """Metadata about stored session state.

    Returned by GET /state/{session_id}/info endpoint.
    """

    exists: bool = Field(..., description="Whether state exists for this session")
    session_id: Optional[str] = Field(None, description="Session identifier")
    size_bytes: Optional[int] = Field(
        None, description="Compressed state size in bytes"
    )
    hash: Optional[str] = Field(
        None, description="SHA256 hash for ETag/change detection"
    )
    created_at: Optional[datetime] = Field(
        None, description="When state was created/updated"
    )
    expires_at: Optional[datetime] = Field(None, description="When state will expire")
    source: Optional[str] = Field(
        None, description="Storage source: 'redis' or 'archive'"
    )

    class Config:
        json_encoders = {datetime: lambda v: v.isoformat() if v else None}


class StateUploadResponse(BaseModel):
    """Response for state upload endpoint.

    Returned by POST /state/{session_id} endpoint.
    """

    message: str = Field(default="state_uploaded", description="Status message")
    size: int = Field(..., description="Uploaded state size in bytes")
