#!/usr/bin/env python3
"""
PoseTrack Pi Agent
==================
Chạy trên Raspberry Pi. Vòng lặp chính:
  1. Đăng ký device với backend (nếu chưa có device_id).
  2. Mỗi 3 giây:
     - Gửi heartbeat.
     - Polling lấy pending command.
     - Nếu có command → thực thi → PATCH status về backend.

Cách dùng:
  python pi_agent.py --backend http://<IP>:8002 --device-name "Pi4B" --device-code "pi-001"

Biến môi trường:
  POSETRACK_BACKEND  : URL backend, mặc định http://localhost:8002
  POSETRACK_DEVICE_ID: ID device nếu đã đăng ký trước
  POSETRACK_TOKEN    : auth_token nếu đã đăng ký trước
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time

import requests

# ── Cấu hình ────────────────────────────────────────────────────────────────

DEFAULT_BACKEND = os.getenv("POSETRACK_BACKEND", "http://localhost:8002")
POLL_INTERVAL = 3  # giây giữa mỗi lần poll
REQUEST_TIMEOUT = 5  # timeout cho từng HTTP request


# ── Helpers ──────────────────────────────────────────────────────────────────

def log(msg: str) -> None:
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{ts}] {msg}", flush=True)


def api(method: str, backend: str, path: str, **kwargs) -> dict:
    url = f"{backend.rstrip('/')}{path}"
    kwargs.setdefault("timeout", REQUEST_TIMEOUT)
    resp = requests.request(method, url, **kwargs)
    resp.raise_for_status()
    return resp.json()


# ── Lifecycle functions ───────────────────────────────────────────────────────

def register_device(backend: str, device_name: str, device_code: str) -> tuple[int, str]:
    """Đăng ký device, trả về (device_id, auth_token)."""
    data = api(
        "POST", backend, "/api/devices/register",
        json={"device_name": device_name, "device_code": device_code},
    )
    device_id = data["data"]["device_id"]
    auth_token = data["data"]["auth_token"]
    log(f"Registered → device_id={device_id}")
    return device_id, auth_token


def send_heartbeat(backend: str, device_id: int) -> None:
    api("POST", backend, f"/api/devices/{device_id}/heartbeat", json={"status": "online"})


def fetch_pending_command(backend: str, device_id: int) -> dict | None:
    data = api("GET", backend, f"/api/devices/{device_id}/commands/pending")
    return data.get("data")  # None nếu không có dispatchable command


def update_command_status(backend: str, device_id: int, command_id: int, status: str) -> None:
    """Báo backend trạng thái command trong lifecycle xử lý."""
    api(
        "PATCH",
        backend,
        f"/api/devices/{device_id}/commands/{command_id}/status",
        json={"status": status},
    )
    log(f"Command {command_id} → {status}")


# ── Command handlers ──────────────────────────────────────────────────────────

def _resolve_session_key(command: dict, payload: dict) -> str:
    payload_session_key = payload.get("session_key")
    if payload_session_key:
        return str(payload_session_key)

    payload_session_id = payload.get("session_id")
    if payload_session_id:
        return str(payload_session_id)

    command_session_key = command.get("session_key")
    if command_session_key:
        return str(command_session_key)

    command_session_id = command.get("session_id")
    if command_session_id is not None:
        return f"sess_{int(command_session_id):06d}"

    return "default_session"


def handle_start_recording(command: dict, backend: str, device_id: int) -> None:
    command_id: int = command["command_id"]
    payload_str: str | None = command.get("command_payload")

    log(f"Executing start_recording (command_id={command_id})")
    update_command_status(backend, device_id, command_id, "running")

    try:
        payload: dict = json.loads(payload_str) if payload_str else {}
    except json.JSONDecodeError:
        payload = {}

    frames_dir: str | None = payload.get("frames_dir")
    zmq_host: str = payload.get("zmq_host", "localhost")
    zmq_port: int = int(payload.get("zmq_port", 5555))
    session_key = _resolve_session_key(command, payload)

    if frames_dir is None:
        log("  [WARN] frames_dir not in payload — skipping ZMQ send")
        update_command_status(backend, device_id, command_id, "failed")
        return

    # Gọi pi_zmq_sender.py nếu tồn tại, hoặc implement trực tiếp bên dưới
    sender_script = os.path.join(os.path.dirname(__file__), "pi_zmq_sender.py")

    if os.path.exists(sender_script):
        cmd = [
            sys.executable, sender_script,
            "--frames-dir", frames_dir,
            "--host", zmq_host,
            "--port", str(zmq_port),
            "--session-id", session_key,
        ]
        log(f"  Running: {' '.join(cmd)}")
        result = subprocess.run(cmd, timeout=120)
        if result.returncode == 0:
            update_command_status(backend, device_id, command_id, "completed")
        else:
            log(f"  [ERROR] pi_zmq_sender exited with code {result.returncode}")
            update_command_status(backend, device_id, command_id, "failed")
    else:
        # Fallback: gửi thẳng qua ZMQ nếu có thư viện
        log(f"  pi_zmq_sender.py not found, attempting inline ZMQ send...")
        try:
            _inline_zmq_send(frames_dir, zmq_host, zmq_port, session_key)
            update_command_status(backend, device_id, command_id, "completed")
        except Exception as exc:
            log(f"  [ERROR] Inline ZMQ send failed: {exc}")
            update_command_status(backend, device_id, command_id, "failed")


def _inline_zmq_send(frames_dir: str, host: str, port: int, session_id: str) -> None:
    import zmq
    from pathlib import Path

    frames_path = Path(frames_dir)
    frame_files = sorted(frames_path.glob("*.jpg")) + sorted(frames_path.glob("*.png"))
    if not frame_files:
        raise FileNotFoundError(f"No image files found in {frames_dir}")

    ctx = zmq.Context()
    sock = ctx.socket(zmq.PUSH)
    sock.connect(f"tcp://{host}:{port}")

    for idx, frame_file in enumerate(frame_files, start=1):
        with frame_file.open("rb") as f:
            frame_bytes = f.read()
        meta = json.dumps({
            "session_id": session_id,
            "frame_index": idx,
            "total_frames": len(frame_files),
            "filename": frame_file.name,
        }).encode()
        sock.send_multipart([meta, frame_bytes])
        log(f"  Sent frame {idx}/{len(frame_files)}: {frame_file.name}")

    sock.close()
    ctx.term()
    log(f"  ZMQ send complete ({len(frame_files)} frames)")


def handle_command(command: dict, backend: str, device_id: int) -> None:
    command_id: int = command["command_id"]
    command_type: str = command["command_type"]

    log(f"Got command: type={command_type}, id={command_id}")

    if command_type == "start_recording":
        handle_start_recording(command, backend, device_id)
    elif command_type == "stop_recording":
        update_command_status(backend, device_id, command_id, "running")
        log("  stop_recording: no action needed in this version")
        update_command_status(backend, device_id, command_id, "completed")
    elif command_type == "capture_photo":
        update_command_status(backend, device_id, command_id, "running")
        log("  capture_photo: not implemented yet")
        update_command_status(backend, device_id, command_id, "failed")
    else:
        update_command_status(backend, device_id, command_id, "running")
        log(f"  [WARN] Unknown command type: {command_type}")
        update_command_status(backend, device_id, command_id, "failed")


# ── Main loop ─────────────────────────────────────────────────────────────────

def run(backend: str, device_id: int) -> None:
    log(f"Agent started — backend={backend}, device_id={device_id}")
    log("Press Ctrl+C to stop.")

    while True:
        try:
            send_heartbeat(backend, device_id)

            command = fetch_pending_command(backend, device_id)
            if command:
                handle_command(command, backend, device_id)

        except requests.exceptions.ConnectionError:
            log("[WARN] Cannot connect to backend — will retry next cycle")
        except requests.exceptions.Timeout:
            log("[WARN] Request timed out — will retry next cycle")
        except requests.exceptions.HTTPError as exc:
            log(f"[WARN] HTTP error: {exc}")
        except Exception as exc:
            log(f"[ERROR] Unexpected error: {exc}")

        time.sleep(POLL_INTERVAL)


# ── Entry point ───────────────────────────────────────────────────────────────

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
