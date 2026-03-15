# Pre-Phase-5 Infrastructure Plan

This document was the gate for Phase 5.

Phase 5 is now complete. This file is kept as the planning record for the infrastructure cut.

The active high-level refactor history still lives in `docs/app-server-migration-plan.md`. This document exists because the Phase 5 prep work was large enough to deserve its own planning artifact.

## Why This Exists

Phases 1 through 4 split:

- transcript rendering
- transcript state
- runtime mapping
- screen orchestration

At the time this document was written, that left one major concentration point:

- `lib/src/features/chat/services/codex_app_server_client.dart`

That file still owns too many unrelated responsibilities at once:

1. app-server transport event models
2. session and turn value objects
3. connection lifecycle
4. JSON-RPC request/response flow
5. inbound host-request tracking
6. app-server method wrappers
7. runtime pointer bookkeeping
8. SSH bootstrap and remote process startup
9. concrete SSH-backed process implementation

If we start Phase 5 without a stricter plan, we will just move complexity around and re-create the same coupling in smaller files.

## State At Time Of Planning

Current relevant hotspot sizes:

| LOC | File |
| ---: | --- |
| 929 | `lib/src/features/chat/services/codex_app_server_client.dart` |
| 1204 | `lib/src/features/chat/application/transcript_policy.dart` |
| 542 | `lib/src/features/chat/application/runtime_event_mapper_notification_mapper.dart` |
| 468 | `lib/src/features/chat/application/chat_session_controller.dart` |

Important consequence:

- Phase 5 is optional as the next cut.
- `transcript_policy.dart` is still the biggest behavioral hotspot.
- Phase 5 only makes sense if we want to finish the presentation/application/infrastructure layering before returning to transcript behavior.

## Phase-5 Decision Gate

Phase 5 should start only if all of these are true:

1. We want to clean up infrastructure next, not continue attacking transcript behavior first.
2. We are willing to move the transport files from `services/` to `infrastructure/app_server/`.
3. We will keep `CodexAppServerClient` as the stable public facade instead of rewriting every caller.
4. We accept a hard-cut/fix-callsites migration with no legacy wrappers.
5. The split is justified by ownership boundaries, not just line count.

If any of those are false, we should not start Phase 5 yet.

## Phase-5 Non-Goals

Phase 5 must not do any of this:

- change chat UI behavior
- redesign request handling semantics
- change JSON-RPC payload shapes
- reintroduce any legacy transport path
- move runtime mapping back into infrastructure
- add new product behavior under cover of refactor work
- split files into tiny units with unclear ownership

## Public Surface To Freeze

Before Phase 5 begins, this public surface should be treated as stable:

- `CodexAppServerClient.connect(...)`
- `CodexAppServerClient.startSession(...)`
- `CodexAppServerClient.sendUserMessage(...)`
- `CodexAppServerClient.answerUserInput(...)`
- `CodexAppServerClient.respondDynamicToolCall(...)`
- `CodexAppServerClient.resolveApproval(...)`
- `CodexAppServerClient.rejectServerRequest(...)`
- `CodexAppServerClient.respondToElicitation(...)`
- `CodexAppServerClient.abortTurn(...)`
- `CodexAppServerClient.disconnect()`
- `CodexAppServerClient.events`
- `CodexAppServerClient.isConnected`
- `CodexAppServerClient.threadId`
- `CodexAppServerClient.activeTurnId`

The application layer, especially `ChatSessionController`, should not need semantic changes just because infrastructure gets reorganized.

## Ownership Split To Enforce

This is the core of the plan.

### `CodexAppServerClient`

Keep as the public facade.

It should own:

- the public API surface
- composition of infra helpers
- stable outward behavior for callers

It should stop owning:

- SSH bootstrap details
- stdout/stderr decode loop details
- direct JSON-RPC request bookkeeping
- pointer update switch internals

### Connection / Runtime Channel Layer

This layer should own:

- process open/close lifecycle
- stdout/stderr subscriptions
- JSON-RPC decode loop
- emitting app-server events
- runtime pointer updates from notifications
- disconnected-state cleanup

It should not know about transcript state or UI behavior.

### Request API Layer

This layer should own:

- outbound app-server method wrappers like `thread/start`, `thread/resume`, `turn/start`, and `turn/interrupt`
- inbound host-request validations
- approval decision encoding
- user-input and elicitation result encoding
- server-result and server-error responses

It should not own:

- process lifetime
- Flutter callbacks
- transcript semantics

### SSH Process Layer

This layer should own:

- SSH socket/client setup
- host-key verification
- identity/password auth setup
- remote command construction
- concrete `CodexAppServerProcess` implementation

It should not own:

- JSON-RPC semantics
- app-server request ids
- session state

## Proposed Target Tree For Phase 5

This is the target I would use if we start Phase 5.

```text
lib/src/features/chat/
  infrastructure/
    app_server/
      codex_app_server_client.dart
      codex_app_server_connection.dart
      codex_app_server_request_api.dart
      codex_app_server_ssh_process.dart
      codex_json_rpc_codec.dart
```

Optional only if the first cut still leaves one file too broad:

```text
lib/src/features/chat/
  infrastructure/
    app_server/
      codex_app_server_models.dart
```

That optional models file would hold:

- event classes
- session/turn value objects
- exception type
- `CodexAppServerProcess`
- `CodexAppServerProcessLauncher`

I would not create more files than this in the first wave.

## Mapping From Current Code To Target Ownership

Current `codex_app_server_client.dart` contents map like this:

- top-level event/session/turn/process declarations:
  candidate for `codex_app_server_models.dart` or keep beside the facade initially
- `connect`, `_disconnect`, `_handleStdoutLine`, `_handleProcessClosed`, `_updateRuntimePointers`, `_writeMessage`, `_emitEvent`, `_decodeLines`:
  move toward `codex_app_server_connection.dart`
- `startSession`, `sendUserMessage`, `answerUserInput`, `respondDynamicToolCall`, `resolveApproval`, `rejectServerRequest`, `respondToElicitation`, `abortTurn`:
  move toward `codex_app_server_request_api.dart`
- `_openSshProcess`, `_buildIdentities`, `_buildRemoteCommand`, `_SshCodexAppServerProcess`:
  move toward `codex_app_server_ssh_process.dart`
- `_approvalPolicyFor`, `_sandboxFor`, `_grantedPermissionsFromRequest`, `_isRecoverableThreadResumeError`:
  keep with the layer that uses them after the first cut

## Proposed Phase-5 Sequence

### Phase 5A: Path Move And SSH Extraction

Goal:

- move transport code into `infrastructure/app_server/`
- extract SSH bootstrap/process implementation first

Reason:

- this is the cleanest ownership seam
- it removes concrete transport setup from the client facade early

### Phase 5B: Extract Connection / Decode Loop

Goal:

- extract process lifecycle, stdout/stderr subscriptions, disconnect cleanup, and runtime pointer updates

Reason:

- this is the second clear ownership seam
- it separates connection state from method wrappers

### Phase 5C: Extract Request API Helpers

Goal:

- extract request/response helpers and inbound host-request response logic

Reason:

- this leaves the facade as a thin composition layer
- it makes request behavior testable without the full client file

### Phase 5D: Reassess

Goal:

- stop if the remaining facade is already small and clear

Do not continue splitting just because more files could be created.

## Required Test Coverage Before Or During Phase 5

These behaviors must remain covered:

1. connect performs initialize handshake and emits connected event
2. startSession starts a new thread correctly
3. startSession resumes an existing thread correctly
4. resume fallback to start works on recoverable errors
5. ephemeral sessions ignore resume ids
6. sendUserMessage encodes turn input correctly
7. approval requests resolve correctly
8. permissions requests resolve correctly
9. user-input requests answer correctly
10. elicitation requests answer correctly
11. dynamic tool requests respond correctly
12. auth-token refresh requests respond or reject correctly
13. request rejection emits the right JSON-RPC error
14. session exit and thread/turn pointer cleanup still happen
15. disconnect fails pending requests and clears inbound-request memory

The existing `test/codex_app_server_client_test.dart` already covers much of this. Phase 5 should preserve or sharpen those tests, not weaken them.

## Pre-Phase-5 Checklist

This is the checklist that must be explicitly answered before starting:

1. Are we doing infrastructure next, or do we want to split `transcript_policy.dart` first?
2. Are we moving from `services/` to `infrastructure/app_server/` in the same phase?
3. Are we keeping `CodexAppServerClient` as the stable public facade?
4. Which declarations stay in the facade file, and which move immediately?
5. Is `codex_app_server_models.dart` in scope, or do we defer that cut?
6. Which existing tests must move or be renamed as part of the infra split?
7. What is the stop condition for Phase 5?

## Stop Conditions

Stop Phase 5 immediately if either of these happens:

1. The split starts forcing behavior changes into `ChatSessionController` or higher layers.
2. The new infra files do not produce clearer ownership than the old single file.

If that happens, roll back the planned next extraction and keep the simpler boundary.

## Recommended Decision

My recommendation right now:

1. Keep this document as the gate for Phase 5.
2. Decide explicitly whether infra is actually next.
3. If infra is next, start with Phase 5A only: path move plus SSH/process extraction.
4. Re-run `dart analyze` and the full `flutter test` suite after each subphase, not only at the end.

If we are optimizing for bug reduction rather than layer completeness, the better next move may still be `transcript_policy.dart` instead of Phase 5.
