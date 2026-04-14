import json
from typing import Any

from sqlalchemy.orm import Session

from app.models.device_command import DeviceCommandModel


def _serialize_command_payload(command_payload: Any | None) -> str | None:
    if command_payload is None:
        return None

    if isinstance(command_payload, str):
        return command_payload

    return json.dumps(command_payload)


def create_device_command(
    db: Session,
    device_id: int,
    session_id: int,
    command_type: str,
    command_payload: Any | None,
) -> DeviceCommandModel:
    new_command = DeviceCommandModel(
        device_id=device_id,
        session_id=session_id,
        command_type=command_type,
        command_payload=_serialize_command_payload(command_payload),
    )
    db.add(new_command)
    db.commit()
    db.refresh(new_command)
    return new_command


def get_oldest_pending_command(db: Session, device_id: int) -> DeviceCommandModel | None:
    return (
        db.query(DeviceCommandModel)
        .filter(
            DeviceCommandModel.device_id == device_id,
            DeviceCommandModel.status == "pending",
        )
        .order_by(DeviceCommandModel.created_at.asc(), DeviceCommandModel.id.asc())
        .first()
    )
