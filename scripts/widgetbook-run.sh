#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

device="${1:-}"
if [ -z "$device" ]; then
  echo "Usage: $(basename "$0") <device>" >&2
  exit 2
fi

target_files=(
  "ios/Flutter/Generated.xcconfig"
  "macos/Flutter/ephemeral/Flutter-Generated.xcconfig"
)

backup_dir="$(mktemp -d)"

restore_targets() {
  local path
  for path in "${target_files[@]}"; do
    local backup_path="$backup_dir/${path//\//__}"
    if [ -f "$backup_path" ]; then
      mkdir -p "$(dirname "$path")"
      cp "$backup_path" "$path"
    elif [ -f "$path" ]; then
      rm -f "$path"
    fi
  done
  rm -rf "$backup_dir"
}

trap restore_targets EXIT INT TERM

for path in "${target_files[@]}"; do
  if [ -f "$path" ]; then
    mkdir -p "$(dirname "$backup_dir/${path//\//__}")"
    cp "$path" "$backup_dir/${path//\//__}"
  fi
done

flutter run -d "$device" -t lib/widgetbook/main.dart
