# 033 Thread/read Contract Phase 0

## Status

Implemented Phase 0 contract hardening.

This document records the current `thread/read(includeTurns: true)` contract
work that was implemented before larger history-restoration refactors.

## What Phase 0 Implemented

Phase 0 did not attempt to redesign transcript restoration yet.

It implemented the contract hardening that had to exist first:

1. A dedicated decoder seam for `thread/read` history responses.
2. Fixture-backed tests for the currently observed upstream envelope shapes.
3. Documentation of the contract findings and the remaining live-capture gate.

## Upstream Contract Findings

The repo vendored upstream references already show two relevant
`thread/read(includeTurns: true)` response envelopes.

### 1. Nested thread envelope

Shape:

```json
{
  "thread": {
    "id": "thread_1",
    "turns": [...]
  }
}
```

Reference:

- `.reference/t3code/apps/server/src/codexAppServerManager.test.ts`

### 2. Flat history envelope

Shape:

```json
{
  "threadId": "thread_1",
  "turns": [...]
}
```

Reference:

- `.reference/t3code/apps/server/src/codexAppServerManager.test.ts`

### 3. `turns` are conditional

The vendored Codex protocol definitions state that `turns` are only populated
for history-bearing responses such as `thread/read` when `includeTurns` is
true.

Reference:

- `.reference/codex/sdk/python/src/codex_app_server/generated/v2_all.py`
- `.reference/codex/codex-rs/docs/codex_mcp_interface.md`

## Why This Matters

Before this phase, Pocket Relay only decoded the nested `payload.thread` shape.

That meant a flat `thread/read` response could look superficially successful
while dropping the historical `turns` payload during decode.

That is exactly the type of silent contract mismatch that creates downstream
churn.

## Current Repo Changes

Phase 0 added:

- a dedicated decoder at
  `lib/src/features/chat/infrastructure/app_server/codex_app_server_thread_read_decoder.dart`
- reference-aligned fixtures under
  `test/fixtures/app_server/thread_read/`
- decoder contract tests
- an integration test proving `readThreadWithTurns()` preserves turns from flat
  `thread/read` responses

## Remaining Decision Gate

Phase 0 is not fully complete until the repo also contains one or more
sanitized real payload captures from a live Codex backend.

The current fixture set is upstream-reference-aligned, which is better than the
previous invented narrow shape, but it is not the same thing as a captured live
payload.

So the remaining gate is still:

1. capture a real `thread/read(includeTurns: true)` payload
2. sanitize it
3. add it as a fixture
4. confirm that the decoder and future restorer logic match that real payload

If the live payload does not contain enough transcript history to rebuild the
conversation on screen, that becomes a backend capability constraint, not a
frontend architecture problem.
