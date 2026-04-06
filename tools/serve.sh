#!/usr/bin/env bash
# Serves the level-editor on http://localhost:8080
cd "$(dirname "$0")/level-editor"
python server.py 8080
