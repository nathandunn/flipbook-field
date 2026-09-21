#!/bin/bash
# Re-export the web build. Needs Godot 4.4.1 and its web export templates.
#   ./build.sh [/path/to/godot4]
set -euo pipefail
GODOT="${1:-godot4}"
cd "$(dirname "$0")"
rm -rf web && mkdir -p web
# Costumes and the backs of heads are drawn, not stored: one pen, at build time.
python3 art/bodygen.py project/faces project/bodies
# New scripts with a class_name are only registered by an import pass;
# without this a fresh clone cannot resolve them and the export fails.
"$GODOT" --headless --path project --import
"$GODOT" --headless --path project --export-release "Web" "$PWD/web/index.html"
cd web
# nginx serves these directly via gzip_static; regenerate them with every build
# or it will hand out a stale compressed copy of a fresh wasm.
gzip -9 -k -f index.wasm index.js
ls -la
