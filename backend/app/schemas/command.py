from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel

from app.schemas.common import ApiResponse


CommandType = Literal["capture_photo", "start_recording", "stop_recording"]
CommandStatus = Literal["pending", "acknowledged", "running", "completed", "failed"]


class DeviceCommandCreateRequest(BaseModel):
    session_id: int
    command_type: CommandType
    command_payload: Any | None = None


class DeviceCommandCreateResponse(BaseModel):
    command_id: int
    session_id: int
    session_key: str
    status: CommandStatus


class DeviceCommandCreateApiResponse(ApiResponse):
    data: DeviceCommandCreateResponse | None = None


class PendingCommandResponse(BaseModel):
    command_id: int
    session_id: int
    session_key: str
    command_type: CommandType
    command_payload: str | None = None
    status: CommandStatus
    created_at: datetime
    executed_at: datetime | None = None


class PendingCommandApiResponse(ApiResponse):
    data: PendingCommandResponse | None = None


class CommandStatusUpdateRequest(BaseModel):
    status: CommandStatus


class CommandStatusUpdateResponse(BaseModel):
    command_id: int
    session_id: int
    session_key: str
    status: CommandStatus
    executed_at: datetime | None = None


class CommandStatusUpdateApiResponse(ApiResponse):
    data: CommandStatusUpdateResponse | None = None
