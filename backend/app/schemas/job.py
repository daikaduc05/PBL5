from datetime import datetime
from typing import Literal

from pydantic import BaseModel

from app.schemas.common import ApiResponse

JobStatus = Literal["queued", "processing", "done", "failed"]
TaskType = Literal["image_pose", "video_pose"]


class JobCreateRequest(BaseModel):
    media_id: int
    session_id: int
    device_id: int | None = None
    task_type: TaskType


class JobCreateResponse(BaseModel):
    job_id: int
    session_id: int
    session_key: str
    status: JobStatus
    progress: int


class JobCreateApiResponse(ApiResponse):
    data: JobCreateResponse | None = None


class JobStatusResponse(BaseModel):
    job_id: int
    command_id: int | None = None
    session_id: int
    session_key: str
    media_id: int | None
    device_id: int | None
    command_type: str | None = None
    command_status: str | None = None
    task_type: str
    status: JobStatus
    progress: int
    error_message: str | None
    created_at: datetime
    started_at: datetime | None
    finished_at: datetime | None


class JobStatusApiResponse(ApiResponse):
    data: JobStatusResponse | None = None


class HistoryItemResponse(BaseModel):
    history_id: int
    command_id: int
    device_id: int | None
    session_id: int
    session_key: str
    command_type: str
    command_status: str
    status: JobStatus
    task_type: str
    progress: int
    created_at: datetime


class HistoryListApiResponse(ApiResponse):
    data: list[HistoryItemResponse] = []


class HistoryDetailResponse(BaseModel):
    history_id: int
    command_id: int
    device_id: int | None
    session_id: int
    session_key: str
    command_type: str
    command_status: str
    status: JobStatus
    task_type: str
    progress: int
    error_message: str | None
    created_at: datetime
    started_at: datetime | None
    finished_at: datetime | None
    result: dict | None = None


class HistoryDetailApiResponse(ApiResponse):
    data: HistoryDetailResponse | None = None
