from __future__ import annotations

import json
import queue
import socket
import threading
import time
from dataclasses import dataclass
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Callable
from urllib.parse import urlparse


LogFn = Callable[[str], None]
PREVIEW_SOCKET_HANDSHAKE = b"POSETRACK_PREVIEW 1\n"
PREVIEW_SOCKET_HANDSHAKE_OK = b"POSETRACK_PREVIEW_OK\n"
DEFAULT_PREVIEW_SOCKET_PORT = 8082


@dataclass
class PreviewFrameSnapshot:
    frame_bytes: bytes | None
    content_type: str
    updated_at: float | None


class PreviewFrameStore:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._frame_bytes: bytes | None = None
        self._content_type = "image/jpeg"
        self._updated_at: float | None = None

    def update(self, frame_bytes: bytes, content_type: str = "image/jpeg") -> None:
        with self._lock:
            self._frame_bytes = frame_bytes
            self._content_type = content_type
            self._updated_at = time.time()

    def snapshot(self) -> PreviewFrameSnapshot:
        with self._lock:
            return PreviewFrameSnapshot(
                frame_bytes=self._frame_bytes,
                content_type=self._content_type,
                updated_at=self._updated_at,
            )


_PREVIEW_STORE = PreviewFrameStore()


class PreviewSocketClient:
    def __init__(
        self,
        conn: socket.socket,
        address: tuple[str, int],
        hub: "PreviewSocketHub",
        logger: LogFn | None = None,
    ) -> None:
        self._conn = conn
        self._address = address
        self._hub = hub
        self._logger = logger
        self._queue: queue.Queue[bytes | None] = queue.Queue(maxsize=1)
        self._thread = threading.Thread(target=self._send_loop, daemon=True)
        self._closed = False
        self._lock = threading.Lock()

    def start(self) -> None:
        self._thread.start()

    def offer(self, frame_bytes: bytes) -> None:
        if self._closed:
            return

        try:
            if self._queue.full():
                self._queue.get_nowait()
            self._queue.put_nowait(frame_bytes)
        except queue.Full:
            return

    def close(self) -> None:
        with self._lock:
            if self._closed:
                return
            self._closed = True

        try:
            self._queue.put_nowait(None)
        except queue.Full:
            pass

        try:
            self._conn.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass

        try:
            self._conn.close()
        except OSError:
            pass

    def _send_loop(self) -> None:
        try:
            while True:
                frame_bytes = self._queue.get()
                if frame_bytes is None:
                    return

                header = len(frame_bytes).to_bytes(4, byteorder="big", signed=False)
                self._conn.sendall(header)
                self._conn.sendall(frame_bytes)
        except OSError as exc:
            if self._logger is not None:
                self._logger(
                    f"Preview socket client {self._address[0]}:{self._address[1]} disconnected: {exc}"
                )
        finally:
            self._hub.unregister(self)
            self.close()


class PreviewSocketHub:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._clients: set[PreviewSocketClient] = set()

    def register(self, client: PreviewSocketClient) -> None:
        with self._lock:
            self._clients.add(client)

    def unregister(self, client: PreviewSocketClient) -> None:
        with self._lock:
            self._clients.discard(client)

    def broadcast(self, frame_bytes: bytes) -> None:
        with self._lock:
            clients = list(self._clients)

        for client in clients:
            client.offer(frame_bytes)

    def close(self) -> None:
        with self._lock:
            clients = list(self._clients)
            self._clients.clear()

        for client in clients:
            client.close()

    def client_count(self) -> int:
        with self._lock:
            return len(self._clients)


_PREVIEW_SOCKET_HUB = PreviewSocketHub()


class PreviewSocketServer:
    def __init__(
        self,
        host: str,
        port: int,
        logger: LogFn | None = None,
    ) -> None:
        self.host = host
        self.port = port
        self._logger = logger
        self._server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._set_socket_option(self._server_socket, socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
        self._server_socket.bind((host, port))
        self._server_socket.listen()
        self._server_socket.settimeout(1.0)
        self._stop_event = threading.Event()
        self._thread = threading.Thread(target=self._accept_loop, daemon=True)
        self._thread.start()

    def close(self) -> None:
        self._stop_event.set()
        try:
            self._server_socket.close()
        except OSError:
            pass
        self._thread.join(timeout=2)
        _PREVIEW_SOCKET_HUB.close()
        if self._logger is not None:
            self._logger("Preview socket server stopped.")

    def _accept_loop(self) -> None:
        while not self._stop_event.is_set():
            try:
                conn, address = self._server_socket.accept()
            except socket.timeout:
                continue
            except OSError:
                return

            try:
                self._handle_client(conn, address)
            except Exception as exc:  # pragma: no cover - runtime network handling
                if self._logger is not None:
                    self._logger(
                        f"Preview socket handshake failed for {address[0]}:{address[1]}: {exc}"
                    )
                try:
                    conn.close()
                except OSError:
                    pass

    def _handle_client(self, conn: socket.socket, address: tuple[str, int]) -> None:
        self._set_socket_option(conn, socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self._set_socket_option(conn, socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
        conn.settimeout(4.0)
        handshake = _read_handshake_line(conn)
        if handshake != PREVIEW_SOCKET_HANDSHAKE:
            raise RuntimeError("Invalid preview handshake.")

        conn.sendall(PREVIEW_SOCKET_HANDSHAKE_OK)
        conn.settimeout(None)

        client = PreviewSocketClient(conn=conn, address=address, hub=_PREVIEW_SOCKET_HUB, logger=self._logger)
        _PREVIEW_SOCKET_HUB.register(client)

        snapshot = _PREVIEW_STORE.snapshot()
        if snapshot.frame_bytes is not None:
            client.offer(snapshot.frame_bytes)

        client.start()

        if self._logger is not None:
            self._logger(f"Preview socket client connected: {address[0]}:{address[1]}")

    @staticmethod
    def _set_socket_option(sock: socket.socket, level: int, option: int, value: int) -> None:
        try:
            sock.setsockopt(level, option, value)
        except OSError:
            pass


class LivePreviewServer:
    def __init__(
        self,
        server: ThreadingHTTPServer,
        thread: threading.Thread,
        host: str,
        port: int,
        socket_server: PreviewSocketServer | None = None,
        socket_port: int | None = None,
        logger: LogFn | None = None,
    ) -> None:
        self._server = server
        self._thread = thread
        self.host = host
        self.port = port
        self.socket_port = socket_port
        self._socket_server = socket_server
        self._logger = logger

    def close(self) -> None:
        self._server.shutdown()
        self._server.server_close()
        self._thread.join(timeout=2)
        if self._socket_server is not None:
            self._socket_server.close()
        if self._logger is not None:
            self._logger("Live preview server stopped.")


def update_preview_frame(frame_bytes: bytes, content_type: str = "image/jpeg") -> None:
    _PREVIEW_STORE.update(frame_bytes=frame_bytes, content_type=content_type)
    _PREVIEW_SOCKET_HUB.broadcast(frame_bytes)


def start_preview_server(
    host: str = "0.0.0.0",
    port: int = 8081,
    socket_port: int = DEFAULT_PREVIEW_SOCKET_PORT,
    logger: LogFn | None = None,
) -> LivePreviewServer:
    handler = _build_preview_handler(store=_PREVIEW_STORE, socket_port=socket_port)
    server = ThreadingHTTPServer((host, port), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    socket_server = None
    if socket_port > 0:
        socket_server = PreviewSocketServer(host=host, port=socket_port, logger=logger)

    if logger is not None:
        logger(f"Live preview server started on http://{host}:{port}")
        if socket_server is not None:
            logger(f"Live preview socket started on tcp://{host}:{socket_port}")

    return LivePreviewServer(
        server=server,
        thread=thread,
        host=host,
        port=port,
        socket_server=socket_server,
        socket_port=socket_port,
        logger=logger,
    )


def _build_preview_handler(store: PreviewFrameStore, socket_port: int):
    class PreviewHandler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:  # noqa: N802
            path = urlparse(self.path).path

            if path == "/health":
                snapshot = store.snapshot()
                self._write_json(
                    HTTPStatus.OK,
                    {
                        "success": True,
                        "ready": snapshot.frame_bytes is not None,
                        "updated_at": snapshot.updated_at,
                        "socket_port": socket_port,
                        "socket_clients": _PREVIEW_SOCKET_HUB.client_count(),
                    },
                )
                return

            if path in {"/preview/latest.jpg", "/preview/latest"}:
                snapshot = store.snapshot()
                if snapshot.frame_bytes is None:
                    self._write_json(
                        HTTPStatus.SERVICE_UNAVAILABLE,
                        {
                            "success": False,
                            "message": "Preview is not ready yet. Start preview or capture first.",
                        },
                    )
                    return

                self.send_response(HTTPStatus.OK)
                self.send_header("Content-Type", snapshot.content_type)
                self.send_header("Content-Length", str(len(snapshot.frame_bytes)))
                self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
                self.send_header("Pragma", "no-cache")
                self.end_headers()
                self.wfile.write(snapshot.frame_bytes)
                return

            self._write_json(
                HTTPStatus.NOT_FOUND,
                {"success": False, "message": f"Unknown preview path: {path}"},
            )

        def log_message(self, format: str, *args) -> None:  # noqa: A003
            return

        def _write_json(self, status_code: HTTPStatus, payload: dict) -> None:
            body = json.dumps(payload).encode("utf-8")
            self.send_response(status_code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
            self.end_headers()
            self.wfile.write(body)

    return PreviewHandler


def _read_handshake_line(conn: socket.socket, max_bytes: int = 64) -> bytes:
    chunks = bytearray()
    while len(chunks) < max_bytes:
        byte = conn.recv(1)
        if not byte:
            break
        chunks.extend(byte)
        if byte == b"\n":
            break

    return bytes(chunks)
