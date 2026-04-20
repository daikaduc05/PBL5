import json

from fastapi import APIRouter, HTTPException

from app.services.result_service import (
    build_session_result_payload,
    get_session_dir,
    list_result_sessions as list_result_session_ids,
)

router = APIRouter(prefix="/results", tags=["Results"])


@router.get("/sessions")
def list_result_sessions() -> dict[str, list[str]]:
    return {"sessions": list_result_session_ids()}


@router.get("/{session_id}")
def list_session_results(session_id: str) -> dict[str, str | list[dict[str, int | str | None]]]:
    try:
        return build_session_result_payload(session_id)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found") from exc


@router.get("/{session_id}/{frame_id}")
def get_frame_result(session_id: str, frame_id: int) -> dict:
    session_dir = get_session_dir(session_id)
    if session_dir is None:
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found")

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
