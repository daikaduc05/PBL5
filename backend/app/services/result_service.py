import re
from pathlib import Path
from typing import Any


BACKEND_ROOT = Path(__file__).resolve().parents[2]
RESULTS_ROOT = BACKEND_ROOT / "workers" / "results"
FRAME_FILE_PATTERN = re.compile(r"^frame_(\d+)_(pose\.jpg|result\.json)$")


def get_session_dir(session_id: str) -> Path | None:
    session_dir = RESULTS_ROOT / session_id
    if not session_dir.exists() or not session_dir.is_dir():
        return None
    return session_dir


def collect_frame_files(session_dir: Path) -> dict[int, dict[str, Path | None]]:
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


def to_backend_relative_path(file_path: Path | None) -> str | None:
    if file_path is None:
        return None

    return file_path.relative_to(BACKEND_ROOT).as_posix()


def build_pose_image_url(pose_image_path: Path | None) -> str | None:
    if pose_image_path is None:
        return None

    static_path = pose_image_path.relative_to(RESULTS_ROOT).as_posix()
    return f"/static/results/{static_path}"


def build_frame_payload(
    frame_id: int,
    file_paths: dict[str, Path | None],
) -> dict[str, int | str | None]:
    return {
        "frame_id": frame_id,
        "pose_image_path": to_backend_relative_path(file_paths["pose_image_path"]),
        "result_json_path": to_backend_relative_path(file_paths["result_json_path"]),
        "pose_image_url": build_pose_image_url(file_paths["pose_image_path"]),
    }


def build_session_result_payload(session_id: str) -> dict[str, str | list[dict[str, int | str | None]]]:
    session_dir = get_session_dir(session_id)
    if session_dir is None:
        raise FileNotFoundError(session_id)

    frames = [
        build_frame_payload(frame_id=frame_id, file_paths=file_paths)
        for frame_id, file_paths in collect_frame_files(session_dir).items()
    ]

    return {
        "session_id": session_id,
        "frames": frames,
    }


def list_result_sessions() -> list[str]:
    if not RESULTS_ROOT.exists():
        return []

    return sorted(
        session_dir.name
        for session_dir in RESULTS_ROOT.iterdir()
        if session_dir.is_dir()
    )


def build_history_result_metadata(session_id: str) -> dict[str, Any]:
    session_dir = get_session_dir(session_id)
    frames: list[dict[str, int | str | None]] = []

    if session_dir is not None:
        frames = [
            build_frame_payload(frame_id=frame_id, file_paths=file_paths)
            for frame_id, file_paths in collect_frame_files(session_dir).items()
        ]

    latest_frame = frames[-1] if frames else None

    latest_result_frame = next(
        (frame for frame in reversed(frames) if frame["result_json_path"] is not None),
        None,
    )

    latest_pose_frame = next(
        (frame for frame in reversed(frames) if frame["pose_image_url"] is not None),
        None,
    )

    return {
        "session_id": session_id,
        "session_exists": session_dir is not None,
        "result_session_url": f"/api/results/{session_id}",
        "frame_count": len(frames),
        "pose_ready_count": sum(1 for frame in frames if frame["pose_image_url"] is not None),
        "result_ready_count": sum(1 for frame in frames if frame["result_json_path"] is not None),
        "latest_frame": latest_frame,
        "latest_pose_frame": latest_pose_frame,
        "latest_result_frame": latest_result_frame,
    }
