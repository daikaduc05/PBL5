"""Simple ZeroMQ worker used to test incoming messages."""

import json
import sys
from pathlib import Path
from typing import Callable

import zmq

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

WORKER_DIR = Path(__file__).resolve().parent
_RUN_POSE_INFERENCE: Callable[[str, str | None], dict] | None = None


def get_pose_inference_runner() -> Callable[[str, str | None], dict]:
    """Import and cache the pose inference function on first use."""
    global _RUN_POSE_INFERENCE

    if _RUN_POSE_INFERENCE is None:
        from core_model.inference import run_pose_inference

        _RUN_POSE_INFERENCE = run_pose_inference

    return _RUN_POSE_INFERENCE


def save_result_json(result_payload: dict, result_json_path: Path) -> None:
    """Persist inference metadata for a processed frame without crashing the worker."""
    try:
        with result_json_path.open("w", encoding="utf-8") as result_file:
            json.dump(result_payload, result_file, indent=2, ensure_ascii=False)

        print(f"[ZMQ Worker] JSON result path: {result_json_path}")
        print(f"[ZMQ Worker] JSON success: {result_payload.get('success', False)}")
        print(f"[ZMQ Worker] JSON num_detections: {result_payload.get('num_detections', 0)}")
    except Exception as exc:
        print(f"[ZMQ Worker] Error writing result JSON file: {exc}")


def run_pose_for_saved_frame(input_path: Path, session_id: str, frame_id: str, metadata: dict) -> None:
    """Run pose inference for a saved frame without interrupting the worker loop."""
    results_dir = WORKER_DIR / "results" / session_id
    results_dir.mkdir(parents=True, exist_ok=True)
    result_path = results_dir / f"frame_{frame_id}_pose.jpg"
    result_json_path = results_dir / f"frame_{frame_id}_result.json"

    print(f"[ZMQ Worker] Pose input frame path: {input_path}")
    print(f"[ZMQ Worker] Pose output result path: {result_path}")

    result = {
        "success": False,
        "num_detections": 0,
        "output_path": None,
    }

    try:
        pose_inference_runner = get_pose_inference_runner()
        result = pose_inference_runner(str(input_path), str(result_path))
        print(f"[ZMQ Worker] Pose inference result: {result}")
        if not result.get("success", False):
            print("[ZMQ Worker] Warning: pose inference returned success=False.")
    except Exception as exc:
        result["error"] = str(exc)
        print(f"[ZMQ Worker] Error during pose inference: {exc}")

    result_payload = {
        "session_id": session_id,
        "frame_id": frame_id,
        "device_id": metadata.get("device_id"),
        "filename": metadata.get("filename"),
        "timestamp": metadata.get("timestamp"),
        "message_type": metadata.get("message_type"),
        "input_path": str(input_path),
        "pose_output_path": str(result_path),
        "success": result.get("success", False),
        "num_detections": result.get("num_detections", 0),
        "inference_result": result,
    }
    save_result_json(result_payload, result_json_path)


def main() -> None:
    """Start a PULL worker and keep listening for multipart messages."""
    context = zmq.Context()
    socket = context.socket(zmq.PULL)
    socket.bind("tcp://*:5555")

    print("[ZMQ Worker] Started and listening on tcp://*:5555")

    try:
        while True:
            try:
                # Receive multipart data: metadata bytes + payload bytes.
                parts = socket.recv_multipart()
                print(f"[ZMQ Worker] Received multipart with {len(parts)} part(s)")

                if len(parts) < 2:
                    print("[ZMQ Worker] Warning: multipart message does not match expected format.")
                    continue

                metadata_bytes = parts[0]
                image_bytes = parts[1]

                try:
                    metadata_json = metadata_bytes.decode("utf-8")
                    metadata = json.loads(metadata_json)
                    session_id = str(metadata.get("session_id", "unknown_session"))
                    frame_id = str(metadata.get("frame_id", "unknown"))

                    print(f"[ZMQ Worker] Raw metadata JSON: {metadata_json}")
                    print(f"[ZMQ Worker] session_id: {session_id}")
                    print(f"[ZMQ Worker] device_id: {metadata.get('device_id')}")
                    print(f"[ZMQ Worker] frame_id: {frame_id}")
                    print(f"[ZMQ Worker] timestamp: {metadata.get('timestamp')}")
                    print(f"[ZMQ Worker] message_type: {metadata.get('message_type')}")
                    print(f"[ZMQ Worker] filename: {metadata.get('filename')}")
                    print(f"[ZMQ Worker] image byte length: {len(image_bytes)}")

                    try:
                        # Group received frames by session to mirror backend storage.
                        output_dir = WORKER_DIR / "output" / session_id
                        output_dir.mkdir(parents=True, exist_ok=True)
                        output_path = output_dir / f"frame_{frame_id}.jpg"
                        output_path.write_bytes(image_bytes)
                        print(f"[ZMQ Worker] Output directory: {output_dir}")
                        print(f"[ZMQ Worker] Output path: {output_path}")
                        print(f"[ZMQ Worker] Saved session_id: {session_id}")
                        print(f"[ZMQ Worker] Saved frame_id: {frame_id}")
                        print(f"[ZMQ Worker] Saved bytes length: {len(image_bytes)}")
                        run_pose_for_saved_frame(output_path, session_id, frame_id, metadata)
                    except OSError as exc:
                        print(f"[ZMQ Worker] Error writing image file: {exc}")
                except (UnicodeDecodeError, json.JSONDecodeError) as exc:
                    print(f"[ZMQ Worker] Error parsing metadata JSON: {exc}")
            except Exception as exc:
                # Keep the worker alive so it can continue receiving later messages.
                print(f"[ZMQ Worker] Error while receiving message: {exc}")
    except KeyboardInterrupt:
        print("[ZMQ Worker] Stopped by user.")
    finally:
        socket.close(0)
        context.term()


if __name__ == "__main__":
    main()
