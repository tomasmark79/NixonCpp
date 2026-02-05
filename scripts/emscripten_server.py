#!/usr/bin/env python3
# Simple COOP/COEP static server for Emscripten
import http.server
import socketserver
import os
import sys

BASE_DIR = os.environ.get("BASE_DIR", os.getcwd())
PORT = int(os.environ.get("PORT", "6931"))

class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def log_message(self, format, *args):
        # Silence request logs
        pass

os.chdir(BASE_DIR)

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("", PORT), Handler) as httpd:
    httpd.serve_forever()
