#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

command="${1:-}"
android_avd="${2:-}"
ios_simulator="${3:-apple_ios_simulator}"

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

booted_android_emulator() {
  require_command adb
  adb devices | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1; exit }'
}

require_running_android_emulator() {
  local device
  device="$(booted_android_emulator)"
  if [ -z "$device" ]; then
    echo "No running Android emulator found. Start one with 'just emulator' or 'just android-dev'." >&2
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
  device="$(booted_android_emulator)"
  if [ -n "$device" ]; then
    printf '%s\n' "$device"
    return 0
  fi

  flutter emulators --launch "$android_avd"

  until device="$(booted_android_emulator)"; [ -n "$device" ]; do
    sleep 2
  done

  until [ "$(adb -s "$device" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
    sleep 2
  done

  printf '%s\n' "$device"
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

ensure_booted_ios_simulator() {
  require_command flutter
  require_command open

  local device
  if device="$(booted_ios_simulator_udid)"; then
    printf '%s\n' "$device"
    return 0
  fi

  flutter emulators --launch "$ios_simulator" >/dev/null 2>&1 || open -a Simulator

  until device="$(booted_ios_simulator_udid)"; do
    sleep 2
  done

  printf '%s\n' "$device"
}

run_android_emulator() {
  if [ "$(current_host)" != "Linux" ]; then
    echo "Android emulator runs are only supported from Linux hosts in this repo." >&2
    exit 1
  fi

  local device
  device="$(require_running_android_emulator)"
  exec flutter run -d "$device"
}

run_android_dev() {
  if [ "$(current_host)" != "Linux" ]; then
    echo "Android emulator runs are only supported from Linux hosts in this repo." >&2
    exit 1
  fi

  local device
  device="$(ensure_booted_android_emulator)"
  exec flutter run -d "$device"
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
