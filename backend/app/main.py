from fastapi import FastAPI

from app.api.routes.health import router as health_router
from app.api.routes.session import router as session_router
from app.core.database import Base, engine
from app.models.session import SessionModel


Base.metadata.create_all(bind=engine)


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


app.include_router(health_router, prefix="/api")
app.include_router(session_router, prefix="/api")
