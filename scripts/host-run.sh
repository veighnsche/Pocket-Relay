#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

command="${1:-}"
android_avd="${2:-Pixel_6}"
ios_simulator="${3:-iPhone 15}"

require_command() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Required command not found: $name" >&2
    exit 127
  fi
}

os_release_id() {
  if [ ! -r /etc/os-release ]; then
    return 1
  fi

  awk -F= '$1 == "ID" { gsub(/"/, "", $2); print $2; exit }' /etc/os-release
}

linux_libsecret_install_hint() {
  local distro
  distro="$(os_release_id 2>/dev/null || true)"

  case "$distro" in
    fedora|rhel|centos|rocky|almalinux)
      printf '%s\n' 'Install it with: sudo dnf install libsecret-devel'
      ;;
    ubuntu|debian|pop|linuxmint|elementary)
      printf '%s\n' 'Install it with: sudo apt install libsecret-1-dev'
      ;;
    arch|manjaro|endeavouros)
      printf '%s\n' 'Install it with: sudo pacman -S libsecret'
      ;;
    opensuse*|sles)
      printf '%s\n' 'Install it with: sudo zypper install libsecret-devel'
      ;;
    *)
      printf '%s\n' 'Install the libsecret development package for your distro so pkg-config can resolve libsecret-1 >= 0.18.4.'
      ;;
  esac
}

ensure_linux_desktop_prereqs() {
  require_command flutter
  require_command pkg-config

  if pkg-config --exists 'libsecret-1 >= 0.18.4'; then
    return 0
  fi

  echo 'Linux desktop builds require libsecret-1 >= 0.18.4 because flutter_secure_storage_linux is enabled in this app.' >&2
  linux_libsecret_install_hint >&2
  exit 1
}

current_host() {
  uname -s
}

booted_android_emulator_for_avd() {
  require_command adb

  local target_avd="${1:-}"
  local device
  local state
  local avd_name

  while read -r device state _; do
    if [[ ! "$device" =~ ^emulator- ]] || [ "$state" != "device" ]; then
      continue
    fi

    avd_name="$(adb -s "$device" emu avd name 2>/dev/null | tr -d '\r' | tail -n 1)"
    if [ "$avd_name" = "$target_avd" ]; then
      printf '%s\n' "$device"
      return 0
    fi
  done < <(adb devices)

  return 1
}

wait_for_booted_android_emulator() {
  local target_avd="${1:-}"
  local timeout_seconds="${2:-120}"
  local elapsed=0
  local device

  until device="$(booted_android_emulator_for_avd "$target_avd")"; do
    if [ "$elapsed" -ge "$timeout_seconds" ]; then
      return 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  printf '%s\n' "$device"
}

require_running_android_emulator() {
  local device
  device="$(booted_android_emulator_for_avd "$android_avd")"
  if [ -z "$device" ]; then
    echo "No running Android emulator found for '$android_avd'. Start one with 'just android-emulator' or run the app with 'just android-dev'." >&2
    exit 1
  fi

  printf '%s\n' "$device"
}

ensure_booted_android_emulator() {
  require_command flutter

  if [ -z "$android_avd" ]; then
    echo "Android AVD name is required." >&2
    exit 2
  fi

  local device
  if device="$(booted_android_emulator_for_avd "$android_avd")"; then
    printf '%s\n' "$device"
    return 0
  fi

  local launch_output=""
  if ! launch_output="$(flutter emulators --launch "$android_avd" 2>&1)"; then
    echo "Flutter couldn't launch Android emulator '$android_avd'." >&2
    if [ -n "$launch_output" ]; then
      printf '%s\n' "$launch_output" >&2
    fi
    exit 1
  fi

  if ! device="$(wait_for_booted_android_emulator "$android_avd" 120)"; then
    echo "Timed out waiting for Android emulator '$android_avd' to boot." >&2
    echo "Available emulators:" >&2
    flutter emulators >&2 || true
    exit 1
  fi

  until [ "$(adb -s "$device" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
    sleep 2
  done

  printf '%s\n' "$device"
}

booted_ios_simulator_udid_for_selector() {
  require_command xcrun
  require_command python3

  (
    export IOS_SIMULATOR_SELECTOR="${1:-$ios_simulator}"
    xcrun simctl list devices --json | python3 -c '
import json
import os
import sys

selector = os.environ.get("IOS_SIMULATOR_SELECTOR", "").strip().lower()
legacy_selector = selector in {"", "apple_ios_simulator"}
payload = json.load(sys.stdin)

for runtime_name, devices in payload.get("devices", {}).items():
    if "iOS" not in runtime_name:
        continue
    for device in devices:
        if not device.get("isAvailable", True):
            continue
        if device.get("state") != "Booted":
            continue
        if legacy_selector:
            print(device["udid"])
            raise SystemExit(0)
        if selector == device["name"].lower() or selector == device["udid"].lower():
            print(device["udid"])
            raise SystemExit(0)

raise SystemExit(1)
'
  )
}

resolve_ios_simulator_device() {
  require_command xcrun
  require_command python3

  (
    export IOS_SIMULATOR_SELECTOR="${1:-$ios_simulator}"
    xcrun simctl list devices --json | python3 -c '
import json
import os
import sys

payload = json.load(sys.stdin)
selector = os.environ.get("IOS_SIMULATOR_SELECTOR", "").strip().lower()
legacy_selector = selector in {"", "apple_ios_simulator"}
first_iphone = None
first_any = None

for runtime_name, devices in payload.get("devices", {}).items():
    if "iOS" not in runtime_name:
        continue
    for device in devices:
        if not device.get("isAvailable", True):
            continue
        row = (device["udid"], device["name"], runtime_name)
        if first_any is None:
            first_any = row
        if first_iphone is None and "iphone" in device["name"].lower():
            first_iphone = row
        if legacy_selector:
            continue
        if selector == device["udid"].lower() or selector == device["name"].lower():
            print("\t".join(row))
            raise SystemExit(0)

if not legacy_selector:
    raise SystemExit(1)

selected = first_iphone or first_any
if selected is None:
    raise SystemExit(1)

print("\t".join(selected))
'
  )
}

wait_for_booted_ios_simulator() {
  local selector="${1:-$ios_simulator}"
  local timeout_seconds="${2:-60}"
  local elapsed=0
  local device

  until device="$(booted_ios_simulator_udid_for_selector "$selector")"; do
    if [ "$elapsed" -ge "$timeout_seconds" ]; then
      return 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  printf '%s\n' "$device"
}

ensure_booted_ios_simulator() {
  require_command open
  require_command xcrun

  local target_device
  if ! target_device="$(resolve_ios_simulator_device "$ios_simulator")"; then
    echo "No available iOS simulator matched '$ios_simulator'." >&2
    xcrun simctl list devices >&2 || true
    exit 1
  fi

  local target_udid target_name target_runtime
  IFS=$'\t' read -r target_udid target_name target_runtime <<< "$target_device"

  local device
  if device="$(booted_ios_simulator_udid_for_selector "$ios_simulator")"; then
    printf '%s\n' "$device"
    return 0
  fi

  echo "Booting iOS simulator: $target_name ($target_runtime)." >&2

  local boot_output=""
  if ! boot_output="$(xcrun simctl boot "$target_udid" 2>&1)"; then
    if ! booted_ios_simulator_udid_for_selector "$ios_simulator" >/dev/null 2>&1; then
      echo "simctl failed to boot '$target_name'." >&2
      if [ -n "$boot_output" ]; then
        printf '%s\n' "$boot_output" >&2
      fi
      exit 1
    fi
  fi

  open -a Simulator --args -CurrentDeviceUDID "$target_udid" >/dev/null 2>&1 || open -a Simulator >/dev/null 2>&1

  if ! device="$(wait_for_booted_ios_simulator "$ios_simulator" 60)"; then
    echo "Timed out waiting for iOS simulator '$target_name' to boot." >&2
    echo "Try booting it manually with:" >&2
    echo "  xcrun simctl boot '$target_udid'" >&2
    xcrun simctl list devices >&2 || true
    exit 1
  fi

  printf '%s\n' "$device"
}

run_android_emulator() {
  if [ "$(current_host)" != "Linux" ]; then
    echo "Android emulator runs are only supported from Linux hosts in this repo." >&2
    exit 1
  fi

  local device
  device="$(require_running_android_emulator)"
  exec flutter run --flavor app -d "$device" -t lib/main.dart
}

run_android_dev() {
  if [ "$(current_host)" != "Linux" ]; then
    echo "Android emulator runs are only supported from Linux hosts in this repo." >&2
    exit 1
  fi

  local device
  device="$(ensure_booted_android_emulator)"
  exec flutter run --flavor app -d "$device" -t lib/main.dart
}

run_ios_simulator() {
  if [ "$(current_host)" != "Darwin" ]; then
    echo "iOS simulator runs are only supported from macOS hosts." >&2
    exit 1
  fi

  local device
  device="$(ensure_booted_ios_simulator)"
  exec flutter run -d "$device"
}

run_linux_desktop() {
  if [ "$(current_host)" != "Linux" ]; then
    echo "Linux desktop runs are only supported from Linux hosts." >&2
    exit 1
  fi

  ensure_linux_desktop_prereqs
  exec flutter run -d linux
}

run_macos_desktop() {
  if [ "$(current_host)" != "Darwin" ]; then
    echo "macOS desktop runs are only supported from macOS hosts." >&2
    exit 1
  fi

  require_command flutter
  exec flutter run -d macos
}

run_mobile() {
  case "$(current_host)" in
    Linux)
      run_android_dev
      ;;
    Darwin)
      run_ios_simulator
      ;;
    *)
      echo "Unsupported host OS for mobile runs: $(current_host)" >&2
      exit 1
      ;;
  esac
}

run_desktop() {
  case "$(current_host)" in
    Linux)
      run_linux_desktop
      ;;
    Darwin)
      run_macos_desktop
      ;;
    *)
      echo "Unsupported host OS for desktop runs: $(current_host)" >&2
      exit 1
      ;;
  esac
}

case "$command" in
  android-emulator)
    run_android_emulator
    ;;
  android-dev)
    run_android_dev
    ;;
  ios-simulator)
    run_ios_simulator
    ;;
  linux)
    run_linux_desktop
    ;;
  macos)
    run_macos_desktop
    ;;
  mobile)
    run_mobile
    ;;
  desktop)
    run_desktop
    ;;
  *)
    echo "Usage: $(basename "$0") {android-emulator|android-dev|ios-simulator|linux|macos|mobile|desktop} [android-avd] [ios-simulator]" >&2
    exit 2
    ;;
esac
