android_avd := "Pixel_6"
ios_simulator := "iPhone 15"

# List the canonical recipe surface without compatibility aliases.
[private]
default:
    @just --list --no-aliases --unsorted

# Inspect the local Flutter toolchain and SDK wiring.
doctor:
    flutter doctor -v

# Boot the standard Pixel 6 Android emulator only.
android-emulator:
    emulator @{{android_avd}} -gpu swiftshader_indirect -no-audio -no-snapshot -no-boot-anim -no-metrics

alias emulator := android-emulator

# Boot the standard Pixel 6 Android emulator with host GPU acceleration on Linux.
android-emulator-host:
    env __GLX_VENDOR_LIBRARY_NAME=mesa QT_QPA_PLATFORM=xcb emulator @{{android_avd}} -gpu host -no-audio -no-snapshot -no-boot-anim -no-metrics

alias emulator-host-experimental := android-emulator-host

# Run on a directly connected Android device.
[private]
android-device:
    flutter run -d android

alias run-android := android-dev

# Run on a directly connected iOS device.
[private]
ios-device:
    flutter run -d ios

alias run-ios := ios-simulator

# Run the Linux desktop app on a Linux host.
[no-exit-message]
[script]
linux-desktop:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-run.sh" linux "{{android_avd}}" "{{ios_simulator}}"

alias run-linux := linux-desktop

# Run the macOS desktop app on a macOS host.
[no-exit-message]
[script]
macos-desktop:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-run.sh" macos "{{android_avd}}" "{{ios_simulator}}"

alias run-macos := macos-desktop

# Boot the standard iPhone 15 simulator if needed and run the app.
[no-exit-message]
[script]
ios-simulator:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-run.sh" ios-simulator "{{android_avd}}" "{{ios_simulator}}"

alias run-ios-simulator := ios-simulator

# Run the host-appropriate mobile target.
[no-exit-message]
[script]
mobile:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-run.sh" mobile "{{android_avd}}" "{{ios_simulator}}"

alias run-mobile := mobile

# Run the host-appropriate desktop target.
[no-exit-message]
[script]
desktop:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-run.sh" desktop "{{android_avd}}" "{{ios_simulator}}"

alias run-desktop := desktop

# Run Widgetbook on the host desktop target.
[no-exit-message]
[script]
widgetbook:
    #!/usr/bin/env bash
    set -euo pipefail

    cd "{{ justfile_directory() }}"

    case "$(uname -s)" in
      Darwin)
        exec flutter run -d macos -t lib/widgetbook/main.dart
        ;;
      Linux)
        exec flutter run -d linux -t lib/widgetbook/main.dart
        ;;
      *)
        echo "Unsupported host for 'just widgetbook'. Use 'flutter run -t lib/widgetbook/main.dart' with an explicit device." >&2
        exit 1
        ;;
    esac

alias wb := widgetbook

# Boot the standard iPhone 15 simulator if needed and run Widgetbook on it.
[no-exit-message]
[script]
widgetbook-ios:
    #!/usr/bin/env bash
    set -euo pipefail

    cd "{{ justfile_directory() }}"

    device_line="$(xcrun simctl list devices available | rg -F "{{ios_simulator}} (" | head -n 1)"
    if [ -z "$device_line" ]; then
      echo "No available iOS simulator matched '{{ios_simulator}}'." >&2
      exit 1
    fi

    device="$(printf '%s\n' "$device_line" | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')"

    booted="$(xcrun simctl list devices | rg -F '{{ios_simulator}}' | rg 'Booted' || true)"
    if [ -z "$booted" ]; then
      open -a Simulator
      xcrun simctl boot "$device" >/dev/null 2>&1 || true
    fi

    exec flutter run -d "$device" -t lib/widgetbook/main.dart

alias wb-ios := widgetbook-ios

# Generate launcher icons from icon.png.
[no-exit-message]
[script]
icons:
    #!/usr/bin/env bash
    set -euo pipefail

    cd "{{ justfile_directory() }}"
    mkdir -p assets/icons

    magick icon.png \
      -trim +repage \
      -resize 824x824 \
      -gravity center \
      -background none \
      -extent 1024x1024 \
      assets/icons/app_icon_master.png

    flutter pub get
    dart run flutter_launcher_icons

# Run against an already booted Pixel 6 Android emulator.
[no-exit-message]
[script]
android-emulator-run:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-run.sh" android-emulator "{{android_avd}}" "{{ios_simulator}}"

alias run-android-emulator := android-dev

# Attach Flutter to an already booted Android emulator.
[no-exit-message]
[script]
android-attach:
    #!/usr/bin/env bash
    set -euo pipefail

    device="$(adb devices | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1; exit }')"
    if [ -z "$device" ]; then
      echo "No running Android emulator found." >&2
      exit 1
    fi

    exec flutter attach -d "$device"

alias attach-android-emulator := android-attach

# Boot the standard Pixel 6 Android emulator if needed and run the app on it.
[no-exit-message]
[script]
android-dev:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-run.sh" android-dev "{{android_avd}}" "{{ios_simulator}}"

# Launch Codex with the repo-local MCP wiring.
[no-exit-message]
[script]
codex-mcp *args:
    #!/usr/bin/env bash
    set -euo pipefail

    project_root="{{ justfile_directory() }}"

    if command -v flutter >/dev/null 2>&1; then
      flutter_bin="$(dirname "$(readlink -f "$(command -v flutter)")")"
      flutter_root="$(cd "$flutter_bin/.." && pwd)"
    else
      flutter_root="${FLUTTER_ROOT:-$HOME/.local/share/flutter}"
      flutter_bin="$flutter_root/bin"
    fi

    dart_bin="$flutter_root/bin/dart"

    if [ ! -x "$dart_bin" ]; then
      echo "Dart binary not found at $dart_bin" >&2
      exit 127
    fi

    export FLUTTER_ROOT="$flutter_root"
    export FLUTTER_SDK="$flutter_root"
    export PATH="$flutter_bin:$PATH"
    export PATH="$HOME/.local/bin:$HOME/bin:$HOME/.bun/bin:$PATH"

    fnm_bin="${FNM_DIR:-$HOME/.local/share/fnm}/fnm"
    if ! command -v codex >/dev/null 2>&1 || ! command -v npx >/dev/null 2>&1; then
      if command -v fnm >/dev/null 2>&1; then
        eval "$(fnm env --shell bash)"
      elif [ -x "$fnm_bin" ]; then
        export PATH="$(dirname "$fnm_bin"):$PATH"
        eval "$("$fnm_bin" env --shell bash)"
      fi
    fi

    if ! command -v flutter >/dev/null 2>&1; then
      echo "Flutter binary not found on PATH after adding $flutter_bin" >&2
      exit 127
    fi

    if ! command -v codex >/dev/null 2>&1; then
      echo "Codex CLI not found on PATH" >&2
      exit 127
    fi

    if ! command -v npx >/dev/null 2>&1; then
      echo "npx not found on PATH" >&2
      exit 127
    fi

    exec codex \
      --dangerously-bypass-approvals-and-sandbox \
      -C "$project_root" \
      -c "mcp_servers.dart.command=\"$dart_bin\"" \
      -c "mcp_servers.dart.args=[\"mcp-server\",\"--flutter-sdk\",\"$flutter_root\",\"--force-roots-fallback\",\"--tools\",\"all\"]" \
      -c "mcp_servers.mobile-mcp.command=\"npx\"" \
      -c "mcp_servers.mobile-mcp.args=[\"@mobilenext/mobile-mcp@latest\"]" \
      {{args}}

# Relaunch the MCP-wired Codex loop whenever it exits.
[no-exit-message]
[script]
codex-mcp-loop:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/codex-mcp-loop.sh"

# Capture an iOS screenshot through the host helper.
[no-exit-message]
[script]
screenshot-ios *args:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-screenshot.sh" ios "$@"

# Capture a macOS screenshot through the host helper.
[no-exit-message]
[script]
screenshot-macos *args:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-screenshot.sh" macos "$@"

# Capture the current desktop screenshot through the host helper.
[no-exit-message]
[script]
screenshot-desktop *args:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-screenshot.sh" desktop "$@"

# Capture both iOS and macOS screenshots through the host helper.
[no-exit-message]
[script]
screenshot-all *args:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-screenshot.sh" both "$@"

alias screenshot-both := screenshot-all
