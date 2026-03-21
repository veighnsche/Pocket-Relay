# 036 Live Thread/read Capture Workflow

## Status

Capture workflow implemented and exercised. The repo now contains one sanitized
live Codex fixture at
`test/fixtures/app_server/thread_read/live_capture_001.json`.

## Why This Exists

Phase 5 cleanup should not start until Pocket Relay has verified the restore
path against a sanitized real `thread/read(includeTurns: true)` payload from
live Codex.

This workflow defines how to capture and sanitize that payload without turning
Pocket Relay into a local historical archive.

## Workflow

1. Preferred path: capture and sanitize directly with:

```bash
dart run tool/capture_live_thread_read_fixture.dart \
  --sanitized-output test/fixtures/app_server/thread_read/live_capture_001.json \
  --raw-output /tmp/raw_thread_read.json
```

2. Fallback path if the raw payload is captured elsewhere:

```bash
dart run tool/sanitize_thread_read_fixture.dart \
  --input /tmp/raw_thread_read.json \
  --output test/fixtures/app_server/thread_read/live_capture_001.json
```

3. Add decoder, normalizer, and restore tests against the sanitized fixture.
4. Re-run:
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

The first live fixture already answered the gate:

1. Codex does provide transcript-bearing history for this captured thread.
2. Pocket Relay's current decoder, normalizer, and restorer handle the
   captured live payload shape.
3. Phase 5 cleanup is no longer blocked on `thread/read` contract uncertainty.

Future captures should still follow this workflow whenever Codex history shape
changes materially.
