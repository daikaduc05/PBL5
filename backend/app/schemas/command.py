from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel

from app.schemas.common import ApiResponse


CommandType = Literal["capture_photo", "start_recording", "stop_recording"]
CommandStatus = Literal["pending", "acknowledged", "completed", "failed"]


class DeviceCommandCreateRequest(BaseModel):
    session_id: int
    command_type: CommandType
    command_payload: Any | None = None


class DeviceCommandCreateResponse(BaseModel):
    command_id: int
    status: CommandStatus


class DeviceCommandCreateApiResponse(ApiResponse):
    data: DeviceCommandCreateResponse | None = None


class PendingCommandResponse(BaseModel):
    command_id: int
    command_type: CommandType
    command_payload: str | None = None
    status: CommandStatus
    created_at: datetime


class PendingCommandApiResponse(ApiResponse):
    data: PendingCommandResponse | None = None
