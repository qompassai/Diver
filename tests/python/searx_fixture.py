"""Loopback fixture: two requests, no upstream search engine or internet traffic."""
import http.server
import json
import pathlib
import sys
import urllib.parse

class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        size = int(self.headers.get('Content-Length', '0'))
        if size > 16384:
            self.send_error(413)
            return
        data = urllib.parse.parse_qs(self.rfile.read(size).decode())
        if self.path.startswith('/forbidden/'):
            self.send_error(403)
            return
        body = json.dumps({'results': [{
            'title': data['q'][0],
            'url': 'https://example.com/local-fixture',
        }]}).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass

server = http.server.HTTPServer(('127.0.0.1', 0), Handler)
server.timeout = 10
pathlib.Path(sys.argv[1]).write_text(str(server.server_port))
try:
    for _ in range(2):
        server.handle_request()
finally:
    server.server_close()
