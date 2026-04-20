from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.job import (
    JobCreateApiResponse,
    JobCreateRequest,
    JobCreateResponse,
    JobStatusApiResponse,
    JobStatusResponse,
)
from app.services.job_service import create_job, get_job_by_id
from app.services.media_service import get_media_by_id
from app.services.session_service import get_session_by_id

router = APIRouter(prefix="/jobs", tags=["Jobs"])


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
    session = get_session_by_id(db, payload.session_id)
    if session is None:
        return _error_response(404, "Session not found")

    media = get_media_by_id(db, payload.media_id)
    if media is None:
        return _error_response(404, "Media not found")

    job = create_job(
        db=db,
        session_id=payload.session_id,
        media_id=payload.media_id,
        task_type=payload.task_type,
        device_id=payload.device_id,
    )

    return JobCreateApiResponse(
        success=True,
        message="Job created successfully",
        data=JobCreateResponse(
            job_id=job.id,
            status=job.status,
            progress=job.progress,
        ),
    )


@router.get("/{job_id}", response_model=JobStatusApiResponse)
def get_job_status_route(
    job_id: int,
    db: Session = Depends(get_db),
) -> JobStatusApiResponse | JSONResponse:
    job = get_job_by_id(db, job_id)
    if job is None:
        return _error_response(404, "Job not found")

    return JobStatusApiResponse(
        success=True,
        message="Job retrieved successfully",
        data=JobStatusResponse(
            job_id=job.id,
            session_id=job.session_id,
            media_id=job.media_id,
            device_id=job.device_id,
            task_type=job.task_type,
            status=job.status,
            progress=job.progress,
            error_message=job.error_message,
            created_at=job.created_at,
            started_at=job.started_at,
            finished_at=job.finished_at,
        ),
    )
