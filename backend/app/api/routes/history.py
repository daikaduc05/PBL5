from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.job import (
    HistoryDetailApiResponse,
    HistoryDetailResponse,
    HistoryItemResponse,
    HistoryListApiResponse,
)
from app.services.history_service import build_history_entry, get_history_command, list_history_commands

router = APIRouter(prefix="/history", tags=["History"])


def _error_response(status_code: int, message: str) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={"success": False, "message": message, "data": None},
    )


@router.get("", response_model=HistoryListApiResponse)
def get_history_route(db: Session = Depends(get_db)) -> HistoryListApiResponse:
    commands = list_history_commands(db)
    return HistoryListApiResponse(
        success=True,
        message="History retrieved successfully",
        data=[
            HistoryItemResponse(
                history_id=entry["history_id"],
                command_id=entry["command_id"],
                device_id=entry["device_id"],
                session_id=entry["session_id"],
                session_key=entry["session_key"],
                command_type=entry["command_type"],
                command_status=entry["command_status"],
                status=entry["status"],
                task_type=entry["task_type"],
                progress=entry["progress"],
                created_at=entry["created_at"],
            )
            for entry in (build_history_entry(command) for command in commands)
        ],
    )


@router.get("/{history_id}", response_model=HistoryDetailApiResponse)
def get_history_detail_route(
    history_id: int,
    db: Session = Depends(get_db),
) -> HistoryDetailApiResponse | JSONResponse:
    command = get_history_command(db, history_id)
    if command is None:
        return _error_response(404, "History entry not found")

    entry = build_history_entry(command)

    return HistoryDetailApiResponse(
        success=True,
        message="History entry retrieved successfully",
        data=HistoryDetailResponse(
            history_id=entry["history_id"],
            command_id=entry["command_id"],
            device_id=entry["device_id"],
            session_id=entry["session_id"],
            session_key=entry["session_key"],
            command_type=entry["command_type"],
            command_status=entry["command_status"],
            status=entry["status"],
            task_type=entry["task_type"],
            progress=entry["progress"],
            error_message=entry["error_message"],
            created_at=entry["created_at"],
            started_at=entry["started_at"],
            finished_at=entry["finished_at"],
            result=entry["result"],
        ),
    )
