#!/bin/bash
set -e
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="${1:-$root/ui-preview}"
size="${2:-1280x720}"
only="${3:-}"
width="${size%x*}"
height="${size#*x}"
cd "$root"
if [ ! -f sourcemap.json ]; then rojo sourcemap default.project.json --output sourcemap.json > /dev/null; fi
rm -rf "$out/json"
mkdir -p "$out/json"
lune run tools/ui_preview/capture "$out/json" "$width" "$height" $only
export PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers
node tools/ui_preview/render.mjs "$out/json" "$out" $only
