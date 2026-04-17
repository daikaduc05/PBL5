import json
import re
from pathlib import Path

from fastapi import APIRouter, HTTPException


router = APIRouter(prefix="/results", tags=["Results"])

BACKEND_ROOT = Path(__file__).resolve().parents[3]
RESULTS_ROOT = BACKEND_ROOT / "workers" / "results"
FRAME_FILE_PATTERN = re.compile(r"^frame_(\d+)_(pose\.jpg|result\.json)$")


def _get_session_dir(session_id: str) -> Path:
    session_dir = RESULTS_ROOT / session_id
    if not session_dir.exists() or not session_dir.is_dir():
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found")
    return session_dir


def _collect_frame_files(session_dir: Path) -> dict[int, dict[str, Path | None]]:
    frames: dict[int, dict[str, Path | None]] = {}

    for file_path in session_dir.iterdir():
        if not file_path.is_file():
            continue

        match = FRAME_FILE_PATTERN.match(file_path.name)
        if match is None:
            continue

        frame_id = int(match.group(1))
        frame_entry = frames.setdefault(
            frame_id,
            {
                "pose_image_path": None,
                "result_json_path": None,
            },
        )

        if file_path.name.endswith("_pose.jpg"):
            frame_entry["pose_image_path"] = file_path
        else:
            frame_entry["result_json_path"] = file_path

    return dict(sorted(frames.items()))


def _to_backend_relative_path(file_path: Path | None) -> str | None:
    if file_path is None:
        return None

    return file_path.relative_to(BACKEND_ROOT).as_posix()


def _build_pose_image_url(pose_image_path: Path | None) -> str | None:
    if pose_image_path is None:
        return None

    static_path = pose_image_path.relative_to(RESULTS_ROOT).as_posix()
    return f"/static/results/{static_path}"


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
def list_session_results(session_id: str) -> dict[str, str | list[dict[str, int | str | None]]]:
    session_dir = _get_session_dir(session_id)
    frames = []

    for frame_id, file_paths in _collect_frame_files(session_dir).items():
        frames.append(
            {
                "frame_id": frame_id,
                "pose_image_path": _to_backend_relative_path(file_paths["pose_image_path"]),
                "result_json_path": _to_backend_relative_path(file_paths["result_json_path"]),
                "pose_image_url": _build_pose_image_url(file_paths["pose_image_path"]),
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
