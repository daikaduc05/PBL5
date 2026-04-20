from datetime import datetime

from pydantic import BaseModel

from app.schemas.common import ApiResponse


class SessionCreateResponse(BaseModel):
    session_id: int
    session_key: str
    token: str
    status: str
    created_at: datetime


class SessionCreateApiResponse(ApiResponse):
    data: SessionCreateResponse | None = None
