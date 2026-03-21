# 036 Live Thread/read Capture Workflow

## Status

Capture workflow added to close the remaining pre-cleanup gate for historical
conversation restoration.

## Why This Exists

Phase 5 cleanup should not start until Pocket Relay has verified the restore
path against a sanitized real `thread/read(includeTurns: true)` payload from
live Codex.

This workflow defines how to capture and sanitize that payload without turning
Pocket Relay into a local historical archive.

## Workflow

1. Capture one real `thread/read(includeTurns: true)` JSON payload from a live
   Codex session outside the repo.
2. Save that raw payload to a temporary local file.
3. Sanitize it with:

```bash
dart run tool/sanitize_thread_read_fixture.dart \
  --input /tmp/raw_thread_read.json \
  --output test/fixtures/app_server/thread_read/live_capture_001.json
```

4. Add decoder, normalizer, and restore tests against the sanitized fixture.
5. Re-run:
   - `dart analyze`
   - `flutter test`

## What The Sanitizer Does

The sanitizer preserves structural protocol fields such as:

- `type`
- `status`
- `kind`
- `model`
- `modelProvider`
- `effort`
- `reasoningEffort`

It redacts likely-sensitive values into stable placeholders, including:

- thread / turn / item ids
- preview text
- names
- cwd and path strings
- content text and other free-form strings

## Decision Gate

After the sanitized live fixture is in the repo, the team must confirm one of
these is true:

1. Pocket Relay already restores the transcript correctly against the real
   upstream shape.
2. Pocket Relay still needs frontend parsing/normalization changes.
3. Codex does not provide enough transcript content in `thread/read`, which
   makes the remaining blocker an upstream capability gap rather than a local
   architecture problem.
