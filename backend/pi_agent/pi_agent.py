#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import threading
import time
from dataclasses import dataclass
from typing import Any

import requests

from pi_capture import (
    capture_photo_to_zmq,
    capture_video_to_zmq,
    has_replay_frames,
    replay_frames_to_zmq,
)


DEFAULT_BACKEND = os.getenv("POSETRACK_BACKEND", "http://localhost:8002")
POLL_INTERVAL = 3
REQUEST_TIMEOUT = 5
DEFAULT_CAMERA_INDEX = int(os.getenv("POSETRACK_CAMERA_INDEX", "0"))
DEFAULT_CAMERA_FPS = float(os.getenv("POSETRACK_CAMERA_FPS", "10"))
DEFAULT_CAMERA_WARMUP_SECONDS = float(os.getenv("POSETRACK_CAMERA_WARMUP", "1.0"))


@dataclass
class ActiveCapture:
    command_id: int
    session_key: str
    command_type: str
    thread: threading.Thread
    stop_event: threading.Event


_ACTIVE_CAPTURE_LOCK = threading.Lock()
_ACTIVE_CAPTURE: ActiveCapture | None = None


def log(message: str) -> None:
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}", flush=True)


def api(method: str, backend: str, path: str, **kwargs) -> dict:
    url = f"{backend.rstrip('/')}{path}"
    kwargs.setdefault("timeout", REQUEST_TIMEOUT)
    response = requests.request(method, url, **kwargs)
    response.raise_for_status()
    return response.json()


def register_device(backend: str, device_name: str, device_code: str) -> tuple[int, str]:
    data = api(
        "POST",
        backend,
        "/api/devices/register",
        json={"device_name": device_name, "device_code": device_code},
    )
    device_id = data["data"]["device_id"]
    auth_token = data["data"]["auth_token"]
    log(f"Registered device_id={device_id}")
    return device_id, auth_token


def send_heartbeat(backend: str, device_id: int) -> None:
    api("POST", backend, f"/api/devices/{device_id}/heartbeat", json={"status": "online"})


def fetch_pending_command(backend: str, device_id: int) -> dict | None:
    data = api("GET", backend, f"/api/devices/{device_id}/commands/pending")
    return data.get("data")


def update_command_status(backend: str, device_id: int, command_id: int, status: str) -> None:
    api(
        "PATCH",
        backend,
        f"/api/devices/{device_id}/commands/{command_id}/status",
        json={"status": status},
    )
    log(f"Command {command_id} -> {status}")


def _load_command_payload(command: dict[str, Any]) -> dict[str, Any]:
    raw_payload = command.get("command_payload")
    if raw_payload is None:
        return {}

    if isinstance(raw_payload, dict):
        return raw_payload

    if isinstance(raw_payload, str):
        try:
            decoded_payload = json.loads(raw_payload)
        except json.JSONDecodeError:
            return {}
        if isinstance(decoded_payload, dict):
            return decoded_payload

    return {}


def _resolve_session_key(command: dict[str, Any], payload: dict[str, Any]) -> str:
    for candidate in (
        payload.get("session_key"),
        payload.get("session_id"),
        command.get("session_key"),
        command.get("session_id"),
    ):
        if candidate is not None:
            if isinstance(candidate, int):
                return f"sess_{candidate:06d}"
            return str(candidate)

    return "default_session"


def _resolve_capture_source(payload: dict[str, Any], frames_dir: str | None) -> str:
    source = str(payload.get("capture_source", "auto")).strip().lower()

    if source == "replay":
        return "replay"
    if source == "camera":
        return "camera"

    if has_replay_frames(frames_dir):
        return "replay"
    return "camera"


def _resolve_capture_duration_seconds(payload: dict[str, Any]) -> float:
    for key in ("actual_duration_seconds", "target_duration_seconds", "duration_seconds"):
        value = payload.get(key)
        try:
            duration = float(value)
        except (TypeError, ValueError):
            continue
        if duration > 0:
            return duration

    return 5.0


def _resolve_int(payload: dict[str, Any], key: str, default: int | None = None) -> int | None:
    value = payload.get(key, default)
    if value is None:
        return None

    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _resolve_float(payload: dict[str, Any], key: str, default: float) -> float:
    value = payload.get(key, default)
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _get_active_capture() -> ActiveCapture | None:
    with _ACTIVE_CAPTURE_LOCK:
        if _ACTIVE_CAPTURE is None:
            return None
        if _ACTIVE_CAPTURE.thread.is_alive():
            return _ACTIVE_CAPTURE
        return None


def _register_active_capture(active_capture: ActiveCapture) -> bool:
    global _ACTIVE_CAPTURE

    with _ACTIVE_CAPTURE_LOCK:
        if _ACTIVE_CAPTURE is not None and _ACTIVE_CAPTURE.thread.is_alive():
            return False

        _ACTIVE_CAPTURE = active_capture
        return True


def _clear_active_capture(command_id: int) -> None:
    global _ACTIVE_CAPTURE

    with _ACTIVE_CAPTURE_LOCK:
        if _ACTIVE_CAPTURE is not None and _ACTIVE_CAPTURE.command_id == command_id:
            _ACTIVE_CAPTURE = None


def _run_capture_job(
    command: dict[str, Any],
    backend: str,
    device_id: int,
    stop_event: threading.Event,
) -> None:
    command_id = int(command["command_id"])
    payload = _load_command_payload(command)
    session_key = _resolve_session_key(command, payload)
    frames_dir = payload.get("frames_dir")
    frames_dir_value = str(frames_dir) if frames_dir else None
    zmq_host = str(payload.get("zmq_host", "localhost"))
    zmq_port = _resolve_int(payload, "zmq_port", 5555) or 5555
    capture_source = _resolve_capture_source(payload, frames_dir_value)
    capture_mode = str(payload.get("capture_mode", "video")).strip().lower()
    camera_index = _resolve_int(payload, "camera_index", DEFAULT_CAMERA_INDEX) or DEFAULT_CAMERA_INDEX
    camera_width = _resolve_int(payload, "camera_width")
    camera_height = _resolve_int(payload, "camera_height")
    camera_fps = _resolve_float(payload, "camera_fps", DEFAULT_CAMERA_FPS)
    warmup_seconds = _resolve_float(payload, "camera_warmup_seconds", DEFAULT_CAMERA_WARMUP_SECONDS)
    replay_interval_seconds = _resolve_float(payload, "replay_interval_seconds", 0.1)

    try:
        if command["command_type"] == "capture_photo" or capture_mode == "image":
            if capture_source == "replay":
                sent_frames = replay_frames_to_zmq(
                    frames_dir=frames_dir_value or "",
                    host=zmq_host,
                    port=zmq_port,
                    session_id=session_key,
                    device_id=device_id,
                    frame_interval_seconds=replay_interval_seconds,
                    max_frames=1,
                    logger=lambda message: log(f"capture_photo replay: {message}"),
                )
            else:
                sent_frames = capture_photo_to_zmq(
                    host=zmq_host,
                    port=zmq_port,
                    session_id=session_key,
                    device_id=device_id,
                    camera_index=camera_index,
                    width=camera_width,
                    height=camera_height,
                    warmup_seconds=warmup_seconds,
                    logger=lambda message: log(f"capture_photo camera: {message}"),
                )
        else:
            duration_seconds = _resolve_capture_duration_seconds(payload)
            if capture_source == "replay":
                sent_frames = replay_frames_to_zmq(
                    frames_dir=frames_dir_value or "",
                    host=zmq_host,
                    port=zmq_port,
                    session_id=session_key,
                    device_id=device_id,
                    frame_interval_seconds=replay_interval_seconds,
                    stop_event=stop_event,
                    logger=lambda message: log(f"start_recording replay: {message}"),
                )
            else:
                sent_frames = capture_video_to_zmq(
                    host=zmq_host,
                    port=zmq_port,
                    session_id=session_key,
                    duration_seconds=duration_seconds,
                    device_id=device_id,
                    camera_index=camera_index,
                    width=camera_width,
                    height=camera_height,
                    fps=camera_fps,
                    warmup_seconds=warmup_seconds,
                    stop_event=stop_event,
                    logger=lambda message: log(f"start_recording camera: {message}"),
                )

        log(f"Capture command {command_id} finished with {sent_frames} frame(s) sent.")
        update_command_status(backend, device_id, command_id, "completed")
    except Exception as exc:
        log(f"[ERROR] Capture command {command_id} failed: {exc}")
        try:
            update_command_status(backend, device_id, command_id, "failed")
        except Exception as update_exc:
            log(f"[ERROR] Failed to update command {command_id} to failed: {update_exc}")
    finally:
        _clear_active_capture(command_id)


def _start_capture_command(command: dict[str, Any], backend: str, device_id: int) -> None:
    command_id = int(command["command_id"])
    payload = _load_command_payload(command)
    session_key = _resolve_session_key(command, payload)
    stop_event = threading.Event()
    capture_thread = threading.Thread(
        target=_run_capture_job,
        args=(command, backend, device_id, stop_event),
        daemon=True,
    )
    active_capture = ActiveCapture(
        command_id=command_id,
        session_key=session_key,
        command_type=str(command["command_type"]),
        thread=capture_thread,
        stop_event=stop_event,
    )

    if not _register_active_capture(active_capture):
        log(f"[WARN] Another capture is already active. Rejecting command {command_id}.")
        update_command_status(backend, device_id, command_id, "failed")
        return

    update_command_status(backend, device_id, command_id, "running")
    capture_thread.start()
    log(f"Capture command {command_id} started in background for session {session_key}.")


def _handle_stop_recording(command: dict[str, Any], backend: str, device_id: int) -> None:
    command_id = int(command["command_id"])
    active_capture = _get_active_capture()

    if active_capture is None or active_capture.command_type != "start_recording":
        log("stop_recording received, but no active recording is running.")
        update_command_status(backend, device_id, command_id, "failed")
        return

    update_command_status(backend, device_id, command_id, "running")
    active_capture.stop_event.set()
    active_capture.thread.join(timeout=15)

    if active_capture.thread.is_alive():
        log(f"[ERROR] stop_recording timed out for active command {active_capture.command_id}.")
        update_command_status(backend, device_id, command_id, "failed")
        return

    update_command_status(backend, device_id, command_id, "completed")
    log(f"stop_recording completed for active command {active_capture.command_id}.")


def handle_command(command: dict[str, Any], backend: str, device_id: int) -> None:
    command_id = int(command["command_id"])
    command_type = str(command["command_type"])
    log(f"Received command {command_id} ({command_type})")

    if command_type == "start_recording":
        _start_capture_command(command, backend, device_id)
        return

    if command_type == "capture_photo":
        _start_capture_command(command, backend, device_id)
        return

    if command_type == "stop_recording":
        _handle_stop_recording(command, backend, device_id)
        return

    log(f"[WARN] Unknown command type: {command_type}")
    update_command_status(backend, device_id, command_id, "failed")


def run(backend: str, device_id: int) -> None:
    log(f"Agent started with backend={backend}, device_id={device_id}")
    log("Press Ctrl+C to stop.")

    while True:
        try:
            send_heartbeat(backend, device_id)

            command = fetch_pending_command(backend, device_id)
            if command:
                handle_command(command, backend, device_id)
        except requests.exceptions.ConnectionError:
            log("[WARN] Cannot connect to backend. Will retry next cycle.")
        except requests.exceptions.Timeout:
            log("[WARN] Request timed out. Will retry next cycle.")
        except requests.exceptions.HTTPError as exc:
            log(f"[WARN] HTTP error: {exc}")
        except Exception as exc:
            log(f"[ERROR] Unexpected error: {exc}")

        time.sleep(POLL_INTERVAL)


def main() -> None:
    parser = argparse.ArgumentParser(description="PoseTrack Pi Agent")
    parser.add_argument(
        "--backend",
        default=DEFAULT_BACKEND,
        help="Backend base URL (default: %(default)s)",
    )
    parser.add_argument("--device-name", default="Raspberry Pi 4B")
    parser.add_argument("--device-code", default="pi-001")
    parser.add_argument(
        "--device-id",
        type=int,
        default=int(os.getenv("POSETRACK_DEVICE_ID", "0")) or None,
        help="Use existing device_id instead of registering again",
    )
    args = parser.parse_args()

    device_id = args.device_id
    if not device_id:
        device_id, _ = register_device(args.backend, args.device_name, args.device_code)

    run(args.backend, device_id)


if __name__ == "__main__":
    main()
