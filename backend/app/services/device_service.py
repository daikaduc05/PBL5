import secrets
from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from app.models.device import DeviceModel


DEVICE_HEARTBEAT_TIMEOUT_SECONDS = 30


def _generate_device_auth_token() -> str:
    return secrets.token_urlsafe(32)


def register_device(db: Session, device_name: str, device_code: str) -> DeviceModel:
    existing_device = db.query(DeviceModel).filter(DeviceModel.device_code == device_code).first()
    now = datetime.utcnow()

    if existing_device is None:
        auth_token = _generate_device_auth_token()
        while db.query(DeviceModel).filter(DeviceModel.auth_token == auth_token).first() is not None:
            auth_token = _generate_device_auth_token()

        device = DeviceModel(
            device_name=device_name,
            device_code=device_code,
            auth_token=auth_token,
            status="online",
            last_seen=now,
        )
        db.add(device)
    else:
        existing_device.device_name = device_name
        existing_device.status = "online"
        existing_device.last_seen = now
        device = existing_device

    db.commit()
    db.refresh(device)
    return device


def list_devices(db: Session) -> list[DeviceModel]:
    return db.query(DeviceModel).order_by(DeviceModel.created_at.asc(), DeviceModel.id.asc()).all()


def get_device_by_id(db: Session, device_id: int) -> DeviceModel | None:
    return db.query(DeviceModel).filter(DeviceModel.id == device_id).first()


def update_device_heartbeat(db: Session, device: DeviceModel, status: str) -> DeviceModel:
    device.status = status
    device.last_seen = datetime.utcnow()
    db.commit()
    db.refresh(device)
    return device


def resolve_device_status(device: DeviceModel, reference_time: datetime | None = None) -> str:
    current_time = reference_time or datetime.utcnow()

    if current_time - device.last_seen > timedelta(seconds=DEVICE_HEARTBEAT_TIMEOUT_SECONDS):
        return "offline"

    return device.status
