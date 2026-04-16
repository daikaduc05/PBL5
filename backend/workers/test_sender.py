import json
import time
from pathlib import Path

import cv2
import zmq


def main() -> None:
    total_frames = 5
    frame_interval_seconds = 1

    context = zmq.Context()
    socket = context.socket(zmq.PUSH)

    try:
        socket.connect("tcp://127.0.0.1:5555")
        print("[Sender] Connected to tcp://127.0.0.1:5555")

        time.sleep(1)

        # Prefer test_image.jpg in the current folder, then fall back to workers/.
        image_path = Path("test_image.jpg")
        if not image_path.exists():
            fallback_path = Path(__file__).resolve().parent / "test_image.jpg"
            if fallback_path.exists():
                image_path = fallback_path
            else:
                print(
                    "[Sender] Error: image file not found. "
                    "Expected 'test_image.jpg' in the backend folder or backend/workers/."
                )
                return

        image = cv2.imread(str(image_path))
        if image is None:
            print(f"[Sender] Error: failed to load image from {image_path.resolve()}")
            return

        print("[Sender] Image loaded successfully")
        print(f"[Sender] Image shape: {image.shape}")

        success, encoded_image = cv2.imencode(".jpg", image)
        if not success:
            print("[Sender] Error: failed to encode image to JPEG")
            return

        image_bytes = encoded_image.tobytes()
        print(f"[Sender] JPEG bytes length: {len(image_bytes)}")

        # Reuse the same JPEG bytes to simulate a small frame stream.
        for frame_id in range(1, total_frames + 1):
            metadata = {
                "session_id": "sess_001",
                "device_id": "raspi_01",
                "frame_id": frame_id,
                "timestamp": time.time(),
                "message_type": "frame_stream_test",
                "filename": image_path.name,
            }
            metadata_bytes = json.dumps(metadata).encode("utf-8")

            print(f"[Sender] Sending frame {frame_id}/{total_frames}")
            print(f"[Sender] Metadata payload: {metadata}")
            socket.send_multipart([metadata_bytes, image_bytes])
            print(f"[Sender] Sent successfully: frame {frame_id}")

            if frame_id < total_frames:
                time.sleep(frame_interval_seconds)
    finally:
        socket.close(0)
        context.term()


if __name__ == "__main__":
    main()
