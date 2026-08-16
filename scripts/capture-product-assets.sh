#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/docs/assets"
WORK_DIR="$(mktemp -d)"
WINDOW_ID_HELPER="$WORK_DIR/window-id"
APP_PID=""

cleanup() {
  if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID"
    wait "$APP_PID" 2>/dev/null || true
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR"
swift build --package-path "$PROJECT_ROOT" >/dev/null
BIN_PATH="$(swift build --package-path "$PROJECT_ROOT" --show-bin-path)/dsh-island"
swiftc "$PROJECT_ROOT/scripts/window-id.swift" -o "$WINDOW_ID_HELPER"

capture() {
  local name="$1"
  local width="$2"
  local height="$3"
  shift 3
  local ready_file="$WORK_DIR/$name.ready"
  local raw_file="$WORK_DIR/$name-native.png"
  local output_file="$OUTPUT_DIR/dsh-island-$name.png"
  local window_id=""

  "$BIN_PATH" "$@" --ready-file "$ready_file" >/dev/null 2>&1 &
  APP_PID="$!"
  for _ in {1..100}; do
    [[ -f "$ready_file" ]] && break
    kill -0 "$APP_PID" 2>/dev/null || break
    sleep 0.1
  done
  if [[ ! -f "$ready_file" ]]; then
    echo "DSH Island did not become ready for $name capture" >&2
    exit 1
  fi

  for _ in {1..50}; do
    window_id="$($WINDOW_ID_HELPER "$APP_PID" 2>/dev/null || true)"
    [[ -n "$window_id" ]] && break
    sleep 0.1
  done
  if [[ -z "$window_id" ]]; then
    echo "Could not find the DSH Island window for $name capture" >&2
    exit 1
  fi

  /usr/sbin/screencapture -x -o -l"$window_id" "$raw_file"
  kill "$APP_PID"
  wait "$APP_PID" 2>/dev/null || true
  APP_PID=""

  sips -z "$height" "$width" "$raw_file" --out "$output_file" >/dev/null
  echo "$output_file"
}

capture working 400 68 --demo-working --theme original
capture collapsed 400 68 --demo --theme original
capture expanded 500 454 --demo-expanded --theme original

capture theme-original 500 454 --demo-expanded --theme original
capture theme-quiet 440 384 --demo-expanded --theme quiet
capture theme-orbital 500 398 --demo-expanded --theme orbital
capture theme-editorial 500 436 --demo-expanded --theme editorial
capture theme-pulse 500 434 --demo-expanded --theme pulse

swift "$PROJECT_ROOT/scripts/verify-transparent-corners.swift" \
  "$OUTPUT_DIR/dsh-island-working.png" 34 \
  "$OUTPUT_DIR/dsh-island-collapsed.png" 34 \
  "$OUTPUT_DIR/dsh-island-expanded.png" 28 \
  "$OUTPUT_DIR/dsh-island-theme-original.png" 28 \
  "$OUTPUT_DIR/dsh-island-theme-quiet.png" 26 \
  "$OUTPUT_DIR/dsh-island-theme-orbital.png" 22 \
  "$OUTPUT_DIR/dsh-island-theme-editorial.png" 20 \
  "$OUTPUT_DIR/dsh-island-theme-pulse.png" 34
