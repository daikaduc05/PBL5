"""Simple ZeroMQ worker used to test incoming messages."""

import json

import zmq


def main() -> None:
    """Start a PULL worker and keep listening for string messages."""
    context = zmq.Context()
    socket = context.socket(zmq.PULL)
    socket.bind("tcp://*:5555")

    print("[ZMQ Worker] Started and listening on tcp://*:5555")

    try:
        while True:
            try:
                # Receive the raw string first so we can inspect it before parsing.
                raw_message = socket.recv_string()
                print(f"[ZMQ Worker] Raw message: {raw_message}")

                try:
                    metadata = json.loads(raw_message)
                    print("[ZMQ Worker] Parsed metadata:")
                    print(f"  session_id: {metadata.get('session_id')}")
                    print(f"  device_id: {metadata.get('device_id')}")
                    print(f"  frame_id: {metadata.get('frame_id')}")
                    print(f"  timestamp: {metadata.get('timestamp')}")
                    print(f"  message_type: {metadata.get('message_type')}")
                except json.JSONDecodeError:
                    print("[ZMQ Worker] Warning: message is not valid JSON.")
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
