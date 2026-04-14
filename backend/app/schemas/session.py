from pydantic import BaseModel

from app.schemas.common import ApiResponse


class SessionCreateResponse(BaseModel):
    session_id: int
    token: str


class SessionCreateApiResponse(ApiResponse):
    data: SessionCreateResponse | None = None
