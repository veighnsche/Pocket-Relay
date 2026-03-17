#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This command only works on macOS hosts." >&2
  exit 1
fi

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
artifacts_dir="${POCKET_RELAY_SCREENSHOT_DIR:-$project_root/.codex-artifacts/screenshots}"

mkdir -p "$artifacts_dir"

timestamp() {
  date +"%Y%m%d-%H%M%S"
}

default_output() {
  local prefix="$1"
  printf '%s/%s-%s.png\n' "$artifacts_dir" "$prefix" "$(timestamp)"
}

require_command() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Required command not found: $name" >&2
    exit 127
  fi
}

booted_ios_simulator_udid() {
  require_command xcrun
  require_command python3
  xcrun simctl list devices --json | python3 -c '
import json
import sys

payload = json.load(sys.stdin)
for runtime_name, devices in payload.get("devices", {}).items():
    if "iOS" not in runtime_name:
        continue
    for device in devices:
        if not device.get("isAvailable", True):
            continue
        if device.get("state") == "Booted":
            print(device["udid"])
            raise SystemExit(0)
raise SystemExit(1)
'
}

find_pocket_relay_pid() {
  pgrep -f '/pocket_relay\.app/Contents/MacOS/pocket_relay$' | tail -n 1
}

find_window_id_for_pid() {
  local pid="$1"
  require_command swift
  swift -e '
import CoreGraphics
import Foundation

let targetPid = Int(CommandLine.arguments[1])!
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []

let bestWindowId = windows.compactMap { item -> (Int, Int)? in
    guard let ownerPid = item[kCGWindowOwnerPID as String] as? Int, ownerPid == targetPid else {
        return nil
    }
    guard let layer = item[kCGWindowLayer as String] as? Int, layer == 0 else {
        return nil
    }
    guard let bounds = item[kCGWindowBounds as String] as? [String: Any],
          let width = bounds["Width"] as? Int,
          let height = bounds["Height"] as? Int,
          width > 200,
          height > 200,
          let windowId = item[kCGWindowNumber as String] as? Int else {
        return nil
    }
    return (windowId, width * height)
}.max(by: { $0.1 < $1.1 })?.0

guard let bestWindowId else {
    throw NSError(domain: "host-screenshot", code: 1)
}

print(bestWindowId)
' "$pid"
}

macos_screen_capture_allowed() {
  require_command swift
  swift -e '
import CoreGraphics
print(CGPreflightScreenCaptureAccess() ? "true" : "false")
'
}

capture_ios() {
  local output="${1:-$(default_output ios)}"
  local device
  if ! device="$(booted_ios_simulator_udid)"; then
    echo "No booted iOS simulator found." >&2
    exit 1
  fi

  mkdir -p "$(dirname "$output")"
  xcrun simctl io "$device" screenshot "$output" >/dev/null
  printf '%s\n' "$output"
}

capture_macos() {
  local output="${1:-$(default_output macos)}"
  local allowed
  allowed="$(macos_screen_capture_allowed)"
  if [ "$allowed" != "true" ]; then
    echo "Screen capture permission is not granted for this terminal. Allow Screen Recording for your terminal app in macOS settings and try again." >&2
    exit 1
  fi

  local pid
  if ! pid="$(find_pocket_relay_pid)"; then
    echo "No running Pocket Relay macOS app process found." >&2
    exit 1
  fi

  local window_id
  if ! window_id="$(find_window_id_for_pid "$pid")"; then
    echo "Could not find an on-screen Pocket Relay macOS window." >&2
    exit 1
  fi

  mkdir -p "$(dirname "$output")"
  screencapture -x -l "$window_id" "$output"
  printf '%s\n' "$output"
}

capture_both() {
  local output_dir="${1:-$artifacts_dir}"
  mkdir -p "$output_dir"

  local stamp
  stamp="$(timestamp)"

  local ios_output="$output_dir/ios-$stamp.png"
  local macos_output="$output_dir/macos-$stamp.png"

  capture_ios "$ios_output" >/dev/null
  capture_macos "$macos_output" >/dev/null

  printf 'ios=%s\n' "$ios_output"
  printf 'macos=%s\n' "$macos_output"
}

main() {
  local command="${1:-}"
  shift || true

  case "$command" in
    ios)
      capture_ios "${1:-}"
      ;;
    macos|desktop)
      capture_macos "${1:-}"
      ;;
    both)
      capture_both "${1:-}"
      ;;
    *)
      echo "Usage: $(basename "$0") {ios|macos|desktop|both} [output-path-or-dir]" >&2
      exit 2
      ;;
  esac
}

main "$@"
