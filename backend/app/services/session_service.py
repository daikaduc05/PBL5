import secrets

from sqlalchemy.orm import Session

from app.models.session import SessionModel


def _generate_session_token() -> str:
    return secrets.token_urlsafe(32)


def create_session(db: Session) -> SessionModel:
    token = _generate_session_token()

    while db.query(SessionModel).filter(SessionModel.token == token).first() is not None:
        token = _generate_session_token()

    new_session = SessionModel(token=token)
    db.add(new_session)
    db.commit()
    db.refresh(new_session)
    return new_session
