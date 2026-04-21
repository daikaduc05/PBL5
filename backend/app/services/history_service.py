import json
from datetime import datetime
from typing import Any

from sqlalchemy.orm import Session

from app.models.device_command import DeviceCommandModel
from app.services.result_service import build_history_result_metadata
from app.services.session_service import build_session_key


CAPTURE_COMMAND_TYPES = ("capture_photo", "start_recording")


def list_history_commands(db: Session) -> list[DeviceCommandModel]:
    return (
        db.query(DeviceCommandModel)
        .filter(DeviceCommandModel.command_type.in_(CAPTURE_COMMAND_TYPES))
        .order_by(DeviceCommandModel.created_at.desc(), DeviceCommandModel.id.desc())
        .all()
    )


def get_history_command(db: Session, history_id: int) -> DeviceCommandModel | None:
    return (
        db.query(DeviceCommandModel)
        .filter(
            DeviceCommandModel.id == history_id,
            DeviceCommandModel.command_type.in_(CAPTURE_COMMAND_TYPES),
        )
        .first()
    )


def _deserialize_command_payload(command_payload: str | None) -> dict[str, Any]:
    if command_payload is None:
        return {}

    try:
        decoded_payload = json.loads(command_payload)
    except json.JSONDecodeError:
        return {}

    if isinstance(decoded_payload, dict):
        return decoded_payload

    return {}


def _resolve_task_type(command: DeviceCommandModel, payload: dict[str, Any]) -> str:
    capture_mode = str(payload.get("capture_mode", "")).strip().lower()

    if command.command_type == "capture_photo" or capture_mode == "image":
        return "image_pose"

    return "video_pose"


def _resolve_history_status(
    command_status: str,
    result_metadata: dict[str, Any],
) -> str:
    if command_status == "failed":
        return "failed"

    if command_status == "completed":
        return "done" if result_metadata.get("result_ready_count", 0) > 0 else "processing"

    if command_status in {"acknowledged", "running"}:
        return "processing"

    return "queued"


def _resolve_history_progress(
    command_status: str,
    history_status: str,
    result_metadata: dict[str, Any],
) -> int:
    frame_count = int(result_metadata.get("frame_count", 0) or 0)
    pose_ready_count = int(result_metadata.get("pose_ready_count", 0) or 0)
    result_ready_count = int(result_metadata.get("result_ready_count", 0) or 0)

    if history_status == "failed":
        if result_ready_count > 0:
            return 90
        if pose_ready_count > 0:
            return 75
        if frame_count > 0:
            return 60
        return 100

    if history_status == "done":
        return 100

    if command_status == "pending":
        return 5

    if command_status == "acknowledged":
        return 20

    if command_status == "running":
        if result_ready_count > 0:
            return 90
        if pose_ready_count > 0:
            return 80
        if frame_count > 0:
            return 65
        return 50

    if command_status == "completed":
        if result_ready_count > 0:
            return 100
        if pose_ready_count > 0:
            return 92
        if frame_count > 0:
            return 85
        return 78

    return 0


def _resolve_error_message(
    history_status: str,
    result_metadata: dict[str, Any],
) -> str | None:
    if history_status != "failed":
        return None

    if result_metadata.get("frame_count", 0):
        return "The device command failed before the backend finished packaging all result files."

    return "The device command failed before any processed result session was produced."


def _parse_iso_datetime(value: Any) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None

    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def build_history_entry(command: DeviceCommandModel) -> dict[str, Any]:
    session_key = build_session_key(command.session_id)
    payload = _deserialize_command_payload(command.command_payload)
    result_metadata = build_history_result_metadata(session_key)
    command_status = command.status.strip().lower()
    history_status = _resolve_history_status(command_status, result_metadata)

    return {
        "history_id": command.id,
        "command_id": command.id,
        "device_id": command.device_id,
        "session_id": command.session_id,
        "session_key": session_key,
        "command_type": command.command_type,
        "command_status": command_status,
        "status": history_status,
        "task_type": _resolve_task_type(command, payload),
        "progress": _resolve_history_progress(command_status, history_status, result_metadata),
        "error_message": _resolve_error_message(history_status, result_metadata),
        "created_at": command.created_at,
        "started_at": command.executed_at,
        "finished_at": (
            _parse_iso_datetime(result_metadata.get("updated_at"))
            if history_status == "done"
            else command.executed_at if history_status == "failed" else None
        ),
        "result": result_metadata,
    }
