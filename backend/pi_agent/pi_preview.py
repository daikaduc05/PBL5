from __future__ import annotations

import json
import threading
import time
from dataclasses import dataclass
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Callable
from urllib.parse import urlparse


LogFn = Callable[[str], None]


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


class LivePreviewServer:
    def __init__(
        self,
        server: ThreadingHTTPServer,
        thread: threading.Thread,
        host: str,
        port: int,
        logger: LogFn | None = None,
    ) -> None:
        self._server = server
        self._thread = thread
        self.host = host
        self.port = port
        self._logger = logger

    def close(self) -> None:
        self._server.shutdown()
        self._server.server_close()
        self._thread.join(timeout=2)
        if self._logger is not None:
            self._logger("Live preview server stopped.")


def update_preview_frame(frame_bytes: bytes, content_type: str = "image/jpeg") -> None:
    _PREVIEW_STORE.update(frame_bytes=frame_bytes, content_type=content_type)


def start_preview_server(
    host: str = "0.0.0.0",
    port: int = 8081,
    logger: LogFn | None = None,
) -> LivePreviewServer:
    handler = _build_preview_handler(store=_PREVIEW_STORE)
    server = ThreadingHTTPServer((host, port), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()

    if logger is not None:
        logger(f"Live preview server started on http://{host}:{port}")

    return LivePreviewServer(
        server=server,
        thread=thread,
        host=host,
        port=port,
        logger=logger,
    )


def _build_preview_handler(store: PreviewFrameStore):
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
