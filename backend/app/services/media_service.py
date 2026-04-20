from pathlib import Path

from fastapi import UploadFile
from sqlalchemy.orm import Session

from app.models.media import MediaModel

BACKEND_ROOT = Path(__file__).resolve().parents[2]
UPLOADS_DIR = BACKEND_ROOT / "storage" / "uploads"


def _ensure_uploads_dir() -> None:
    UPLOADS_DIR.mkdir(parents=True, exist_ok=True)


def upload_media(
    db: Session,
    file: UploadFile,
    session_id: int,
    source_type: str,
    media_type: str,
    device_id: int | None = None,
) -> MediaModel:
    _ensure_uploads_dir()

    # Build a unique file name to prevent collisions
    import uuid
    original_name = file.filename or "upload"
    suffix = Path(original_name).suffix or ""
    unique_name = f"{uuid.uuid4().hex}{suffix}"
    dest_path = UPLOADS_DIR / unique_name

    # Write to disk
    content = file.file.read()
    dest_path.write_bytes(content)

    relative_path = dest_path.relative_to(BACKEND_ROOT).as_posix()

    new_media = MediaModel(
        session_id=session_id,
        device_id=device_id,
        source_type=source_type,
        media_type=media_type,
        file_name=original_name,
        file_path=relative_path,
    )
    db.add(new_media)
    db.commit()
    db.refresh(new_media)
    return new_media


def get_media_by_id(db: Session, media_id: int) -> MediaModel | None:
    return db.query(MediaModel).filter(MediaModel.id == media_id).first()
