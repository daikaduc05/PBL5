from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.session import SessionCreateApiResponse, SessionCreateResponse
from app.services.session_service import build_session_key, create_session


router = APIRouter(tags=["Session"])


@router.post("/session/create", response_model=SessionCreateApiResponse)
def create_session_route(db: Session = Depends(get_db)) -> SessionCreateApiResponse:
    session = create_session(db)
    return SessionCreateApiResponse(
        success=True,
        message="Session created successfully",
        data=SessionCreateResponse(
            session_id=session.id,
            session_key=build_session_key(session.id),
            token=session.token,
            status=session.status,
            created_at=session.created_at,
        ),
    )
