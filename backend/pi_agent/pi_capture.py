from __future__ import annotations

import json
import os
import time
from pathlib import Path
from typing import Callable

import zmq

from pi_preview import update_preview_frame


LogFn = Callable[[str], None]
IMAGE_SUFFIXES = (".jpg", ".jpeg", ".png")
DEFAULT_PREVIEW_MAX_WIDTH = int(os.getenv("POSETRACK_PREVIEW_MAX_WIDTH", "480"))
DEFAULT_PREVIEW_MAX_HEIGHT = int(os.getenv("POSETRACK_PREVIEW_MAX_HEIGHT", "360"))
DEFAULT_PREVIEW_JPEG_QUALITY = int(os.getenv("POSETRACK_PREVIEW_JPEG_QUALITY", "45"))
DEFAULT_PREVIEW_STREAM_FPS = float(os.getenv("POSETRACK_PREVIEW_STREAM_FPS", "6"))


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
    picamera2_error: Exception | None = None

    try:
        return _capture_photo_with_picamera2_to_zmq(
            host=host,
            port=port,
            session_id=session_id,
            device_id=device_id,
            camera_index=camera_index,
            width=width,
            height=height,
            warmup_seconds=warmup_seconds,
            logger=logger,
        )
    except RuntimeError as exc:
        picamera2_error = exc
        _log(logger, f"Picamera2 still capture failed, falling back to OpenCV: {exc}")

    cv2 = _import_cv2()
    camera = _open_opencv_camera(
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
            if picamera2_error is not None:
                raise RuntimeError(
                    "Camera did not return a frame for capture_photo. "
                    f"Picamera2 attempt also failed: {picamera2_error}"
                ) from picamera2_error
            raise RuntimeError("Camera did not return a frame for capture_photo.")

        frame_timestamp = time.time()
        frame_bytes = _encode_frame_to_jpeg(cv2, frame)
        _publish_preview_frame(
            cv2,
            frame,
            metadata=_build_preview_metadata(
                frame_id=1,
                session_id=session_id,
                mode="capture_photo_preview",
                timestamp=frame_timestamp,
            ),
        )
        _send_frame_bytes(
            socket=socket,
            session_id=session_id,
            frame_id=1,
            frame_bytes=frame_bytes,
            device_id=device_id,
            message_type="capture_photo",
            filename="camera_photo.jpg",
            source="camera",
            timestamp=frame_timestamp,
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
    picamera2_error: Exception | None = None

    try:
        return _capture_video_with_picamera2_to_zmq(
            host=host,
            port=port,
            session_id=session_id,
            duration_seconds=duration_seconds,
            device_id=device_id,
            camera_index=camera_index,
            width=width,
            height=height,
            fps=fps,
            warmup_seconds=warmup_seconds,
            stop_event=stop_event,
            logger=logger,
        )
    except RuntimeError as exc:
        picamera2_error = exc
        _log(logger, f"Picamera2 video capture failed, falling back to OpenCV: {exc}")

    cv2 = _import_cv2()
    camera = _open_opencv_camera(
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
    preview_sent_at: float | None = None

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
                    if picamera2_error is not None:
                        raise RuntimeError(
                            "Camera repeatedly failed to provide video frames. "
                            f"Picamera2 attempt also failed: {picamera2_error}"
                        ) from picamera2_error
                    raise RuntimeError("Camera repeatedly failed to provide video frames.")
                time.sleep(0.05)
                continue

            read_failures = 0
            frame_id += 1
            frame_timestamp = time.time()
            frame_bytes = _encode_frame_to_jpeg(cv2, frame)
            preview_sent_at = _publish_preview_frame(
                cv2,
                frame,
                last_sent_at=preview_sent_at,
                max_fps=DEFAULT_PREVIEW_STREAM_FPS,
                metadata=_build_preview_metadata(
                    frame_id=frame_id,
                    session_id=session_id,
                    mode="recording_preview",
                    timestamp=frame_timestamp,
                ),
            )
            _send_frame_bytes(
                socket=socket,
                session_id=session_id,
                frame_id=frame_id,
                frame_bytes=frame_bytes,
                device_id=device_id,
                message_type="frame_stream_camera",
                filename=f"camera_frame_{frame_id}.jpg",
                source="camera",
                timestamp=frame_timestamp,
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


def stream_idle_preview(
    camera_index: int = 0,
    width: int | None = None,
    height: int | None = None,
    fps: float = 5.0,
    warmup_seconds: float = 1.0,
    stop_event=None,
    logger: LogFn | None = None,
) -> None:
    picamera2_error: Exception | None = None

    try:
        _stream_idle_preview_with_picamera2(
            camera_index=camera_index,
            width=width,
            height=height,
            fps=fps,
            warmup_seconds=warmup_seconds,
            stop_event=stop_event,
            logger=logger,
        )
        return
    except RuntimeError as exc:
        picamera2_error = exc
        _log(logger, f"Picamera2 idle preview failed, falling back to OpenCV: {exc}")

    cv2 = _import_cv2()
    camera = _open_opencv_camera(
        cv2=cv2,
        camera_index=camera_index,
        width=width,
        height=height,
        fps=fps,
    )
    frame_interval_seconds = 1.0 / max(fps, 1.0)

    idle_frame_id = 0

    try:
        _warm_up_camera(camera, warmup_seconds)

        while stop_event is None or not stop_event.is_set():
            loop_started_at = time.monotonic()
            success, frame = camera.read()
            if success and frame is not None:
                idle_frame_id += 1
                _publish_preview_frame(
                    cv2,
                    frame,
                    metadata=_build_preview_metadata(
                        frame_id=idle_frame_id,
                        session_id=None,
                        mode="idle_preview",
                    ),
                )

            remaining_sleep = frame_interval_seconds - (time.monotonic() - loop_started_at)
            if remaining_sleep > 0:
                if stop_event is not None:
                    stop_event.wait(remaining_sleep)
                else:
                    time.sleep(remaining_sleep)
    except Exception as exc:
        if picamera2_error is not None:
            raise RuntimeError(
                f"OpenCV idle preview also failed after Picamera2 failure: {picamera2_error}; {exc}"
            ) from exc
        raise RuntimeError(f"OpenCV idle preview failed: {exc}") from exc
    finally:
        camera.release()


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
    timestamp: float | None = None,
) -> None:
    metadata = {
        "session_id": session_id,
        "device_id": device_id,
        "frame_id": frame_id,
        "timestamp": time.time() if timestamp is None else float(timestamp),
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


def _import_picamera2():
    try:
        from picamera2 import Picamera2  # type: ignore
    except ImportError as exc:  # pragma: no cover - depends on runtime environment
        raise RuntimeError(
            "Picamera2 is not installed. Install python3-picamera2 on the Raspberry Pi "
            "or provide a V4L2-compatible /dev/video* camera for OpenCV."
        ) from exc

    return Picamera2


def _open_picamera2_camera(
    camera_index: int,
    *,
    logger: LogFn | None = None,
    purpose: str,
    retries: int = 6,
    retry_delay_seconds: float = 0.4,
):
    Picamera2 = _import_picamera2()
    last_error: Exception | None = None

    for attempt in range(1, retries + 1):
        for factory in _picamera2_factories(Picamera2, camera_index):
            try:
                return factory()
            except Exception as exc:  # pragma: no cover - depends on Pi runtime
                last_error = exc

        if attempt < retries:
            _log(
                logger,
                f"Picamera2 open attempt {attempt}/{retries} for {purpose} failed: {last_error}",
            )
            time.sleep(retry_delay_seconds)

    inventory = _describe_picamera2_inventory(Picamera2)
    raise RuntimeError(
        f"Unable to open Picamera2 camera index {camera_index} for {purpose}: {last_error}. "
        f"{inventory}"
    )


def _picamera2_factories(Picamera2, camera_index: int):
    if camera_index == 0:
        return (
            lambda: Picamera2(),
            lambda: Picamera2(camera_num=0),
        )

    return (lambda: Picamera2(camera_num=camera_index),)


def _describe_picamera2_inventory(Picamera2) -> str:
    try:
        camera_info = Picamera2.global_camera_info()
    except Exception as exc:  # pragma: no cover - depends on Pi runtime
        return f"Picamera2 camera inventory unavailable: {exc}"

    if not camera_info:
        return "Picamera2 reported no cameras."

    return f"Picamera2 camera inventory: {camera_info}"


def _open_opencv_camera(
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
    if hasattr(cv2, "CAP_PROP_BUFFERSIZE"):
        camera.set(cv2.CAP_PROP_BUFFERSIZE, 1)

    return camera


def _capture_photo_with_picamera2_to_zmq(
    host: str,
    port: int,
    session_id: str,
    device_id: int | None,
    camera_index: int,
    width: int | None,
    height: int | None,
    warmup_seconds: float,
    logger: LogFn | None,
) -> int:
    cv2 = _import_cv2()
    socket, context = _open_push_socket(host, port)
    picamera2 = None

    try:
        picamera2 = _open_picamera2_camera(
            camera_index,
            logger=logger,
            purpose="still capture",
        )
        configuration = picamera2.create_still_configuration(
            main={
                "size": _resolve_picamera_size(width, height, default=(1296, 972)),
                "format": "RGB888",
            },
            buffer_count=2,
        )
        picamera2.configure(configuration)
        picamera2.start()
        time.sleep(max(warmup_seconds, 1.0))

        frame = picamera2.capture_array("main")
        frame = _normalize_frame_for_jpeg(cv2, frame)
        if frame is None:
            raise RuntimeError("Picamera2 returned an empty frame for capture_photo.")

        frame_timestamp = time.time()
        frame_bytes = _encode_frame_to_jpeg(cv2, frame)
        _publish_preview_frame(
            cv2,
            frame,
            metadata=_build_preview_metadata(
                frame_id=1,
                session_id=session_id,
                mode="capture_photo_preview",
                timestamp=frame_timestamp,
            ),
        )
        _send_frame_bytes(
            socket=socket,
            session_id=session_id,
            frame_id=1,
            frame_bytes=frame_bytes,
            device_id=device_id,
            message_type="capture_photo",
            filename="camera_photo.jpg",
            source="camera",
            timestamp=frame_timestamp,
        )
        _log(logger, "Picamera2 photo captured and sent.")
        return 1
    except Exception as exc:
        raise RuntimeError(f"Picamera2 still capture failed: {exc}") from exc
    finally:
        _close_picamera2(picamera2)
        socket.close(0)
        context.term()


def _capture_video_with_picamera2_to_zmq(
    host: str,
    port: int,
    session_id: str,
    duration_seconds: float,
    device_id: int | None,
    camera_index: int,
    width: int | None,
    height: int | None,
    fps: float,
    warmup_seconds: float,
    stop_event,
    logger: LogFn | None,
) -> int:
    cv2 = _import_cv2()
    socket, context = _open_push_socket(host, port)
    picamera2 = None
    frame_interval_seconds = 1.0 / max(fps, 1.0)
    deadline = time.monotonic() + max(duration_seconds, 1.0)
    frame_id = 0
    preview_sent_at: float | None = None

    try:
        picamera2 = _open_picamera2_camera(
            camera_index,
            logger=logger,
            purpose="video capture",
        )
        frame_duration = int(1_000_000 / max(fps, 1.0))
        configuration = picamera2.create_video_configuration(
            main={
                "size": _resolve_picamera_size(width, height, default=(640, 480)),
                "format": "RGB888",
            },
            controls={"FrameDurationLimits": (frame_duration, frame_duration)},
            buffer_count=4,
        )
        picamera2.configure(configuration)
        picamera2.start()
        time.sleep(max(warmup_seconds, 1.0))

        while time.monotonic() < deadline:
            if stop_event is not None and stop_event.is_set():
                _log(logger, "Picamera2 live capture stopped by stop event.")
                break

            loop_started_at = time.monotonic()
            frame = _normalize_frame_for_jpeg(cv2, picamera2.capture_array("main"))
            if frame is None:
                raise RuntimeError("Picamera2 returned an empty frame during video capture.")

            frame_id += 1
            frame_timestamp = time.time()
            frame_bytes = _encode_frame_to_jpeg(cv2, frame)
            preview_sent_at = _publish_preview_frame(
                cv2,
                frame,
                last_sent_at=preview_sent_at,
                max_fps=DEFAULT_PREVIEW_STREAM_FPS,
                metadata=_build_preview_metadata(
                    frame_id=frame_id,
                    session_id=session_id,
                    mode="recording_preview",
                    timestamp=frame_timestamp,
                ),
            )
            _send_frame_bytes(
                socket=socket,
                session_id=session_id,
                frame_id=frame_id,
                frame_bytes=frame_bytes,
                device_id=device_id,
                message_type="frame_stream_camera",
                filename=f"camera_frame_{frame_id}.jpg",
                source="camera",
                timestamp=frame_timestamp,
            )
            _log(logger, f"Picamera2 live camera frame {frame_id} sent.")

            remaining_sleep = frame_interval_seconds - (time.monotonic() - loop_started_at)
            if remaining_sleep > 0:
                if stop_event is not None:
                    stop_event.wait(remaining_sleep)
                else:
                    time.sleep(remaining_sleep)
    except Exception as exc:
        raise RuntimeError(f"Picamera2 video capture failed: {exc}") from exc
    finally:
        _close_picamera2(picamera2)
        socket.close(0)
        context.term()

    if frame_id == 0:
        raise RuntimeError("Picamera2 did not capture any video frames.")

    return frame_id


def _stream_idle_preview_with_picamera2(
    camera_index: int,
    width: int | None,
    height: int | None,
    fps: float,
    warmup_seconds: float,
    stop_event,
    logger: LogFn | None,
) -> None:
    cv2 = _import_cv2()
    picamera2 = None
    frame_interval_seconds = 1.0 / max(fps, 1.0)
    idle_frame_id = 0

    try:
        picamera2 = _open_picamera2_camera(
            camera_index,
            logger=logger,
            purpose="idle preview",
        )
        frame_duration = int(1_000_000 / max(fps, 1.0))
        configuration = picamera2.create_preview_configuration(
            main={
                "size": _resolve_picamera_size(width, height, default=(640, 480)),
                "format": "RGB888",
            },
            controls={"FrameDurationLimits": (frame_duration, frame_duration)},
            buffer_count=2,
        )
        picamera2.configure(configuration)
        picamera2.start()
        time.sleep(max(warmup_seconds, 1.0))
        _log(logger, "Picamera2 idle preview loop started.")

        while stop_event is None or not stop_event.is_set():
            loop_started_at = time.monotonic()
            frame = _normalize_frame_for_jpeg(cv2, picamera2.capture_array("main"))
            if frame is not None:
                idle_frame_id += 1
                _publish_preview_frame(
                    cv2,
                    frame,
                    metadata=_build_preview_metadata(
                        frame_id=idle_frame_id,
                        session_id=None,
                        mode="idle_preview",
                    ),
                )

            remaining_sleep = frame_interval_seconds - (time.monotonic() - loop_started_at)
            if remaining_sleep > 0:
                if stop_event is not None:
                    stop_event.wait(remaining_sleep)
                else:
                    time.sleep(remaining_sleep)
    except Exception as exc:
        raise RuntimeError(f"Picamera2 idle preview failed: {exc}") from exc
    finally:
        _close_picamera2(picamera2)


def _resolve_picamera_size(
    width: int | None,
    height: int | None,
    default: tuple[int, int],
) -> tuple[int, int]:
    requested_width = width or default[0]
    requested_height = height or default[1]
    return requested_width, requested_height


def _normalize_frame_for_jpeg(cv2, frame):
    if frame is None or getattr(frame, "size", 0) == 0:
        return None

    if len(frame.shape) == 3:
        channels = frame.shape[2]
        # Picamera2 RGB888 arrays are already laid out as BGR for OpenCV users,
        # so a per-frame RGB->BGR conversion here only adds latency.
        if channels == 3:
            return frame
        if channels == 4:
            return cv2.cvtColor(frame, cv2.COLOR_RGBA2BGR)

    return frame


def _close_picamera2(picamera2) -> None:
    if picamera2 is None:
        return

    try:
        picamera2.stop()
    except Exception:
        pass

    try:
        picamera2.close()
    except Exception:
        pass


def _warm_up_camera(camera, warmup_seconds: float) -> None:
    deadline = time.monotonic() + max(warmup_seconds, 0.0)
    while time.monotonic() < deadline:
        camera.read()
        time.sleep(0.05)


def _publish_preview_frame(
    cv2,
    frame,
    *,
    last_sent_at: float | None = None,
    max_fps: float | None = None,
    metadata: dict[str, object] | None = None,
) -> float:
    now = time.monotonic()
    if max_fps is not None and max_fps > 0 and last_sent_at is not None:
        minimum_interval_seconds = 1.0 / max(max_fps, 0.1)
        if now - last_sent_at < minimum_interval_seconds:
            return last_sent_at

    update_preview_frame(
        frame_bytes=_encode_preview_frame_to_jpeg(cv2, frame),
        metadata=metadata,
    )
    return now


def _build_preview_metadata(
    *,
    frame_id: int | None,
    session_id: str | None,
    mode: str,
    timestamp: float | None = None,
) -> dict[str, object]:
    return {
        "frame_id": frame_id,
        "timestamp": time.time() if timestamp is None else float(timestamp),
        "session_id": session_id,
        "mode": mode,
    }


def _encode_preview_frame_to_jpeg(cv2, frame) -> bytes:
    preview_frame = frame
    if frame is None:
        raise RuntimeError("Cannot encode an empty preview frame.")

    frame_height, frame_width = frame.shape[:2]
    scale = min(
        DEFAULT_PREVIEW_MAX_WIDTH / max(frame_width, 1),
        DEFAULT_PREVIEW_MAX_HEIGHT / max(frame_height, 1),
        1.0,
    )

    if scale < 1.0:
        preview_frame = cv2.resize(
            frame,
            (
                max(1, int(frame_width * scale)),
                max(1, int(frame_height * scale)),
            ),
            interpolation=cv2.INTER_AREA,
        )

    return _encode_frame_to_jpeg(
        cv2,
        preview_frame,
        quality=DEFAULT_PREVIEW_JPEG_QUALITY,
    )


def _encode_frame_to_jpeg(cv2, frame, quality: int | None = None) -> bytes:
    params = []
    if quality is not None:
        params = [int(cv2.IMWRITE_JPEG_QUALITY), max(30, min(int(quality), 95))]

    success, encoded_frame = cv2.imencode(".jpg", frame, params)
    if not success:
        raise RuntimeError("Failed to encode captured frame to JPEG.")
    return encoded_frame.tobytes()


def _log(logger: LogFn | None, message: str) -> None:
    if logger is not None:
        logger(message)
