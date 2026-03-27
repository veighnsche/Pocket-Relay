#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hook_path="$project_root/.githooks"
tmp_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp_dir"
}

trap cleanup EXIT

init_repo() {
  local branch="$1"
  local repo

  repo="$(mktemp -d "$tmp_dir/${branch}-repo-XXXXXX")"

  git init -b "$branch" "$repo" >/dev/null
  git -C "$repo" config user.name "Pocket Relay Hook Test"
  git -C "$repo" config user.email "pocket-relay-hook-test@example.com"
  git -C "$repo" config core.hooksPath "$hook_path"

  printf 'seed\n' >"$repo/guard.txt"
  git -C "$repo" add guard.txt
  POCKET_ALLOW_PROTECTED_BRANCH_COMMIT=1 \
    git -C "$repo" commit -m "seed" >/dev/null

  printf '%s\n' "$repo"
}

assert_commit_blocked() {
  local branch="$1"
  local repo
  local output

  repo="$(init_repo "$branch")"
  printf '%s\n' "$branch" >>"$repo/guard.txt"
  git -C "$repo" add guard.txt

  if output="$(git -C "$repo" commit -m "blocked" 2>&1)"; then
    echo "Expected commit on $branch to be blocked." >&2
    exit 1
  fi

  if ! grep -F "Start a feature branch and open a PR instead." >/dev/null <<<"$output"; then
    echo "Blocked commit on $branch did not explain the feature-branch policy." >&2
    printf '%s\n' "$output" >&2
    exit 1
  fi
}

assert_no_verify_still_blocked() {
  local repo
  local output

  repo="$(init_repo master)"
  printf 'no-verify\n' >>"$repo/guard.txt"
  git -C "$repo" add guard.txt

  if output="$(git -C "$repo" commit --no-verify -m "blocked" 2>&1)"; then
    echo "Expected --no-verify commit on master to be blocked." >&2
    exit 1
  fi

  if ! grep -F "Start a feature branch and open a PR instead." >/dev/null <<<"$output"; then
    echo "Blocked --no-verify commit did not explain the feature-branch policy." >&2
    printf '%s\n' "$output" >&2
    exit 1
  fi
}

assert_feature_branch_commit_allowed() {
  local repo

  repo="$(init_repo master)"
  git -C "$repo" switch -c feat/hook-test >/dev/null
  printf 'feature\n' >>"$repo/guard.txt"
  git -C "$repo" add guard.txt
  git -C "$repo" commit -m "feature commit" >/dev/null
}

assert_override_allowed() {
  local repo

  repo="$(init_repo master)"
  printf 'override\n' >>"$repo/guard.txt"
  git -C "$repo" add guard.txt
  POCKET_ALLOW_PROTECTED_BRANCH_COMMIT=1 \
    git -C "$repo" commit -m "override" >/dev/null
}

main() {
  assert_commit_blocked master
  assert_commit_blocked main
  assert_no_verify_still_blocked
  assert_feature_branch_commit_allowed
  assert_override_allowed
  echo "Protected-branch commit guard passed."
}

main "$@"
