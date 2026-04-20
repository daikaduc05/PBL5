import secrets

from sqlalchemy.orm import Session

from app.models.session import SessionModel


SESSION_KEY_PREFIX = "sess"


def _generate_session_token() -> str:
    return secrets.token_urlsafe(32)


def build_session_key(session_id: int) -> str:
    return f"{SESSION_KEY_PREFIX}_{session_id:06d}"


def create_session(db: Session) -> SessionModel:
    token = _generate_session_token()

    while db.query(SessionModel).filter(SessionModel.token == token).first() is not None:
        token = _generate_session_token()

    new_session = SessionModel(token=token)
    db.add(new_session)
    db.commit()
    db.refresh(new_session)
    return new_session


def get_session_by_id(db: Session, session_id: int) -> SessionModel | None:
    return db.query(SessionModel).filter(SessionModel.id == session_id).first()
