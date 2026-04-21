from sqlalchemy.orm import Session

from app.services.history_service import build_history_entry, get_history_command


LEGACY_JOB_CREATE_MESSAGE = (
    "The /jobs create endpoint is retired. "
    "Use POST /api/session/create and POST /api/devices/{device_id}/commands instead."
)


def get_legacy_job_status(db: Session, job_id: int) -> dict | None:
    command = get_history_command(db, job_id)
    if command is None:
        return None

    entry = build_history_entry(command)
    return {
        "job_id": command.id,
        "command_id": entry["command_id"],
        "session_id": entry["session_id"],
        "session_key": entry["session_key"],
        "media_id": None,
        "device_id": entry["device_id"],
        "command_type": entry["command_type"],
        "command_status": entry["command_status"],
        "task_type": entry["task_type"],
        "status": entry["status"],
        "progress": entry["progress"],
        "error_message": entry["error_message"],
        "created_at": entry["created_at"],
        "started_at": entry["started_at"],
        "finished_at": entry["finished_at"],
    }
