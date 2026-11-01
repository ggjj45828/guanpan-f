"""Strict response-body limits for external HTTP sources."""
from __future__ import annotations


class ResponseTooLarge(ValueError):
    pass


def read_bounded_body(response, maximum_bytes: int, *, source: str) -> bytes:
    """Read at most maximum_bytes and reject a response that crosses the cap."""
    if type(maximum_bytes) is not int or maximum_bytes <= 0:
        raise ValueError("maximum_bytes must be a positive integer")
    headers = getattr(response, "headers", None)
    content_length = headers.get("Content-Length") if headers is not None else None
    if content_length is not None:
        try:
            if not content_length.isascii() or not content_length.isdecimal():
                raise ValueError
            declared_length = int(content_length)
        except (AttributeError, ValueError) as exc:
            raise ValueError(f"{source} returned an invalid Content-Length") from exc
        if declared_length > maximum_bytes:
            raise ResponseTooLarge(f"{source} response exceeds {maximum_bytes} bytes")
    body = response.read(maximum_bytes + 1)
    if not isinstance(body, bytes):
        raise ValueError(f"{source} response body is not bytes")
    if len(body) > maximum_bytes:
        raise ResponseTooLarge(f"{source} response exceeds {maximum_bytes} bytes")
    return body
