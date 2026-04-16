import time

import zmq


def main():
    context = zmq.Context()
    socket = context.socket(zmq.PUSH)

    socket.connect("tcp://127.0.0.1:5555")
    print("[Sender] Connected to tcp://127.0.0.1:5555")

    time.sleep(1)

    message = "Hello from Raspberry Pi test sender"
    socket.send_string(message)

    print(f"[Sender] Sent: {message}")


if __name__ == "__main__":
    main()
