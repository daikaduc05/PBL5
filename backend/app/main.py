from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.api.routes.device import router as device_router
from app.api.routes.health import router as health_router
from app.api.routes.result import router as result_router
from app.api.routes.session import router as session_router
from app.core.database import Base, engine
from app.models.device import DeviceModel
from app.models.device_command import DeviceCommandModel
from app.models.session import SessionModel


Base.metadata.create_all(bind=engine)

BACKEND_ROOT = Path(__file__).resolve().parents[1]
RESULTS_STATIC_ROOT = BACKEND_ROOT / "workers" / "results"
RESULTS_STATIC_ROOT.mkdir(parents=True, exist_ok=True)


app = FastAPI(
    title="PoseTrack Backend",
    version="0.1.0",
)


@app.get("/")
def read_root() -> dict:
    return {
        "success": True,
        "message": "PoseTrack backend is running",
        "data": {
            "port": 8002,
        },
    }


app.mount("/static/results", StaticFiles(directory=RESULTS_STATIC_ROOT), name="result-static")
app.include_router(health_router, prefix="/api")
app.include_router(session_router, prefix="/api")
app.include_router(device_router, prefix="/api")
app.include_router(result_router, prefix="/api")
