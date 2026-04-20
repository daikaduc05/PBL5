from datetime import datetime
from typing import Literal

from pydantic import BaseModel

from app.schemas.common import ApiResponse

MediaSourceType = Literal["app", "pi"]
MediaType = Literal["image", "video", "frame_batch"]


class MediaUploadResponse(BaseModel):
    media_id: int
    file_name: str
    file_path: str
    media_type: MediaType


class MediaUploadApiResponse(ApiResponse):
    data: MediaUploadResponse | None = None
