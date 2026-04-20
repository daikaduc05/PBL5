import json
from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.models.device_command import DeviceCommandModel
from app.services.session_service import build_session_key


COMMAND_CLAIM_TIMEOUT_SECONDS = 180
ACTIVE_COMMAND_STATUSES = {"acknowledged", "running"}
FINAL_COMMAND_STATUSES = {"completed", "failed"}
ALLOWED_STATUS_TRANSITIONS = {
    "pending": {"pending", "acknowledged", "running", "failed"},
    "acknowledged": {"acknowledged", "running", "completed", "failed"},
    "running": {"running", "completed", "failed"},
    "completed": {"completed"},
    "failed": {"failed"},
}


def _serialize_command_payload(command_payload: Any | None, session_id: int) -> str | None:
    if command_payload is None:
        return json.dumps(
            {
                "session_id": session_id,
                "session_key": build_session_key(session_id),
            }
        )

    if isinstance(command_payload, str):
        try:
            parsed_payload = json.loads(command_payload)
        except json.JSONDecodeError:
            return command_payload

        if isinstance(parsed_payload, dict):
            parsed_payload.setdefault("session_id", session_id)
            parsed_payload.setdefault("session_key", build_session_key(session_id))
            return json.dumps(parsed_payload)

        return command_payload

    if isinstance(command_payload, dict):
        serialized_payload = dict(command_payload)
        serialized_payload.setdefault("session_id", session_id)
        serialized_payload.setdefault("session_key", build_session_key(session_id))
        return json.dumps(serialized_payload)

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
        command_payload=_serialize_command_payload(command_payload, session_id=session_id),
    )
    db.add(new_command)
    db.commit()
    db.refresh(new_command)
    return new_command


def _get_oldest_pending_command(db: Session, device_id: int) -> DeviceCommandModel | None:
    return (
        db.query(DeviceCommandModel)
        .filter(
            DeviceCommandModel.device_id == device_id,
            DeviceCommandModel.status == "pending",
        )
        .order_by(DeviceCommandModel.created_at.asc(), DeviceCommandModel.id.asc())
        .first()
    )


def _get_oldest_stale_active_command(db: Session, device_id: int) -> DeviceCommandModel | None:
    stale_before = datetime.utcnow() - timedelta(seconds=COMMAND_CLAIM_TIMEOUT_SECONDS)

    return (
        db.query(DeviceCommandModel)
        .filter(
            DeviceCommandModel.device_id == device_id,
            DeviceCommandModel.status.in_(ACTIVE_COMMAND_STATUSES),
            or_(
                DeviceCommandModel.executed_at.is_(None),
                DeviceCommandModel.executed_at <= stale_before,
            ),
        )
        .order_by(
            DeviceCommandModel.executed_at.asc(),
            DeviceCommandModel.created_at.asc(),
            DeviceCommandModel.id.asc(),
        )
        .first()
    )


def claim_oldest_command_for_device(db: Session, device_id: int) -> DeviceCommandModel | None:
    command = _get_oldest_pending_command(db=db, device_id=device_id)
    if command is None:
        command = _get_oldest_stale_active_command(db=db, device_id=device_id)

    if command is None:
        return None

    command.status = "acknowledged"
    command.executed_at = datetime.utcnow()
    db.commit()
    db.refresh(command)
    return command


def get_command_by_id(db: Session, command_id: int) -> DeviceCommandModel | None:
    return db.query(DeviceCommandModel).filter(DeviceCommandModel.id == command_id).first()


def update_command_status(
    db: Session,
    command_id: int,
    status: str,
) -> tuple[DeviceCommandModel | None, str | None]:
    command = get_command_by_id(db=db, command_id=command_id)
    if command is None:
        return None, "Command not found"

    normalized_status = status.strip().lower()
    allowed_statuses = ALLOWED_STATUS_TRANSITIONS.get(command.status, set())
    if normalized_status not in allowed_statuses:
        return (
            command,
            f"Cannot change command status from '{command.status}' to '{normalized_status}'",
        )

    if normalized_status in ACTIVE_COMMAND_STATUSES | FINAL_COMMAND_STATUSES:
        command.executed_at = command.executed_at or datetime.utcnow()

    command.status = normalized_status
    db.commit()
    db.refresh(command)
    return command, None
