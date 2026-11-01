"""In-memory HTTP request runner for tests of BaseHTTPRequestHandler routes."""
from __future__ import annotations

from io import BytesIO
import json
from types import SimpleNamespace


class _MemoryStream(BytesIO):
    def close(self):
        # Preserve response bytes after BaseRequestHandler.finish().
        pass


class _MemorySocket:
    def __init__(self, request: bytes):
        self.reader = _MemoryStream(request)
        self.writer = _MemoryStream()

    def makefile(self, mode, buffering=None):
        return self.reader if "r" in mode else self.writer


def dispatch_json(handler_type, target: str, *, method: str = "GET",
                  body: str = "", headers: dict[str, str] | None = None) -> tuple[int, dict]:
    """Pass a raw HTTP/1.1 request through the production handler without TCP."""
    encoded_body = body.encode("utf-8")
    request_headers = {"Host": "localhost", "Connection": "close", **(headers or {})}
    if body and not any(key.lower() == "content-length" for key in request_headers):
        request_headers["Content-Length"] = str(len(encoded_body))
    head = f"{method} {target} HTTP/1.1\r\n" + "".join(
        f"{key}: {value}\r\n" for key, value in request_headers.items()) + "\r\n"
    connection = _MemorySocket(head.encode("ascii") + encoded_body)
    # The standard socket writer uses sendall(); a buffered writer instead
    # writes to the in-memory stream while preserving BaseHTTPRequestHandler.
    handler_type.wbufsize = -1
    handler_type(connection, ("127.0.0.1", 0),
                 SimpleNamespace(server_name="localhost", server_port=8788))
    raw = connection.writer.getvalue()
    response_head, response_body = raw.split(b"\r\n\r\n", 1)
    status = int(response_head.split(b"\r\n", 1)[0].split()[1])
    return status, json.loads(response_body)
