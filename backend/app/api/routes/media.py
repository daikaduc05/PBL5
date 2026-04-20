from fastapi import APIRouter, Depends, Form, UploadFile
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.media import MediaUploadApiResponse, MediaUploadResponse
from app.services.media_service import upload_media
from app.services.session_service import get_session_by_id

router = APIRouter(prefix="/media", tags=["Media"])


def _error_response(status_code: int, message: str) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={"success": False, "message": message, "data": None},
    )


@router.post("/upload", response_model=MediaUploadApiResponse)
async def upload_media_route(
    file: UploadFile,
    source_type: str = Form(...),
    media_type: str = Form(...),
    session_id: int = Form(...),
    device_id: int | None = Form(None),
    db: Session = Depends(get_db),
) -> MediaUploadApiResponse | JSONResponse:
    if source_type not in ("app", "pi"):
        return _error_response(400, "source_type must be 'app' or 'pi'")

    if media_type not in ("image", "video", "frame_batch"):
        return _error_response(400, "media_type must be 'image', 'video', or 'frame_batch'")

    session = get_session_by_id(db, session_id)
    if session is None:
        return _error_response(404, "Session not found")

    media = upload_media(
        db=db,
        file=file,
        session_id=session_id,
        source_type=source_type,
        media_type=media_type,
        device_id=device_id,
    )

    return MediaUploadApiResponse(
        success=True,
        message="Media uploaded successfully",
        data=MediaUploadResponse(
            media_id=media.id,
            file_name=media.file_name,
            file_path=media.file_path,
            media_type=media.media_type,
        ),
    )
