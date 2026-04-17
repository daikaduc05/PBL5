import json
import re
from pathlib import Path

from fastapi import APIRouter, HTTPException


router = APIRouter(prefix="/results", tags=["Results"])

BACKEND_ROOT = Path(__file__).resolve().parents[3]
RESULTS_ROOT = BACKEND_ROOT / "workers" / "results"
FRAME_FILE_PATTERN = re.compile(r"^frame_(\d+)_(pose\.jpg|result\.json)$")


def _to_relative_path(path: Path) -> str:
    return path.relative_to(BACKEND_ROOT).as_posix()


def _get_session_dir(session_id: str) -> Path:
    session_dir = RESULTS_ROOT / session_id
    if not session_dir.exists() or not session_dir.is_dir():
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found")
    return session_dir


def _collect_frame_ids(session_dir: Path) -> list[int]:
    frame_ids: set[int] = set()

    for file_path in session_dir.iterdir():
        if not file_path.is_file():
            continue

        match = FRAME_FILE_PATTERN.match(file_path.name)
        if match is None:
            continue

        frame_ids.add(int(match.group(1)))

    return sorted(frame_ids)


@router.get("/sessions")
def list_result_sessions() -> dict[str, list[str]]:
    if not RESULTS_ROOT.exists():
        return {"sessions": []}

    sessions = sorted(
        session_dir.name
        for session_dir in RESULTS_ROOT.iterdir()
        if session_dir.is_dir()
    )
    return {"sessions": sessions}


@router.get("/{session_id}")
def list_session_results(session_id: str) -> dict[str, str | list[dict[str, int | str]]]:
    session_dir = _get_session_dir(session_id)
    frames = []

    for frame_id in _collect_frame_ids(session_dir):
        frames.append(
            {
                "frame_id": frame_id,
                "pose_image_path": _to_relative_path(session_dir / f"frame_{frame_id}_pose.jpg"),
                "result_json_path": _to_relative_path(session_dir / f"frame_{frame_id}_result.json"),
            }
        )

    return {
        "session_id": session_id,
        "frames": frames,
    }


@router.get("/{session_id}/{frame_id}")
def get_frame_result(session_id: str, frame_id: int) -> dict:
    session_dir = _get_session_dir(session_id)
    result_json_path = session_dir / f"frame_{frame_id}_result.json"

    if not result_json_path.exists() or not result_json_path.is_file():
        raise HTTPException(
            status_code=404,
            detail=f"Result JSON for session '{session_id}' and frame '{frame_id}' not found",
        )

    try:
        with result_json_path.open("r", encoding="utf-8") as result_file:
            return json.load(result_file)
    except json.JSONDecodeError as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Result JSON for session '{session_id}' and frame '{frame_id}' is invalid",
        ) from exc
