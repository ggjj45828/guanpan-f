from __future__ import annotations

import unittest
from pathlib import Path

from nas.fminute.http_limits import ResponseTooLarge, read_bounded_body


ROOT = Path(__file__).resolve().parents[1]


class Headers(dict):
    def get(self, key, default=None):
        return super().get(key, default)


class Response:
    def __init__(self, body: bytes, headers=None):
        self.body = body
        self.headers = Headers(headers or {})
        self.requested_sizes = []

    def read(self, size: int) -> bytes:
        self.requested_sizes.append(size)
        return self.body[:size]


class HTTPResponseLimitTests(unittest.TestCase):
    def test_accepts_body_at_exact_limit_and_reads_one_byte_past_cap(self):
        response = Response(b"1234")

        self.assertEqual(read_bounded_body(response, 4, source="fixture"), b"1234")
        self.assertEqual(response.requested_sizes, [5])

    def test_rejects_oversized_stream_even_without_content_length(self):
        response = Response(b"12345")

        with self.assertRaisesRegex(ResponseTooLarge, "fixture response exceeds 4 bytes"):
            read_bounded_body(response, 4, source="fixture")

    def test_rejects_declared_oversize_before_reading(self):
        response = Response(b"", {"Content-Length": "5"})

        with self.assertRaises(ResponseTooLarge):
            read_bounded_body(response, 4, source="fixture")
        self.assertEqual(response.requested_sizes, [])

    def test_rejects_oversized_body_even_when_content_length_lies(self):
        response = Response(b"12345", {"Content-Length": "4"})

        with self.assertRaises(ResponseTooLarge):
            read_bounded_body(response, 4, source="fixture")

    def test_rejects_malformed_content_length(self):
        with self.assertRaisesRegex(ValueError, "invalid Content-Length"):
            read_bounded_body(Response(b"1", {"Content-Length": "4x"}), 4, source="fixture")

    def test_all_external_nas_http_body_reads_use_the_strict_limit(self):
        for relative in ("nas/fminute/providers.py", "nas/fminute/index_history.py",
                         "nas/fminute/calendar_sync.py"):
            with self.subTest(source=relative):
                source = (ROOT / relative).read_text(encoding="utf-8")
                self.assertIn("read_bounded_body(", source)
                self.assertNotRegex(source, r"response\.read\(\s*(?:2_000_000|4_000_000)\s*\)")


if __name__ == "__main__":
    unittest.main()
