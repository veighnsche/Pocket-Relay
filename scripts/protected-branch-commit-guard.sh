#!/usr/bin/env bash
set -euo pipefail

current_branch() {
  git symbolic-ref --quiet --short HEAD 2>/dev/null || true
}

is_protected_branch() {
  case "${1:-}" in
    master|main)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

main() {
  local branch
  branch="${1:-$(current_branch)}"

  if [ -z "$branch" ] || ! is_protected_branch "$branch"; then
    exit 0
  fi

  if [ "${POCKET_ALLOW_PROTECTED_BRANCH_COMMIT:-}" = "1" ]; then
    exit 0
  fi

  cat >&2 <<EOF
Direct commits to '$branch' are blocked in this repo.
Start a feature branch and open a PR instead.

If the operator explicitly approved a one-off protected-branch commit, rerun:
  POCKET_ALLOW_PROTECTED_BRANCH_COMMIT=1 git commit ...

Typical flow:
  git switch -c feat/<short-name>
EOF
  exit 1
}

main "$@"
