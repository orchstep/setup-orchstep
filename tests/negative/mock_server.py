#!/usr/bin/env python3
"""Serve a deliberately broken OrchStep release for negative testing.

Usage: mock_server.py <mode> <port>
  mode = wrong-checksum | missing-entry | truncated
Serves:
  /orchstep_9.9.9_linux_amd64.tar.gz
  /checksums.txt
"""
import hashlib
import http.server
import io
import sys
import tarfile

MODE = sys.argv[1]
PORT = int(sys.argv[2])


def build_tarball() -> bytes:
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        data = b"#!/bin/sh\necho orchstep 9.9.9\n"
        info = tarfile.TarInfo(name="orchstep")
        info.size = len(data)
        info.mode = 0o755
        tar.addfile(info, io.BytesIO(data))
    return buf.getvalue()


TARBALL = build_tarball()
ASSET = "orchstep_9.9.9_linux_amd64.tar.gz"


def checksums_body() -> bytes:
    real = hashlib.sha256(TARBALL).hexdigest()
    if MODE == "wrong-checksum":
        return f"{'0' * 64}  {ASSET}\n".encode()
    if MODE == "missing-entry":
        return f"{real}  some-other-file.tar.gz\n".encode()
    return f"{real}  {ASSET}\n".encode()


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):  # noqa: N802
        if self.path.endswith(ASSET):
            body = TARBALL[: len(TARBALL) // 2] if MODE == "truncated" else TARBALL
            self.send_response(200)
            self.send_header("Content-Type", "application/gzip")
            self.end_headers()
            self.wfile.write(body)
        elif self.path.endswith("checksums.txt"):
            body = checksums_body()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_error(404)

    def log_message(self, *args):  # silence
        pass


if __name__ == "__main__":
    http.server.HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
