from datetime import datetime
from typing import Literal

from pydantic import BaseModel

from app.schemas.common import ApiResponse


DeviceStatus = Literal["offline", "online", "idle", "capturing", "uploading", "error"]


class DeviceRegisterRequest(BaseModel):
    device_name: str
    device_code: str


class DeviceRegisterResponse(BaseModel):
    device_id: int
    auth_token: str
    status: DeviceStatus


class DeviceRegisterApiResponse(ApiResponse):
    data: DeviceRegisterResponse | None = None


class DeviceSummaryResponse(BaseModel):
    id: int
    device_name: str
    device_code: str
    status: DeviceStatus
    last_seen: datetime | None = None
    created_at: datetime


class DeviceListApiResponse(ApiResponse):
    data: list[DeviceSummaryResponse] | None = None


class DeviceHeartbeatRequest(BaseModel):
    status: DeviceStatus = "online"


class DeviceHeartbeatResponse(BaseModel):
    device_id: int
    status: DeviceStatus
    last_seen: datetime


class DeviceHeartbeatApiResponse(ApiResponse):
    data: DeviceHeartbeatResponse | None = None
