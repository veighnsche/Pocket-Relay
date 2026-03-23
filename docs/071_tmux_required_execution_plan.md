# Tmux-Required Execution Plan

## Status

This is the definitive execution plan for the remote continuity upgrade.

It replaces further option exploration with a fixed implementation sequence for
the chosen architecture.

Related docs:

- [`069_true_live_turn_continuity_contract.md`](./069_true_live_turn_continuity_contract.md)
- [`070_true_live_turn_continuity_migration_map.md`](./070_true_live_turn_continuity_migration_map.md)
- [`072_true_live_turn_continuity_slice_plan.md`](./072_true_live_turn_continuity_slice_plan.md)

## Locked Decisions

These decisions are now fixed for the supported remote path:

- `tmux` is required
- there is no degraded remote mode without `tmux`
- the durable owner is remote-side, not phone-side
- the remote server lifecycle is user-owned
- the user explicitly starts, stops, and restarts the remote server
- Pocket Relay may automatically discover and connect to an already-running
  healthy server
- Pocket Relay must not implicitly start, stop, or replace the remote server
  during ordinary reconnect behavior
- the reconnectable transport is app-server websocket
- live reattach uses reconnect-time `thread/resume`
- `thread/read` is truthful fallback only after real continuity loss
- brief post-turn lock/unlock must not rebuild an existing in-memory lane
- Pocket Relay does not own historical transcript truth

## What "Done" Means

The remote upgrade is done only when all of these are true:

1. Remote mode enforces `tmux` and `codex` prerequisites honestly.
2. Remote mode exposes explicit `Start server`, `Stop server`, and
   `Restart server` controls.
3. Pocket Relay can discover whether a Pocket Relay-managed remote server is
   already running for the selected connection/workspace.
4. Pocket Relay can connect to an already-running healthy server without
   starting another one.
5. Pocket Relay no longer treats remote SSH stdio as the primary remote owner.
6. A fresh Pocket Relay process can reconnect to that same running server
   through websocket.
7. Reconnect uses `thread/resume` before any history fallback.
8. `thread/read` is used only after real continuity loss or finished-turn
   fallback.
9. Brief post-turn lock/unlock does not discard an existing surviving lane.
10. The old implicit remote owner lifecycle is deleted.

## Implementation Strategy

The plan is intentionally split into phases that reduce downstream churn.

The rule is:

- do not delete old behavior before its replacement exists
- do not keep the old behavior after the replacement is verified
- do not leave server lifetime ownership implicit anywhere in the final path

## Completion Guardrails

The feature must not be marked complete through any of these shortcuts:

- reconnecting to history via `thread/read` and calling that live continuity
- silently auto-starting a fresh remote server during reconnect and calling it
  the same live run
- silently replacing one remote server with another and still claiming
  continuity
- leaving remote SSH stdio alive as a hidden primary path while claiming the
  migration is done
- delaying `thread/resume` until the next outbound prompt and calling that
  reattach
- showing UI controls such as `Start server` or `Stop server` before they are
  wired to real remote lifecycle behavior
- inferring "server is healthy" from naming only without real verification
- preserving only local in-memory state and calling that recovery after a real
  cold start
- using app-local transcript history as a substitute for Codex truth

If any of those are still true, the feature is not done even if the UI looks
plausible.

## Phase 0: Preserve Existing Lane On Pure Transport Recovery

### Purpose

Eliminate the avoidable current regression where brief post-turn screen-off
causes lane rebuild and detail loss even though the lane still exists in
memory.

### Scope

- keep the current transport mechanism
- change reconnect policy only

### Must not do

- do not rebuild the lane from `thread/read` on pure same-process reconnect
- do not widen this phase into websocket or `tmux` work
- do not treat brief post-turn lock/unlock like a cold-start restore

### Required behavior

- pure transport reconnect must reuse the existing binding when saved settings
  did not change
- reconnect must not rebuild the lane from `thread/read` in that case

### Files

- `lib/src/features/workspace/application/connection_workspace_controller_lifecycle.dart`
- `test/connection_workspace_controller_test.dart`
- `test/workspace_app_lifecycle_host_test.dart`

### Exit criteria

- same-process short lock/unlock no longer forces lane recreation
- focused tests prove in-place reconnect behavior

## Phase 1: Introduce The Ownership And Transport Seams

### Purpose

Stop the codebase from being hard-wired to remote spawned-process stdio.

### Scope

- no product flip yet
- create the seams the final architecture needs

### Must not do

- do not leave spawned-process ownership hidden behind a renamed interface
- do not mix remote server lifecycle policy into the generic transport seam
- do not break the current stdio path before its temporary adapter exists

### Required changes

- split SSH bootstrap responsibilities from transport responsibilities
- split remote server discovery/control responsibilities from transport
  responsibilities
- make app-server connection transport-shaped instead of process-shaped
- keep stdio as a temporary compatibility adapter only during migration

### Files

- `lib/src/features/chat/transport/app_server/codex_app_server_connection.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_connection_lifecycle.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_client.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart`

### Add

- reconnectable websocket transport implementation
- remote server discovery/control seam

### Exit criteria

- workspace/controller layers no longer depend on spawned-process ownership
- websocket transport can exist without pretending to own remote lifetime

## Phase 2: Implement Capability Probe And Server Discovery

### Purpose

Make the remote prerequisite and running-server inventory real.

### Must not do

- do not collapse missing `tmux` and stopped server into the same state
- do not infer capability from saved config alone without real host checks
- do not treat a named `tmux` session as enough proof of server health

### Required behavior

- probe `tmux` presence explicitly
- probe remote `codex` launcher availability explicitly
- discover Pocket Relay-managed remote servers deterministically
- classify:
  - prerequisite missing
  - server not running
  - server unhealthy
  - server running and connectable

### Files

- `lib/src/features/connection_settings/application/...`
- `lib/src/features/connection_settings/domain/...`
- `lib/src/features/workspace/application/...`

### Add

- remote capability probe helper
- remote server inventory/discovery helper

### Exit criteria

- Pocket Relay can tell the user honestly whether a host is eligible
- Pocket Relay can tell the user honestly whether a server is already running
- missing `tmux` is a hard prerequisite failure, not a degraded runtime mode
- "no server running" is distinct from "host unsupported"

## Phase 3: Implement Explicit Remote Server Controls

### Purpose

Move server lifetime ownership out of hidden reconnect behavior and into
explicit user actions.

### Must not do

- do not auto-start or auto-stop the remote server as a side effect of reconnect
- do not ship UI-only controls before the remote actions are real
- do not treat restart as an implicit reconnect fallback

### Required behavior

- add explicit `Start server`
- add explicit `Stop server`
- add explicit `Restart server`
- start creates the Pocket Relay-managed `tmux` owner and launches websocket
  app-server intentionally
- stop tears that owner down intentionally
- restart is explicit replacement, not implicit reconnect behavior
- ordinary disconnect/backgrounding never counts as a stop signal

### Files

- `lib/src/features/workspace/presentation/...`
- `lib/src/features/workspace/application/...`
- `lib/src/features/chat/transport/app_server/...`

### Add

- remote server control helper
- UI states and actions for explicit server ownership

### Exit criteria

- Pocket Relay no longer decides server lifetime implicitly
- the user can intentionally start and stop the remote server

## Phase 4: Connect To The Existing `tmux`-Owned Websocket Server

### Purpose

Reach the already-running user-owned server without recreating ownership on
connect.

### Must not do

- do not silently start a replacement server when attach fails
- do not keep SSH stdio as a hidden default remote owner path
- do not let websocket transport own discovery or lifecycle policy

### Required behavior

- SSH bootstraps secure reachability and discovery only
- `tmux` owns the long-lived remote app-server
- app-server listens on websocket
- Pocket Relay reaches it through the chosen SSH-forwarded path
- if no healthy server is running, Pocket Relay surfaces that state instead of
  silently starting one

### Files

- `lib/src/features/chat/transport/app_server/...`
- remote server discovery/control helper

### Delete in this phase

- remote SSH stdio as the default remote ownership model

### Exit criteria

- a user-started remote server survives the phone app leaving the foreground
- Pocket Relay can reconnect to that same server without launching a
  replacement

## Phase 5: Implement Real Live Reattach

### Purpose

Stop history restore from masquerading as continuity.

### Must not do

- do not call `thread/read` first and label that continuity
- do not delay `thread/resume` until the next user prompt
- do not synthesize pending approvals or input locally and call that success

### Required behavior

- reconnect path calls `initialize`
- reconnect path performs `thread/resume(selectedThreadId)` for live re-entry
- pending approval and user-input state are restored onto the reattached lane
- `thread/read` is used only when the server is gone, the turn already
  finished, or continuity cannot be proven

### Files

- `lib/src/features/chat/lane/application/chat_session_controller_recovery.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_history.dart`
- `lib/src/features/workspace/application/connection_workspace_controller_lifecycle.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_request_api_session_thread.dart`

### Delete in this phase

- history-first reconnect as the default transport recovery path
- prompt-send-triggered resume as the normal reattach path

### Exit criteria

- reconnect enters the same live thread when continuity is still available
- history restore is no longer the default answer to interrupted continuity

## Phase 6: Remove The Old Remote Recovery Model

### Purpose

Pay down the temporary migration compatibility and leave only the intended
remote architecture standing.

### Must not do

- do not leave any hidden remote SSH stdio ownership path reachable
- do not keep ambiguous reconnect UI states for convenience
- do not declare the migration complete before the delete list and verification
  matrix are actually satisfied

### Delete

- remote SSH stdio as primary remote path
- any remote reconnect logic that recreates lanes by default after pure
  transport loss
- any remote mode messaging that implies `tmux` is optional
- any code path that waits for the next prompt before performing the normal
  reattach
- implicit remote server creation during ordinary connect/reconnect
- implicit remote server stop semantics tied to disconnect/backgrounding

### Keep

- truthful history restore after real continuity loss
- local-mode launch behavior
- lane-level local runtime persistence such as selected thread and draft

### Exit criteria

- one coherent remote continuity architecture remains
- no shadow fallback remote mode remains
- no hidden server lifecycle policy remains

## Required Test Matrix

The final implementation is not done without this matrix.

### Lifecycle

- routine app switching does not sever the live lane
- brief post-turn lock/unlock preserves the existing completed lane when the
  process survives
- true cold-start restore falls back truthfully

### Capability

- missing `tmux` blocks supported remote mode
- missing `codex` launcher is surfaced honestly

### Server inventory and control

- explicit `Start server` starts the expected `tmux`-owned server
- explicit `Stop server` stops the expected server
- explicit `Restart server` replaces it intentionally
- discovery distinguishes:
  - server running
  - server stopped
  - server unhealthy

### Transport

- websocket reconnect works through the chosen SSH-forwarded path
- transport loss alone does not recreate the lane if the binding still exists
- reconnect to an existing server does not implicitly create a new one

### Reattach

- `thread/resume` restores the live thread after reconnect
- pending approval state survives reconnect
- pending user-input state survives reconnect
- finished turns fall back to truthful restore without pretending to be live

### Mixed cases

- transport loss plus saved-settings reconnect still applies saved settings
- server stopped plus reconnect surfaces explicit stopped-server state
- server unhealthy plus reconnect surfaces explicit unhealthy-server state
- owner loss plus reconnect falls back truthfully
- remote crash plus reconnect falls back truthfully

## Delete Schedule

This is the exact delete order.

### Delete first from primary behavior

- remote history-first reconnect after pure transport loss
- lane recreation after brief post-turn lock/unlock when the lane still exists

### Delete after replacement exists

- remote SSH stdio as primary remote owner model
- prompt-send-triggered resume as the normal reattach mechanism
- implicit remote server creation on connect/reconnect
- implicit remote server stop semantics on disconnect

### Never delete

- truthful restore after real external failure
- local draft persistence
- selected thread persistence

## Open Questions That Are Still Legitimate

These are not architecture-open questions anymore. They are execution-detail
questions.

- exact `tmux` session naming format
- exact server metadata contract for discovery
- exact websocket endpoint and forwarding shape
- exact readiness/health verification command contract
- exact UI placement for `Start server`, `Stop server`, and `Restart server`

None of these reopen the architecture choice.

## Recommended Next Work Order

This is the execution order to follow now:

1. Land Phase 0 if it is not already merged.
2. Build the transport and server-lifecycle seams from Phase 1.
3. Implement capability probing and server discovery from Phase 2.
4. Implement explicit server controls from Phase 3.
5. Connect to the existing `tmux`-owned websocket server from Phase 4.
6. Replace reconnect-time history restore with live `thread/resume` from Phase
   5.
7. Delete the old remote recovery model in Phase 6.

Must not do:

- do not skip ahead to live reattach before discovery, explicit server controls,
  and websocket transport exist
- do not mark an earlier step complete by relying on a later forbidden shortcut
- do not keep hidden fallback behavior alive just to make the next step look
  easier

This is the completed plan. Further work should now be implementation, not more
architecture drift.

For slice-level execution order, use:

- [`072_true_live_turn_continuity_slice_plan.md`](./072_true_live_turn_continuity_slice_plan.md)
