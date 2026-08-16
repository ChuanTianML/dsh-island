#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HTML_PATH="$PROJECT_ROOT/docs/marketing/preview.html"
OUTPUT_DIR="$PROJECT_ROOT/docs/assets"
FRAME_DIR="$PROJECT_ROOT/.marketing/gif-frames"
CHROME_BIN="${CHROME_BIN:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
FFMPEG_BIN="${FFMPEG_BIN:-$(command -v ffmpeg || true)}"

if [[ ! -x "$CHROME_BIN" ]]; then
  echo "Google Chrome was not found at $CHROME_BIN" >&2
  exit 1
fi
if [[ -z "$FFMPEG_BIN" || ! -x "$FFMPEG_BIN" ]]; then
  echo "ffmpeg was not found; install it or set FFMPEG_BIN" >&2
  exit 1
fi

"$PROJECT_ROOT/scripts/capture-product-assets.sh"

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
render 1600 1000 "mode=themes" "$OUTPUT_DIR/dsh-island-themes.png"
render 1600 1000 "mode=desktop" "$OUTPUT_DIR/dsh-island-desktop.png"
render 1200 720 "mode=demo&state=working" "$FRAME_DIR/00-working.png"
render 1200 720 "mode=demo&state=attention" "$FRAME_DIR/01-attention.png"
render 1200 720 "mode=demo&state=expanding" "$FRAME_DIR/02-expanding.png"
render 1200 720 "mode=demo&state=expanded" "$FRAME_DIR/03-expanded.png"

GIF_CONCAT="$(mktemp)"
trap 'rm -f "$GIF_CONCAT"' EXIT
{
  printf "file '%s'\n" "$FRAME_DIR/00-working.png"
  printf "duration 2.2\n"
  printf "file '%s'\n" "$FRAME_DIR/01-attention.png"
  printf "duration 1.6\n"
  printf "file '%s'\n" "$FRAME_DIR/02-expanding.png"
  printf "duration 0.5\n"
  printf "file '%s'\n" "$FRAME_DIR/03-expanded.png"
  printf "duration 3.2\n"
  printf "file '%s'\n" "$FRAME_DIR/03-expanded.png"
} >"$GIF_CONCAT"
"$FFMPEG_BIN" -y -v error \
  -f concat -safe 0 -i "$GIF_CONCAT" \
  -filter_complex \
  "[0:v]fps=10,split[frames][palette_source];[palette_source]palettegen=max_colors=128:stats_mode=diff[palette];[frames][palette]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle" \
  -t 7.5 -loop 0 "$OUTPUT_DIR/dsh-island-demo.gif"

echo "$OUTPUT_DIR/dsh-island-social-preview.png"
echo "$OUTPUT_DIR/dsh-island-themes.png"
echo "$OUTPUT_DIR/dsh-island-desktop.png"
echo "$OUTPUT_DIR/dsh-island-demo.gif"
echo "$FRAME_DIR"
