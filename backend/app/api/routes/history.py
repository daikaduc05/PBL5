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
from app.services.job_service import get_job_by_id, list_jobs
from app.services.session_service import build_session_key

router = APIRouter(prefix="/history", tags=["History"])


def _error_response(status_code: int, message: str) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={"success": False, "message": message, "data": None},
    )


@router.get("", response_model=HistoryListApiResponse)
def get_history_route(db: Session = Depends(get_db)) -> HistoryListApiResponse:
    jobs = list_jobs(db)
    return HistoryListApiResponse(
        success=True,
        message="History retrieved successfully",
        data=[
            HistoryItemResponse(
                job_id=job.id,
                session_id=job.session_id,
                session_key=build_session_key(job.session_id),
                status=job.status,
                task_type=job.task_type,
                progress=job.progress,
                created_at=job.created_at,
            )
            for job in jobs
        ],
    )


@router.get("/{job_id}", response_model=HistoryDetailApiResponse)
def get_history_detail_route(
    job_id: int,
    db: Session = Depends(get_db),
) -> HistoryDetailApiResponse | JSONResponse:
    job = get_job_by_id(db, job_id)
    if job is None:
        return _error_response(404, "Job not found")

    return HistoryDetailApiResponse(
        success=True,
        message="Job detail retrieved successfully",
        data=HistoryDetailResponse(
            job_id=job.id,
            session_id=job.session_id,
            session_key=build_session_key(job.session_id),
            status=job.status,
            task_type=job.task_type,
            progress=job.progress,
            error_message=job.error_message,
            created_at=job.created_at,
            started_at=job.started_at,
            finished_at=job.finished_at,
            result=None,  # Future: attach result overlay path when done
        ),
    )
