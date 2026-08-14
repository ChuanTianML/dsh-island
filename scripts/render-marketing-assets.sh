#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HTML_PATH="$PROJECT_ROOT/docs/marketing/preview.html"
OUTPUT_DIR="$PROJECT_ROOT/docs/assets"
FRAME_DIR="$PROJECT_ROOT/.marketing/gif-frames"
CHROME_BIN="${CHROME_BIN:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"

if [[ ! -x "$CHROME_BIN" ]]; then
  echo "Google Chrome was not found at $CHROME_BIN" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR" "$FRAME_DIR"
rm -f "$FRAME_DIR"/*.png

render() {
  local width="$1"
  local height="$2"
  local query="$3"
  local output="$4"
  local profile
  local chrome_pid
  profile="$(mktemp -d)"
  rm -f "$output"
  "$CHROME_BIN" \
    --headless=new \
    --disable-gpu \
    --hide-scrollbars \
    --no-first-run \
    --allow-file-access-from-files \
    --user-data-dir="$profile" \
    --window-size="$width,$height" \
    --screenshot="$output" \
    "file://$HTML_PATH?$query" >/dev/null 2>&1 &
  chrome_pid="$!"
  for _ in {1..200}; do
    [[ -s "$output" ]] && break
    kill -0 "$chrome_pid" 2>/dev/null || break
    sleep 0.1
  done
  if kill -0 "$chrome_pid" 2>/dev/null; then
    kill "$chrome_pid"
  fi
  wait "$chrome_pid" 2>/dev/null || true
  rm -r "$profile"
  if [[ ! -s "$output" ]]; then
    echo "Failed to render $output" >&2
    exit 1
  fi
}

render 1200 630 "mode=social" "$OUTPUT_DIR/dsh-island-social-preview.png"
render 1600 1000 "mode=desktop" "$OUTPUT_DIR/dsh-island-desktop.png"
render 1200 720 "mode=demo&state=working" "$FRAME_DIR/00-working.png"
render 1200 720 "mode=demo&state=attention" "$FRAME_DIR/01-attention.png"
render 1200 720 "mode=demo&state=expanding" "$FRAME_DIR/02-expanding.png"
render 1200 720 "mode=demo&state=expanded" "$FRAME_DIR/03-expanded.png"

echo "$OUTPUT_DIR/dsh-island-social-preview.png"
echo "$OUTPUT_DIR/dsh-island-desktop.png"
echo "$FRAME_DIR"
