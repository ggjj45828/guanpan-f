"""Production HTTP runner for the F minute archive service.

A deployment-specific runtime factory supplies verified calendars and real data
providers. This module intentionally has no synthetic/default market source.
"""
from __future__ import annotations

import hmac
import importlib
import os
from http.server import ThreadingHTTPServer
from typing import Callable

from .http_api import make_handler
from .service import MinuteArchiveService


def _required(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"required environment variable is missing: {name}")
    return value


def _load_factory(spec: str) -> Callable[[], MinuteArchiveService]:
    module_name, separator, attribute = spec.partition(":")
    if not separator or not module_name or not attribute:
        raise RuntimeError("F_MINUTE_RUNTIME_FACTORY must use module:function syntax")
    module = importlib.import_module(module_name)
    factory = getattr(module, attribute, None)
    if not callable(factory):
        raise RuntimeError("configured F minute runtime factory is not callable")
    return factory


def build_server() -> ThreadingHTTPServer:
    token = _required("F_MINUTE_API_TOKEN").encode("utf-8")
    if len(token) < 32:
        raise RuntimeError("F_MINUTE_API_TOKEN must contain at least 32 UTF-8 bytes")
    factory_spec = (os.environ.get("F_MINUTE_RUNTIME_FACTORY", "") or
                    "nas.fminute.runtime:build_service").strip()
    service = _load_factory(factory_spec)()
    if not isinstance(service, MinuteArchiveService):
        raise RuntimeError("runtime factory must return MinuteArchiveService")

    def authorize(request) -> bool:
        supplied = request.headers.get("X-Api-Key", "").encode("utf-8")
        return hmac.compare_digest(supplied, token)

    host = os.environ.get("F_MINUTE_HOST", "0.0.0.0")
    try:
        port = int(os.environ.get("F_MINUTE_PORT", "8788"))
    except ValueError as exc:
        raise RuntimeError("F_MINUTE_PORT must be an integer") from exc
    if not 1 <= port <= 65535:
        raise RuntimeError("F_MINUTE_PORT must be in [1,65535]")
    server = ThreadingHTTPServer((host, port), make_handler(service, authorize))
    server.minute_service = service
    return server


def main() -> None:
    server = build_server()
    worker = getattr(server.minute_service, "runtime_worker", None)
    if worker is not None:
        worker.start()
    host, port = server.server_address[:2]
    print(f"F minute archive listening on {host}:{port}", flush=True)
    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        pass
    finally:
        if worker is not None:
            worker.stop()
        server.server_close()


if __name__ == "__main__":
    main()
