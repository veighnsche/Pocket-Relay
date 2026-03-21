# Reflector Cleanup Plan

## Baseline

This document records the current reflector baseline after merging PR 12
(`0a35fcd`).

PR 12 already removed one duplication seam:

- persisted conversation selection is now hydrated at the coordinator boundary
  instead of being threaded through `ConnectionLaneBinding` and
  `ChatSessionController` as duplicated initial state
- user-message context actions were simplified in the card itself

PR 12 did not remove the larger duplication and legacy seams described below.

## Confirmed Findings

### 1. Controller thread transitions are duplicated

The controller currently implements three separate versions of the same core
thread-history transition flow:

- restore historical thread transcript
- rollback to an earlier prompt
- fork a thread and restore the forked history

The repeated behavior includes:

- idle / restore guard checks
- app-server thread operation
- history restoration
- conversation-recovery cleanup
- historical-restore cleanup
- continuation-thread tracking
- state application
- error reporting

Primary files:

- `lib/src/features/chat/application/chat_session_controller.dart`

Primary methods:

- `continueFromUserMessage()`
- `branchSelectedConversation()`
- `_restoreConversationTranscript()`

This is the highest-priority cleanup target because it is the main source of
future churn when thread semantics change.

### 2. App-server thread RPC wrappers are repeated

The request API currently hand-rolls very similar logic for:

- `readThread()`
- `readThreadWithTurns()`
- `rollbackThread()`
- `forkThread()`

The repeated behavior includes:

- connection checks
- thread-id normalization
- request dispatch
- thread/history decoding
- tracked-thread updates

Primary files:

- `lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart`
- `lib/src/features/chat/infrastructure/app_server/codex_app_server_client.dart`

This is not broken, but it makes every new thread verb more expensive than it
should be.

### 3. Two fake app-server clients are maintained separately

There are currently two different fake backends:

- test fake:
  `test/support/fake_codex_app_server_client.dart`
- Widgetbook fake:
  `lib/widgetbook/support/fake_codex_app_server_client.dart`

They do not have the same capabilities. The test fake already knows about much
more backend behavior than the Widgetbook fake.

This is a real duplication seam and a likely source of future drift.

### 4. Production conversation-state persistence still carries compatibility paths

The connection conversation-state store still has two legacy/compatibility
branches in the main path:

- legacy handoff migration
- silent in-memory fallback when `SharedPreferencesAsync()` is unavailable

Primary files:

- `lib/src/core/storage/codex_connection_conversation_state_store.dart`
- `lib/src/core/storage/codex_connection_conversation_state_legacy_migration.dart`

This may still be justified, but it should be treated as explicit migration or
recovery code, not as invisible permanent baseline behavior.

### 5. Transcript reset behavior is split across parallel paths

Reset-like behavior exists in several overlapping variants:

- controller:
  - `startFreshConversation()`
  - `clearTranscript()`
- transcript policy:
  - `startFreshThread()`
  - `clearTranscript()`
  - `detachThread()`

These variants mostly clear the same state with small differences.

Primary files:

- `lib/src/features/chat/application/chat_session_controller.dart`
- `lib/src/features/chat/application/transcript_policy.dart`
- `lib/src/features/chat/application/transcript_reducer.dart`

This is a lower-priority duplication seam than thread transitions, but it is
still cleanup work worth doing.

### 6. Work-log classification is growing as a chained classifier

`ChatWorkLogItemProjector` now classifies work-log entries through a long
null-gated sequence:

- MCP tool call
- web search
- command wait
- read command
- git command
- search command
- generic command
- generic work-log entry fallback

Primary file:

- `lib/src/features/chat/presentation/chat_work_log_item_projector.dart`

This is not legacy yet, but it is a known expansion seam that should be
normalized before more upstream tool families are added.

## Cleanup Order

### Phase 1: Controller thread-transition consolidation

Goal:

- create one controller-owned helper for history-restoring thread transitions

Must cover:

- `thread/read`
- `thread/rollback`
- `thread/fork` plus follow-up history read

The helper should own:

- preflight guard handling where appropriate
- app-server operation execution
- restored-history mapping
- recovery/restore cleanup
- continuation-thread tracking
- state application
- failure reporting hooks

Expected outcome:

- `continueFromUserMessage()`
- `branchSelectedConversation()`
- `_restoreConversationTranscript()`

become thin action-specific wrappers.

### Phase 2: App-server thread request helper extraction

Goal:

- factor repeated thread request logic out of `CodexAppServerRequestApi`

Likely helper responsibilities:

- normalize and validate thread ids
- send thread requests with standard payload patterns
- decode summary/history responses
- update tracked thread/session identity when required

Expected outcome:

- less repeated request glue for existing thread verbs
- lower cost for adding future thread verbs

### Phase 3: Unify fake app-server infrastructure

Goal:

- stop maintaining separate backend behavior forks for Widgetbook and tests

Preferred outcome:

- one shared fake backend seam
- Widgetbook uses the same fake capability surface as tests, with only thin
  preview-specific setup

Constraint:

- Widgetbook must remain downstream-only and must not own product behavior

### Phase 4: Persistence compatibility audit and removal plan

Goal:

- decide what compatibility behavior is still intentionally supported

Audit questions:

- is legacy handoff migration still needed?
- is the `SharedPreferencesAsync` memory fallback still a real supported path?
- if the answer is no, remove it
- if the answer is yes, isolate it as explicit recovery behavior

Expected outcome:

- smaller hot path
- fewer silent mode changes

### Phase 5: Transcript reset primitive consolidation

Goal:

- unify fresh-thread, clear-transcript, and detach-thread state clearing into a
  smaller shared primitive

Expected outcome:

- fewer parallel reset implementations
- clearer ownership of “clear transcript state but optionally append a signal”

### Phase 6: Work-log classifier normalization

Goal:

- replace the long null-gated classifier chain with ordered classifier helpers
  or a more explicit dispatch pipeline

Expected outcome:

- easier addition of new upstream tool/runtime surfaces
- less accidental overlap between command specializations

## Verification Expectations

Each phase should add or update tests that prove structure, not just text.

Minimum verification by area:

- controller thread transitions:
  targeted `chat_session_controller_test.dart`
- workspace/lane activation impact:
  `connection_workspace_controller_test.dart`
- UI action wiring:
  `chat_root_adapter_test.dart`
- app-server wrapper changes:
  `codex_app_server_client_test.dart`
- work-log projection changes:
  `chat_screen_app_server_test.dart`
  and relevant presentation/widget tests

## Immediate Next Step

Start with Phase 1.

That is the highest-value reflector slice because it removes the most
duplicated thread semantics from the live controller path and reduces future
churn across restore, rollback, and fork behavior.
