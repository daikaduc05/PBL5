from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.command import (
    DeviceCommandCreateApiResponse,
    DeviceCommandCreateRequest,
    DeviceCommandCreateResponse,
    PendingCommandApiResponse,
    PendingCommandResponse,
)
from app.schemas.device import (
    DeviceHeartbeatApiResponse,
    DeviceHeartbeatRequest,
    DeviceHeartbeatResponse,
    DeviceListApiResponse,
    DeviceRegisterApiResponse,
    DeviceRegisterRequest,
    DeviceRegisterResponse,
    DeviceSummaryResponse,
)
from app.services.command_service import create_device_command, get_oldest_pending_command
from app.services.device_service import (
    get_device_by_id,
    list_devices,
    register_device,
    resolve_device_status,
    update_device_heartbeat,
)
from app.services.session_service import get_session_by_id


router = APIRouter(tags=["Devices"])


def _error_response(status_code: int, message: str) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={
            "success": False,
            "message": message,
            "data": None,
        },
    )


@router.post("/devices/register", response_model=DeviceRegisterApiResponse)
def register_device_route(
    payload: DeviceRegisterRequest,
    db: Session = Depends(get_db),
) -> DeviceRegisterApiResponse:
    device = register_device(
        db=db,
        device_name=payload.device_name,
        device_code=payload.device_code,
    )

    return DeviceRegisterApiResponse(
        success=True,
        message="Device registered successfully",
        data=DeviceRegisterResponse(
            device_id=device.id,
            auth_token=device.auth_token,
            status=resolve_device_status(device),
        ),
    )


@router.get("/devices", response_model=DeviceListApiResponse)
def list_devices_route(db: Session = Depends(get_db)) -> DeviceListApiResponse:
    devices = list_devices(db)

    return DeviceListApiResponse(
        success=True,
        message="Devices retrieved successfully",
        data=[
            DeviceSummaryResponse(
                id=device.id,
                device_name=device.device_name,
                device_code=device.device_code,
                status=resolve_device_status(device),
                last_seen=device.last_seen,
                created_at=device.created_at,
            )
            for device in devices
        ],
    )


@router.post("/devices/{device_id}/heartbeat", response_model=DeviceHeartbeatApiResponse)
def device_heartbeat_route(
    device_id: int,
    payload: DeviceHeartbeatRequest,
    db: Session = Depends(get_db),
) -> DeviceHeartbeatApiResponse | JSONResponse:
    device = get_device_by_id(db, device_id)
    if device is None:
        return _error_response(status_code=404, message="Device not found")

    updated_device = update_device_heartbeat(db=db, device=device, status=payload.status)
    return DeviceHeartbeatApiResponse(
        success=True,
        message="Heartbeat updated",
        data=DeviceHeartbeatResponse(
            device_id=updated_device.id,
            status=resolve_device_status(updated_device),
            last_seen=updated_device.last_seen,
        ),
    )


@router.post("/devices/{device_id}/commands", response_model=DeviceCommandCreateApiResponse)
def create_device_command_route(
    device_id: int,
    payload: DeviceCommandCreateRequest,
    db: Session = Depends(get_db),
) -> DeviceCommandCreateApiResponse | JSONResponse:
    device = get_device_by_id(db, device_id)
    if device is None:
        return _error_response(status_code=404, message="Device not found")

    session = get_session_by_id(db, payload.session_id)
    if session is None:
        return _error_response(status_code=404, message="Session not found")

    command = create_device_command(
        db=db,
        device_id=device.id,
        session_id=session.id,
        command_type=payload.command_type,
        command_payload=payload.command_payload,
    )

    return DeviceCommandCreateApiResponse(
        success=True,
        message="Command created successfully",
        data=DeviceCommandCreateResponse(
            command_id=command.id,
            status=command.status,
        ),
    )


@router.get("/devices/{device_id}/commands/pending", response_model=PendingCommandApiResponse)
def get_pending_command_route(
    device_id: int,
    db: Session = Depends(get_db),
) -> PendingCommandApiResponse | JSONResponse:
    device = get_device_by_id(db, device_id)
    if device is None:
        return _error_response(status_code=404, message="Device not found")

    pending_command = get_oldest_pending_command(db=db, device_id=device.id)
    if pending_command is None:
        return PendingCommandApiResponse(
            success=True,
            message="No pending commands",
            data=None,
        )

    return PendingCommandApiResponse(
        success=True,
        message="Pending command retrieved successfully",
        data=PendingCommandResponse(
            command_id=pending_command.id,
            command_type=pending_command.command_type,
            command_payload=pending_command.command_payload,
            status=pending_command.status,
            created_at=pending_command.created_at,
        ),
    )
