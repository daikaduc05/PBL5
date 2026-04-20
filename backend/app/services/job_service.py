import threading
from datetime import datetime

from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.models.job import JobModel


def create_job(
    db: Session,
    session_id: int,
    media_id: int,
    task_type: str,
    device_id: int | None = None,
) -> JobModel:
    new_job = JobModel(
        session_id=session_id,
        media_id=media_id,
        device_id=device_id,
        task_type=task_type,
        status="queued",
        progress=0,
    )
    db.add(new_job)
    db.commit()
    db.refresh(new_job)

    # Kick off stub processing in background thread
    threading.Thread(
        target=_stub_process_job,
        args=(new_job.id,),
        daemon=True,
    ).start()

    return new_job


def get_job_by_id(db: Session, job_id: int) -> JobModel | None:
    return db.query(JobModel).filter(JobModel.id == job_id).first()


def list_jobs(db: Session) -> list[JobModel]:
    return db.query(JobModel).order_by(JobModel.created_at.desc()).all()


def _stub_process_job(job_id: int) -> None:
    """
    Simulate the processing pipeline:
      queued (0s) → processing (2s, 0→80%) → done (5s, 100%)
    Uses its own DB session since it runs in a background thread.
    """
    import time

    # --- Step 1: queued → processing ---
    time.sleep(2)
    db = SessionLocal()
    try:
        job = db.query(JobModel).filter(JobModel.id == job_id).first()
        if job is None or job.status != "queued":
            return
        job.status = "processing"
        job.progress = 10
        job.started_at = datetime.utcnow()
        db.commit()
    finally:
        db.close()

    # --- Step 2: Gradually increment progress ---
    for step in range(1, 8):
        time.sleep(0.5)
        db = SessionLocal()
        try:
            job = db.query(JobModel).filter(JobModel.id == job_id).first()
            if job is None or job.status != "processing":
                return
            job.progress = min(10 + step * 10, 80)
            db.commit()
        finally:
            db.close()

    # --- Step 3: processing → done ---
    time.sleep(1)
    db = SessionLocal()
    try:
        job = db.query(JobModel).filter(JobModel.id == job_id).first()
        if job is None or job.status != "processing":
            return
        job.status = "done"
        job.progress = 100
        job.finished_at = datetime.utcnow()
        db.commit()
    finally:
        db.close()
