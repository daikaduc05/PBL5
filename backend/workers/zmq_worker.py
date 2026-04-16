"""Simple ZeroMQ worker used to test incoming messages."""

import json
from pathlib import Path

import zmq


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
                    session_id = metadata.get("session_id", "unknown_session")
                    frame_id = metadata.get("frame_id", "unknown")

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
                        output_dir = Path(__file__).resolve().parent / "output" / session_id
                        output_dir.mkdir(parents=True, exist_ok=True)
                        output_path = output_dir / f"frame_{frame_id}.jpg"
                        output_path.write_bytes(image_bytes)
                        print(f"[ZMQ Worker] Output directory: {output_dir}")
                        print(f"[ZMQ Worker] Output path: {output_path}")
                        print(f"[ZMQ Worker] Saved session_id: {session_id}")
                        print(f"[ZMQ Worker] Saved frame_id: {frame_id}")
                        print(f"[ZMQ Worker] Saved bytes length: {len(image_bytes)}")
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
