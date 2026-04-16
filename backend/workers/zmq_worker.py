"""Simple ZeroMQ worker used to test incoming messages."""

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
                # Wait for the next string message from the sender.
                message = socket.recv_string()
                print(f"[ZMQ Worker] Received message: {message}")
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
