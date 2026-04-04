"""Dev server for Farhaven Level Editor.

Serves the editor and exposes API endpoints for file discovery and saving,
so the editor can load the project automatically without a directory picker.

Endpoints:
  GET  /                          → serves index.html
  GET  /api/discover              → lists maps, resources, biomes
  GET  /api/file?path=<rel_path>  → reads a project file
  POST /api/file?path=<rel_path>  → writes a project file
  GET  /*                         → static files from level-editor/
"""

import http.server
import json
import os
import sys
import urllib.parse

# Project root is two levels up from this script (tools/level-editor/ → project root)
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.normpath(os.path.join(SCRIPT_DIR, '..', '..'))
EDITOR_DIR = SCRIPT_DIR

# Directories to scan (relative to project root)
SCAN_DIRS = {
    'maps': ('data/maps', '.json'),
    'resources': ('data/resources', '.tres'),
    'biomes': ('data/biomes', '.tres'),
}

# Only allow access to files under these prefixes
ALLOWED_PREFIXES = ['data/maps/', 'data/resources/', 'data/biomes/', 'data/catalog/']


def is_safe_path(rel_path):
    """Ensure the path doesn't escape allowed directories."""
    normalized = os.path.normpath(rel_path).replace('\\', '/')
    if '..' in normalized:
        return False
    return any(normalized.startswith(prefix) for prefix in ALLOWED_PREFIXES)


def discover_files():
    """Scan project directories and return file listings."""
    result = {}
    for key, (subdir, ext) in SCAN_DIRS.items():
        full_dir = os.path.join(PROJECT_ROOT, subdir)
        files = []
        if os.path.isdir(full_dir):
            for name in sorted(os.listdir(full_dir)):
                if name.endswith(ext):
                    files.append(name)
        result[key] = {'dir': subdir, 'files': files}
    return result


class EditorHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=EDITOR_DIR, **kwargs)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        params = urllib.parse.parse_qs(parsed.query)

        if path == '/api/discover':
            data = discover_files()
            self._json_response(200, data)

        elif path == '/api/file':
            rel_path = params.get('path', [''])[0]
            if not rel_path or not is_safe_path(rel_path):
                self._json_response(400, {'error': 'Invalid path'})
                return
            full_path = os.path.join(PROJECT_ROOT, rel_path)
            if not os.path.isfile(full_path):
                self._json_response(404, {'error': f'File not found: {rel_path}'})
                return
            with open(full_path, 'r', encoding='utf-8') as f:
                content = f.read()
            self._text_response(200, content)

        else:
            super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        params = urllib.parse.parse_qs(parsed.query)

        if path == '/api/file':
            rel_path = params.get('path', [''])[0]
            if not rel_path or not is_safe_path(rel_path):
                self._json_response(400, {'error': 'Invalid path'})
                return
            full_path = os.path.join(PROJECT_ROOT, rel_path)
            if not os.path.isfile(full_path):
                self._json_response(404, {'error': f'File not found: {rel_path}'})
                return
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length).decode('utf-8')
            with open(full_path, 'w', encoding='utf-8', newline='\n') as f:
                f.write(body)
            self._json_response(200, {'ok': True})
        else:
            self._json_response(404, {'error': 'Not found'})

    def _json_response(self, status, data):
        body = json.dumps(data).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', len(body))
        self.end_headers()
        self.wfile.write(body)

    def _text_response(self, status, text):
        body = text.encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'text/plain; charset=utf-8')
        self.send_header('Content-Length', len(body))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        # Quieter logging — skip static asset requests
        msg = format % args
        if '/api/' in msg:
            sys.stderr.write(f"[editor] {msg}\n")


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    server = http.server.HTTPServer(('', port), EditorHandler)
    print(f"Farhaven Level Editor running at http://localhost:{port}")
    print(f"Project root: {PROJECT_ROOT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()
