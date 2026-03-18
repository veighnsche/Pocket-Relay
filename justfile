android_avd := "Pixel_9_API_36"
ios_simulator := "apple_ios_simulator"

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
run-linux:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-run.sh" linux "{{android_avd}}" "{{ios_simulator}}"

[no-exit-message]
[script]
run-macos:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-run.sh" macos "{{android_avd}}" "{{ios_simulator}}"

[no-exit-message]
[script]
run-ios-simulator:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-run.sh" ios-simulator "{{android_avd}}" "{{ios_simulator}}"

[no-exit-message]
[script]
run-mobile:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-run.sh" mobile "{{android_avd}}" "{{ios_simulator}}"

[no-exit-message]
[script]
run-desktop:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-run.sh" desktop "{{android_avd}}" "{{ios_simulator}}"

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

    exec "{{ justfile_directory() }}/scripts/host-run.sh" android-emulator "{{android_avd}}" "{{ios_simulator}}"

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

    exec "{{ justfile_directory() }}/scripts/host-run.sh" android-dev "{{android_avd}}" "{{ios_simulator}}"

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

[no-exit-message]
[script]
codex-mcp-loop:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/codex-mcp-loop.sh"

[no-exit-message]
[script]
screenshot-ios *args:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-screenshot.sh" ios "$@"

[no-exit-message]
[script]
screenshot-macos *args:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-screenshot.sh" macos "$@"

[no-exit-message]
[script]
screenshot-desktop *args:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-screenshot.sh" desktop "$@"

[no-exit-message]
[script]
screenshot-both *args:
    #!/usr/bin/env bash
    set -euo pipefail

    exec "{{ justfile_directory() }}/scripts/host-screenshot.sh" both "$@"
