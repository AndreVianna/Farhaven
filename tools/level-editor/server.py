"""Dev server for Farhaven Level Editor.

Serves the editor and exposes API endpoints for file discovery and saving,
so the editor can load the project automatically without a directory picker.

Endpoints:
  GET  /                          → serves index.html
  GET  /api/discover              → lists maps, props, biomes
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
    'props': ('data/props', '.tres'),
    'biomes': ('data/biomes', '.tres'),
    'recipes': ('data/recipes', '.tres'),
    'events': ('data/events', '.tres'),
    'journal': ('data/journal', '.tres'),
    'cutscenes': ('data/cutscenes', '.tres'),
}

# Only allow access to files under these prefixes
ALLOWED_PREFIXES = ['data/maps/', 'data/props/', 'data/biomes/', 'data/catalog/', 'data/recipes/', 'data/events/', 'data/journal/', 'data/cutscenes/']

# Individual files permitted at paths outside ALLOWED_PREFIXES. Kept narrow —
# each entry is a full relative path, not a prefix.
ALLOWED_FILES = {'data/game_settings.tres'}

# Read-only binary asset prefixes served via /api/asset (e.g. terrain
# textures the editor previews). Kept separate from the writable
# ALLOWED_PREFIXES so a stray POST can never overwrite a PNG.
ALLOWED_ASSET_PREFIXES = ['assets/textures/', 'assets/props/']

# Extensions we'll serve through /api/asset, mapped to MIME types.
ASSET_MIME = {
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.webp': 'image/webp',
}


def is_safe_path(rel_path):
    """Ensure the path doesn't escape allowed directories."""
    normalized = os.path.normpath(rel_path).replace('\\', '/')
    if any(part == '..' for part in normalized.split('/')):
        return False
    if normalized in ALLOWED_FILES:
        return True
    return any(normalized.startswith(prefix) for prefix in ALLOWED_PREFIXES)


def is_safe_delete_path(rel_path):
    """DELETE is restricted to map JSON files only to reduce accidental damage."""
    normalized = os.path.normpath(rel_path).replace('\\', '/')
    if any(part == '..' for part in normalized.split('/')):
        return False
    maps_dir, maps_ext = SCAN_DIRS['maps']
    maps_prefix = maps_dir.rstrip('/') + '/'
    return normalized.startswith(maps_prefix) and normalized.endswith(maps_ext)


def is_safe_asset_path(rel_path):
    """Read-only check for /api/asset and /api/list-assets serving."""
    normalized = os.path.normpath(rel_path).replace('\\', '/')
    if os.path.isabs(normalized) or ':' in normalized:
        return False
    if any(part == '..' for part in normalized.split('/')):
        return False
    # Accept the exact directory name (equality) or any path strictly
    # under it. Keeping the trailing slash on the prefix avoids the
    # prefix-confusion bug where `assets/texturesbackup/` would match
    # `assets/textures` after rstrip('/').
    for prefix in ALLOWED_ASSET_PREFIXES:
        pdir = prefix.rstrip('/')
        if normalized == pdir or normalized.startswith(pdir + '/'):
            return True
    return False


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

        elif path == '/api/list-assets':
            rel_dir = params.get('dir', [''])[0]
            if not rel_dir or not is_safe_asset_path(rel_dir):
                self._json_response(400, {'error': 'Invalid asset directory'})
                return
            ext = params.get('ext', ['.png'])[0].lower()
            if ext not in ASSET_MIME:
                self._json_response(400, {'error': f'Unsupported extension: {ext}'})
                return
            full_dir = os.path.join(PROJECT_ROOT, rel_dir)
            files = []
            if os.path.isdir(full_dir):
                for name in sorted(os.listdir(full_dir)):
                    if name.endswith(ext):
                        files.append(name)
            self._json_response(200, {'dir': rel_dir, 'files': files})

        elif path == '/api/asset':
            rel_path = params.get('path', [''])[0]
            if not rel_path or not is_safe_asset_path(rel_path):
                self._json_response(400, {'error': 'Invalid asset path'})
                return
            ext = os.path.splitext(rel_path)[1].lower()
            mime = ASSET_MIME.get(ext)
            if mime is None:
                self._json_response(415, {'error': f'Unsupported asset type: {ext}'})
                return
            full_path = os.path.join(PROJECT_ROOT, rel_path)
            if not os.path.isfile(full_path):
                self._json_response(404, {'error': f'Asset not found: {rel_path}'})
                return
            with open(full_path, 'rb') as f:
                body = f.read()
            self.send_response(200)
            self.send_header('Content-Type', mime)
            self.send_header('Content-Length', len(body))
            self.send_header('Cache-Control', 'public, max-age=300')
            self.end_headers()
            self.wfile.write(body)

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
            parent_dir = os.path.dirname(full_path)
            if not os.path.isdir(parent_dir):
                self._json_response(404, {'error': f'Directory not found: {os.path.dirname(rel_path)}'})
                return
            length = int(self.headers.get('Content-Length', 0))
            # Cap request body to prevent DoS via oversized upload (or
            # a mis-declared Content-Length exhausting memory). 64 MB
            # covers realistic maps — the 150-radius procedural ch1
            # already hits 10 MB before populate, and a densely
            # populated map can more than triple that. Previous 8 MB
            # cap silently dropped connections and forced the browser
            # into the Blob-download fallback.
            MAX_UPLOAD_BYTES = 64 * 1024 * 1024
            if length < 0 or length > MAX_UPLOAD_BYTES:
                self._json_response(413, {'error': f'Request body too large (limit {MAX_UPLOAD_BYTES} bytes)'})
                # Drain the body so the connection can stay alive and
                # the client can actually read the 413 JSON instead of
                # seeing a generic "Failed to fetch" when the server
                # closes mid-stream.
                try:
                    remaining = length
                    while remaining > 0:
                        chunk = self.rfile.read(min(remaining, 65536))
                        if not chunk:
                            break
                        remaining -= len(chunk)
                except Exception:
                    pass
                return
            body = self.rfile.read(length).decode('utf-8')
            with open(full_path, 'w', encoding='utf-8', newline='\n') as f:
                f.write(body)
            self._json_response(200, {'ok': True})
        else:
            self._json_response(404, {'error': 'Not found'})

    def do_DELETE(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        params = urllib.parse.parse_qs(parsed.query)

        if path == '/api/file':
            rel_path = params.get('path', [''])[0]
            if not rel_path or not is_safe_delete_path(rel_path):
                self._json_response(400, {'error': 'Invalid path'})
                return
            full_path = os.path.join(PROJECT_ROOT, rel_path)
            if not os.path.isfile(full_path):
                self._json_response(404, {'error': f'File not found: {rel_path}'})
                return
            try:
                os.remove(full_path)
            except OSError as e:
                self._json_response(500, {'error': f'Failed to delete file: {e}'})
                return
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
    server = http.server.HTTPServer(('127.0.0.1', port), EditorHandler)
    print(f"Farhaven Level Editor running at http://localhost:{port}")
    print(f"Project root: {PROJECT_ROOT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()
