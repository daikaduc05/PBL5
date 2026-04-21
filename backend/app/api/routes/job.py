from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.job import (
    JobCreateApiResponse,
    JobCreateRequest,
    JobStatusApiResponse,
    JobStatusResponse,
)
from app.services.job_service import LEGACY_JOB_CREATE_MESSAGE, get_legacy_job_status

router = APIRouter(prefix="/jobs", tags=["Legacy Jobs"])


def _error_response(status_code: int, message: str) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={"success": False, "message": message, "data": None},
    )


@router.post("", response_model=JobCreateApiResponse)
def create_job_route(
    payload: JobCreateRequest,
    db: Session = Depends(get_db),
) -> JobCreateApiResponse | JSONResponse:
    return JSONResponse(
        status_code=410,
        content={
            "success": False,
            "message": LEGACY_JOB_CREATE_MESSAGE,
            "data": {
                "session_id": payload.session_id,
                "media_id": payload.media_id,
                "device_id": payload.device_id,
                "task_type": payload.task_type,
            },
        },
    )


@router.get("/{job_id}", response_model=JobStatusApiResponse)
def get_job_status_route(
    job_id: int,
    db: Session = Depends(get_db),
) -> JobStatusApiResponse | JSONResponse:
    job = get_legacy_job_status(db, job_id)
    if job is None:
        return _error_response(
            404,
            "Legacy job record not found. Use /api/history/{history_id} or /api/devices/{device_id}/commands/{command_id} for canonical status.",
        )

    return JobStatusApiResponse(
        success=True,
        message="Legacy job status retrieved from canonical command history",
        data=JobStatusResponse(
            job_id=job["job_id"],
            command_id=job["command_id"],
            session_id=job["session_id"],
            session_key=job["session_key"],
            media_id=job["media_id"],
            device_id=job["device_id"],
            command_type=job["command_type"],
            command_status=job["command_status"],
            task_type=job["task_type"],
            status=job["status"],
            progress=job["progress"],
            error_message=job["error_message"],
            created_at=job["created_at"],
            started_at=job["started_at"],
            finished_at=job["finished_at"],
        ),
    )
