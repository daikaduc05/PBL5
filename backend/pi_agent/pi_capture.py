from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Callable

import zmq


LogFn = Callable[[str], None]
IMAGE_SUFFIXES = (".jpg", ".jpeg", ".png")


def has_replay_frames(frames_dir: str | None) -> bool:
    if frames_dir is None:
        return False

    frames_path = Path(frames_dir)
    if not frames_path.exists() or not frames_path.is_dir():
        return False

    return any(
        file_path.is_file() and file_path.suffix.lower() in IMAGE_SUFFIXES
        for file_path in frames_path.iterdir()
    )


def replay_frames_to_zmq(
    frames_dir: str,
    host: str,
    port: int,
    session_id: str,
    device_id: int | None = None,
    frame_interval_seconds: float = 0.1,
    max_frames: int | None = None,
    stop_event=None,
    logger: LogFn | None = None,
) -> int:
    frame_files = _list_frame_files(frames_dir)
    if max_frames is not None:
        frame_files = frame_files[:max_frames]

    if not frame_files:
        raise FileNotFoundError(f"No image files found in {frames_dir}")

    socket, context = _open_push_socket(host, port)
    sent_frames = 0

    try:
        for frame_id, frame_file in enumerate(frame_files, start=1):
            if stop_event is not None and stop_event.is_set():
                _log(logger, "Replay stopped by stop event.")
                break

            frame_bytes = frame_file.read_bytes()
            _send_frame_bytes(
                socket=socket,
                session_id=session_id,
                frame_id=frame_id,
                frame_bytes=frame_bytes,
                device_id=device_id,
                message_type="frame_stream_replay",
                filename=frame_file.name,
                source="replay",
            )
            sent_frames += 1
            _log(logger, f"Replay frame {frame_id} sent: {frame_file.name}")

            if frame_interval_seconds > 0 and frame_id < len(frame_files):
                if stop_event is not None:
                    stop_event.wait(frame_interval_seconds)
                else:
                    time.sleep(frame_interval_seconds)
    finally:
        socket.close(0)
        context.term()

    if sent_frames == 0:
        raise RuntimeError("Replay stopped before any frame was sent.")

    return sent_frames


def capture_photo_to_zmq(
    host: str,
    port: int,
    session_id: str,
    device_id: int | None = None,
    camera_index: int = 0,
    width: int | None = None,
    height: int | None = None,
    warmup_seconds: float = 1.0,
    logger: LogFn | None = None,
) -> int:
    cv2 = _import_cv2()
    camera = _open_camera(
        cv2=cv2,
        camera_index=camera_index,
        width=width,
        height=height,
    )
    socket, context = _open_push_socket(host, port)

    try:
        _warm_up_camera(camera, warmup_seconds)
        success, frame = camera.read()
        if not success or frame is None:
            raise RuntimeError("Camera did not return a frame for capture_photo.")

        frame_bytes = _encode_frame_to_jpeg(cv2, frame)
        _send_frame_bytes(
            socket=socket,
            session_id=session_id,
            frame_id=1,
            frame_bytes=frame_bytes,
            device_id=device_id,
            message_type="capture_photo",
            filename="camera_photo.jpg",
            source="camera",
        )
        _log(logger, "Camera photo captured and sent.")
        return 1
    finally:
        camera.release()
        socket.close(0)
        context.term()


def capture_video_to_zmq(
    host: str,
    port: int,
    session_id: str,
    duration_seconds: float,
    device_id: int | None = None,
    camera_index: int = 0,
    width: int | None = None,
    height: int | None = None,
    fps: float = 10.0,
    warmup_seconds: float = 1.0,
    stop_event=None,
    logger: LogFn | None = None,
) -> int:
    cv2 = _import_cv2()
    camera = _open_camera(
        cv2=cv2,
        camera_index=camera_index,
        width=width,
        height=height,
        fps=fps,
    )
    socket, context = _open_push_socket(host, port)
    frame_interval_seconds = 1.0 / max(fps, 1.0)
    deadline = time.monotonic() + max(duration_seconds, 1.0)
    frame_id = 0
    read_failures = 0

    try:
        _warm_up_camera(camera, warmup_seconds)

        while time.monotonic() < deadline:
            if stop_event is not None and stop_event.is_set():
                _log(logger, "Live capture stopped by stop event.")
                break

            loop_started_at = time.monotonic()
            success, frame = camera.read()
            if not success or frame is None:
                read_failures += 1
                if read_failures >= 5:
                    raise RuntimeError("Camera repeatedly failed to provide video frames.")
                time.sleep(0.05)
                continue

            read_failures = 0
            frame_id += 1
            frame_bytes = _encode_frame_to_jpeg(cv2, frame)
            _send_frame_bytes(
                socket=socket,
                session_id=session_id,
                frame_id=frame_id,
                frame_bytes=frame_bytes,
                device_id=device_id,
                message_type="frame_stream_camera",
                filename=f"camera_frame_{frame_id}.jpg",
                source="camera",
            )
            _log(logger, f"Live camera frame {frame_id} sent.")

            remaining_sleep = frame_interval_seconds - (time.monotonic() - loop_started_at)
            if remaining_sleep > 0:
                if stop_event is not None:
                    stop_event.wait(remaining_sleep)
                else:
                    time.sleep(remaining_sleep)
    finally:
        camera.release()
        socket.close(0)
        context.term()

    if frame_id == 0:
        raise RuntimeError("No live camera frame was captured.")

    return frame_id


def _list_frame_files(frames_dir: str) -> list[Path]:
    frames_path = Path(frames_dir)
    if not frames_path.exists() or not frames_path.is_dir():
        raise FileNotFoundError(f"Replay frames directory not found: {frames_dir}")

    return sorted(
        file_path
        for file_path in frames_path.iterdir()
        if file_path.is_file() and file_path.suffix.lower() in IMAGE_SUFFIXES
    )


def _open_push_socket(host: str, port: int) -> tuple[zmq.Socket, zmq.Context]:
    context = zmq.Context()
    socket = context.socket(zmq.PUSH)
    socket.connect(f"tcp://{host}:{port}")
    return socket, context


def _send_frame_bytes(
    socket: zmq.Socket,
    session_id: str,
    frame_id: int,
    frame_bytes: bytes,
    device_id: int | None,
    message_type: str,
    filename: str,
    source: str,
) -> None:
    metadata = {
        "session_id": session_id,
        "device_id": device_id,
        "frame_id": frame_id,
        "timestamp": time.time(),
        "message_type": message_type,
        "filename": filename,
        "source": source,
    }
    socket.send_multipart([json.dumps(metadata).encode("utf-8"), frame_bytes])


def _import_cv2():
    try:
        import cv2  # type: ignore
    except ImportError as exc:  # pragma: no cover - depends on runtime environment
        raise RuntimeError(
            "OpenCV is required for live camera capture on the Pi agent."
        ) from exc

    return cv2


def _open_camera(
    cv2,
    camera_index: int,
    width: int | None = None,
    height: int | None = None,
    fps: float | None = None,
):
    camera = cv2.VideoCapture(camera_index)
    if not camera.isOpened():
        camera.release()
        raise RuntimeError(f"Unable to open camera index {camera_index}.")

    if width is not None:
        camera.set(cv2.CAP_PROP_FRAME_WIDTH, width)
    if height is not None:
        camera.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
    if fps is not None:
        camera.set(cv2.CAP_PROP_FPS, fps)

    return camera


def _warm_up_camera(camera, warmup_seconds: float) -> None:
    deadline = time.monotonic() + max(warmup_seconds, 0.0)
    while time.monotonic() < deadline:
        camera.read()
        time.sleep(0.05)


def _encode_frame_to_jpeg(cv2, frame) -> bytes:
    success, encoded_frame = cv2.imencode(".jpg", frame)
    if not success:
        raise RuntimeError("Failed to encode captured frame to JPEG.")
    return encoded_frame.tobytes()


def _log(logger: LogFn | None, message: str) -> None:
    if logger is not None:
        logger(message)
