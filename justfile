android_avd := "Pixel_9_API_36"

default:
    @just --list

doctor:
    flutter doctor -v

emulator:
    emulator @{{android_avd}} -gpu swiftshader_indirect -no-audio -no-snapshot -no-boot-anim -no-metrics

emulator-host-experimental:
    env __GLX_VENDOR_LIBRARY_NAME=mesa QT_QPA_PLATFORM=xcb emulator @{{android_avd}} -gpu host -no-audio -no-snapshot -no-boot-anim -no-metrics

run-android:
    flutter run -d android

run-ios:
    flutter run -d ios

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

[no-exit-message]
[script]
run-android-emulator:
    #!/usr/bin/env bash
    set -euo pipefail

    device="$(adb devices | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1; exit }')"
    if [ -z "$device" ]; then
      echo "No running Android emulator found. Start one with 'just emulator' or 'just android-dev'." >&2
      exit 1
    fi

    exec flutter run -d "$device"

[no-exit-message]
[script]
attach-android-emulator:
    #!/usr/bin/env bash
    set -euo pipefail

    device="$(adb devices | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1; exit }')"
    if [ -z "$device" ]; then
      echo "No running Android emulator found." >&2
      exit 1
    fi

    exec flutter attach -d "$device"

[no-exit-message]
[script]
android-dev:
    #!/usr/bin/env bash
    set -euo pipefail

    avd="{{android_avd}}"
    device="$(adb devices | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1; exit }')"

    if [ -z "$device" ]; then
      flutter emulators --launch "$avd"

      until device="$(adb devices | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1; exit }')"; [ -n "$device" ]; do
        sleep 2
      done

      until [ "$(adb -s "$device" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
        sleep 2
      done
    fi

    exec flutter run -d "$device"

[no-exit-message]
[script]
codex-mcp:
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

    if ! command -v flutter >/dev/null 2>&1; then
      echo "Flutter binary not found on PATH after adding $flutter_bin" >&2
      exit 127
    fi

    if ! command -v codex >/dev/null 2>&1; then
      echo "Codex CLI not found on PATH" >&2
      exit 127
    fi

    exec codex \
      --dangerously-bypass-approvals-and-sandbox \
      -C "$project_root" \
      -c "mcp_servers.dart.command=\"$dart_bin\"" \
      -c "mcp_servers.dart.args=[\"mcp-server\",\"--flutter-sdk\",\"$flutter_root\",\"--force-roots-fallback\",\"--tools\",\"all\"]"

[no-exit-message]
[script]
codex-mcp-loop:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/codex-mcp-loop.sh"
