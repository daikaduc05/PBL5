import json
import time

import zmq


def main():
    context = zmq.Context()
    socket = context.socket(zmq.PUSH)

    socket.connect("tcp://127.0.0.1:5555")
    print("[Sender] Connected to tcp://127.0.0.1:5555")

    time.sleep(1)

    metadata = {
        "session_id": "sess_001",
        "device_id": "raspi_01",
        "frame_id": 1,
        "timestamp": time.time(),
        "message_type": "frame_metadata_test",
    }
    message = json.dumps(metadata)

    print("[Sender] Sending metadata JSON...")
    print(f"[Sender] Payload: {message}")
    socket.send_string(message)
    print("[Sender] Sent successfully")


if __name__ == "__main__":
    main()
