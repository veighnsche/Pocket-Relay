# 074 Phase 6 Cleanup Source Audit

## Purpose

This document turns the Phase 6 delete plan into a source-backed cleanup audit.

It answers four questions:

1. what is already replaced and no longer the primary production path
2. what old behavior is still structurally reachable and should be deleted or
   narrowed
3. what looks old but must remain because the websocket continuity path still
   depends on it
4. which tests, fixtures, and downstream preview surfaces must be cleaned up
   together with the production code

This document builds on:

- [`069_true_live_turn_continuity_contract.md`](./069_true_live_turn_continuity_contract.md)
- [`070_true_live_turn_continuity_migration_map.md`](./070_true_live_turn_continuity_migration_map.md)
- [`071_tmux_required_execution_plan.md`](./071_tmux_required_execution_plan.md)
- [`072_true_live_turn_continuity_slice_plan.md`](./072_true_live_turn_continuity_slice_plan.md)
- [`073_true_live_turn_continuity_remaining_work_plan.md`](./073_true_live_turn_continuity_remaining_work_plan.md)

## Key Distinction

Phase 6 is not "delete SSH".

Phase 6 is:

- delete SSH-launched remote `stdio://` app-server ownership
- keep SSH bootstrap where the websocket continuity path still needs it

This distinction matters because the new remote continuity path still uses SSH
for:

- host-key verification
- SSH authentication
- local port forwarding to the remote websocket app-server
- explicit remote owner inspect/start/stop/restart commands

So the real delete target is the old remote owner model, not SSH itself.

## What Is Already Replaced

These areas already follow the intended architecture and should be treated as
the baseline, not as cleanup targets.

### Workspace bootstrap no longer uses remote SSH stdio as the primary path

`lib/src/app/pocket_relay_dependencies.dart`

- remote lane bindings are created with
  `buildConnectionScopedCodexAppServerTransportOpener(...)`
- the owner identity is the saved `connectionId`
- remote lane creation now depends on remote owner inspection plus websocket
  attach, not on launching a fresh remote `stdio://` child

`lib/src/features/chat/transport/app_server/codex_app_server_connection_scoped_transport.dart`

- local mode still opens a local `stdio://` process
- remote mode now:
  - inspects the expected managed owner
  - requires a connectable websocket endpoint
  - opens an SSH-forwarded websocket transport
- this file already enforces that a stopped or unhealthy managed owner is not a
  valid remote attach target

### Workspace reconnect no longer uses history-first reconnect

`lib/src/features/workspace/application/connection_workspace_controller_lifecycle.dart`

- reconnect first restores transport
- then calls `binding.sessionController.reattachConversation(threadId)`
- only falls back to `selectConversationForResume(threadId)` when live reattach
  yields no visible live state or throws

This means the old "wait for the next prompt before the thread becomes live
again" path is already no longer the workspace reconnect primary path.

### Remote server lifetime is already explicit

`lib/src/features/workspace/application/connection_workspace_controller_remote_owner.dart`

- `startRemoteServer`
- `stopRemoteServer`
- `restartRemoteServer`

`lib/src/features/connection_settings/application/connection_settings_presenter_sections.dart`

- settings already surface explicit remote server status plus explicit
  start/stop/restart controls

This means implicit reconnect-time server creation/destruction is already
replaced in the primary workspace/settings flow.

## Cleanup Finding 1: Saved Connections Still Uses The Old Dormant-Only Model

The branch now has connection-owned remote server state, but the main saved
inventory surface still follows the old "saved means dormant" model.

### Files

`lib/src/features/workspace/presentation/workspace_dormant_roster_content.dart`

- builds the saved page from `workspaceState.dormantConnectionIds`
- this filters out any saved connection that already has an open lane

`lib/src/features/workspace/domain/connection_workspace_state.dart`

- `dormantConnectionIds` is still the inventory source for the saved page

`lib/src/features/workspace/presentation/workspace_desktop_shell_sidebar_expanded.dart`

- keeps `Open lanes` as one section
- summarizes `Saved` using `state.dormantConnectionIds`

`lib/src/features/workspace/presentation/workspace_mobile_shell.dart`

- still hosts a dedicated saved-connections page, but that page's contents are
  currently dormant-only because of the roster filter above

### Why this is now wrong

The connection id is now the durable owner identity for:

- remote server discovery
- remote server status
- explicit `Start server` / `Stop server` / `Restart server`

That means the saved connection itself is the owned object. Hiding it from the
saved inventory when it becomes active pushes connection-owned truth onto a
lane-only surface.

### Cleanup conclusion

Replace:

- the dormant-only `Saved connections` model

Keep, but narrow:

- `Open lanes` on desktop, if it remains, as quick-switch UI only

## Cleanup Finding 2: Remote SSH Stdio Ownership Still Exists Structurally

The primary workspace path is fixed, but the old remote SSH stdio owner model is
still structurally present in generic transport defaults.

### Files

`lib/src/features/chat/transport/app_server/codex_app_server_client.dart`

- the default constructor still falls back to `openCodexAppServerTransport`
  whenever no explicit `transportOpener` is supplied

`lib/src/features/chat/transport/app_server/codex_app_server_process_launcher.dart`

- `openCodexAppServerTransport(...)` still chooses:
  - local process launcher for local mode
  - `openSshCodexAppServerProcess(...)` for remote mode

`lib/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart`

- still builds and launches:
  `codex app-server --listen stdio://`
- still emits the old remote process start / remote launch failure events

### Why this still matters

Even though the workspace bootstrap no longer uses this path, the generic client
default still means "remote mode over SSH stdio" continues to exist as a
framework-level fallback.

That is exactly the kind of shadow fallback Phase 6 says must be removed.

### Most important live example

`lib/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart`

- when `profile.isRemote && ownerId != null`, the repository correctly uses the
  connection-scoped websocket owner path
- otherwise it falls back to `CodexAppServerClient()`

That means the repository still structurally allows a remote caller with no
`ownerId` to reach the old remote SSH stdio path.

### Cleanup conclusion

Delete or narrow:

- the generic remote branch in `openCodexAppServerTransport(...)`
- the implicit remote default in `CodexAppServerClient()`
- the remote-without-owner fallback in
  `CodexAppServerConversationHistoryRepository`

Keep:

- local `stdio://` launch behavior

## Cleanup Finding 3: Prompt-Send Resume Still Exists, But It Is No Longer The Normal Reattach Path

`lib/src/features/chat/lane/application/chat_session_controller_history.dart`

- `_ensureChatSessionAppServerThread(...)` still does:
  `startSession(resumeThreadId: activeThreadId)`

This is still real code, but it is important to classify it correctly.

### What it is no longer doing

It is no longer the workspace reconnect-time primary reattach path.

That work has already moved into:

`lib/src/features/chat/lane/application/chat_session_controller_recovery.dart`

- `reattachConversation(threadId)` calls `appServerClient.resumeThread(...)`

and:

`lib/src/features/workspace/application/connection_workspace_controller_lifecycle.dart`

- reconnect recovery calls `reattachConversation(...)` before truthful fallback

### What it is still doing

It is still the explicit "continue this already-selected thread on the next
outbound send" mechanism after transcript selection / restore.

That behavior is still covered by tests such as:

- `test/connection_workspace_desktop_shell_test.dart`
- `test/chat_session_controller_test.dart`

Those tests prove a still-valid behavior:

- user selects or restores a saved conversation
- next prompt continues that thread

### Cleanup conclusion

Do not blindly delete all `resumeThreadId` support.

Delete or narrow:

- any code comments, docs, tests, or production flows that still treat this
  prompt-send resume path as the normal reconnect-time continuity answer

Keep:

- explicit continue-thread behavior after intentional transcript selection /
  restore

## Cleanup Finding 4: The Remote Launch Failure Event Stack Is Now Legacy-Only

The old remote SSH stdio model has a full event, runtime, transcript, and UI
stack dedicated to "SSH remote launch failed" and "remote process started".

### Source chain

Transport events:

- `lib/src/features/chat/transport/app_server/codex_app_server_models.dart`
  - `CodexAppServerSshRemoteLaunchFailedEvent`
  - `CodexAppServerSshRemoteProcessStartedEvent`

Emitter:

- `lib/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart`

Runtime mapping:

- `lib/src/features/chat/runtime/application/runtime_event_mapper_transport_mapper.dart`

Transcript/runtime blocks:

- `lib/src/features/chat/transcript/domain/codex_runtime_event_events_status.dart`
- `lib/src/features/chat/transcript/domain/codex_ui_block_ssh.dart`
- `lib/src/features/chat/transcript/application/transcript_policy.dart`
- `lib/src/features/chat/transcript/application/transcript_reducer_session.dart`
- `lib/src/features/chat/transcript/application/transcript_reducer_workspace.dart`

Presentation:

- `lib/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh/ssh_remote_launch_failed_surface.dart`
- `lib/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh/ssh_surface_host.dart`

Tests and preview downstream:

- `test/codex_runtime_event_mapper_test.dart`
- `test/codex_session_reducer_test.dart`
- `test/codex_ui_block_surface_test.dart`
- `test/chat_screen_app_server_test.dart`
- `test/codex_app_server_ssh_process_test.dart`
- `lib/widgetbook/support/widgetbook_fixtures.dart`
- `lib/widgetbook/story_catalog.dart`

### Why this is now legacy-only

The websocket continuity path still authenticates over SSH, but it does not
launch the app-server over SSH stdio as the lane transport.

So:

- SSH connect/auth/host-key failures remain real
- SSH remote app-server launch / remote process started events are tied to the
  deleted owner model

### Additional state that appears legacy now

`lib/src/features/workspace/domain/connection_workspace_state.dart`

- `ConnectionWorkspaceTransportLossReason.sshRemoteLaunchFailed`

`lib/src/features/workspace/application/connection_workspace_controller.dart`

- still maps `CodexAppServerSshRemoteLaunchFailedEvent` into that loss reason

That looks dead once the SSH remote app-server launch path is removed.

### Cleanup conclusion

Delete together:

- the remote launch failure event types
- the runtime mapper branches for them
- the transcript blocks and surfaces that only render them
- the workspace transport-loss reason that only exists to classify them
- the tests and Widgetbook fixtures/stories that only exist for those events

## Cleanup Finding 5: SSH Bootstrap Failure Surfaces Must Remain

These can look legacy at first glance, but they are still required by the
websocket continuity path.

### Why they stay

`lib/src/features/chat/transport/app_server/codex_app_server_ssh_forward.dart`

- still uses `connectAuthenticatedSshBootstrapClient(...)`
- still depends on:
  - host-key verification
  - SSH authentication
  - opening a local port forward to the remote websocket server

That means the following remain valid:

- `CodexAppServerUnpinnedHostKeyEvent`
- `CodexAppServerSshConnectFailedEvent`
- `CodexAppServerSshHostKeyMismatchEvent`
- `CodexAppServerSshAuthenticationFailedEvent`
- `CodexAppServerSshAuthenticatedEvent`
- SSH port-forward start/failure events

These are still truthful transport/bootstrap states even after remote SSH stdio
ownership is removed.

### Cleanup conclusion

Keep:

- SSH bootstrap and port-forward failure events
- transcript/runtime surfaces for host-key, auth, and connect failures

Delete only:

- the remote-launch and remote-process-start event family

## Cleanup Finding 6: The Recovery State Model Is More Precise Than The UI Surface

The runtime state model is already more explicit than the current end-user
surface.

### Source of precise runtime state

`lib/src/features/workspace/domain/connection_workspace_state.dart`

- `ConnectionWorkspaceTransportRecoveryPhase`
- `ConnectionWorkspaceLiveReattachPhase`
  - `transportLost`
  - `reconnecting`
  - `ownerMissing`
  - `ownerUnhealthy`
  - `liveReattached`
  - `fallbackRestore`
- `ConnectionWorkspaceRecoveryOutcome`
  - `transportRestored`
  - `transportUnavailable`
  - `liveReattached`
  - `conversationRestored`
  - `conversationUnavailable`
  - `conversationRestoreFailed`

### Current UI use is still narrower

`lib/src/features/workspace/presentation/workspace_live_lane_surface.dart`

- the lane notice only reads:
  - `transportRecoveryPhase`
  - `remoteRuntime.server.status`
- it does not render `liveReattachPhase`
- it does not render `lastRecoveryOutcome`

### Why this matters for Phase 6.3

The runtime layer can already distinguish:

- owner missing
- owner unhealthy
- live reattached
- truthful fallback restore

But the visible lane recovery surface is still mostly organized around a generic
transport notice plus remote runtime.

This is much better than the original history-first reconnect behavior, but it
still leaves a mismatch:

- precise runtime vocabulary exists
- the primary lane UI does not fully consume it

### Cleanup conclusion

Phase 6.3 needs one of these outcomes:

1. make the UI consume the explicit recovery vocabulary honestly, or
2. delete any phase/outcome state that is only internal bookkeeping and not part
   of a justified app-owned runtime contract

What Phase 6 must not do is keep both:

- rich internal recovery taxonomy
- generic user-facing reconnect language that blurs it back together

## Cleanup Finding 7: Some `stdio://` References Must Stay

Not every `stdio://` string is Phase 6 cleanup.

### Keep

`lib/src/features/chat/transport/app_server/codex_app_server_local_process.dart`

- local mode still launches:
  `codex app-server --listen stdio://`

That remains correct.

Related local-mode and tooling tests that should remain:

- `test/codex_app_server_local_process_test.dart`
- `test/capture_live_thread_read_fixture_test.dart`

### Delete or narrow only when tied to remote SSH ownership

Examples that are Phase 6 cleanup:

- `test/codex_app_server_ssh_process_test.dart`
- the remote branches in
  `test/codex_app_server_process_launcher_test.dart`

So the audit rule is:

- local stdio is valid
- remote SSH stdio ownership is not

## Cleanup Finding 8: The Current Branch Still Needs A "Delete Or Narrow" Pass Across Tests

The production behavior has moved faster than the test/preview/support surface.

### Tests and support likely to delete with remote SSH stdio ownership

- `test/codex_app_server_ssh_process_test.dart`
- remote branches in `test/codex_app_server_process_launcher_test.dart`
- remote-launch event assertions in:
  - `test/codex_runtime_event_mapper_test.dart`
  - `test/codex_session_reducer_test.dart`
  - `test/codex_ui_block_surface_test.dart`
  - `test/chat_screen_app_server_test.dart`
- Widgetbook fixtures/stories for SSH remote launch failure

### Tests to narrow instead of delete

Tests around `resumeThreadId` split into two groups:

Keep:

- tests that prove explicit continue-thread behavior after transcript restore or
  user-selected conversation resume

Delete or rewrite:

- tests that still frame prompt-send resume as the normal reconnect-time
  continuity mechanism

### Tests to keep

- websocket transport and SSH forward tests
- remote owner probe/inspect/start/stop/restart tests
- workspace reconnect + live reattach + truthful fallback tests
- local app-server process tests

## Recommended Phase 6 Delete Order

### 1. Delete the structural remote stdio fallback first

Primary targets:

- `codex_app_server_client.dart`
- `codex_app_server_process_launcher.dart`
- `codex_workspace_conversation_history_repository.dart`

Reason:

- this removes the hidden remote default before cleanup work starts deleting the
  old event/UI/test stack

### 2. Delete the remote-launch event family

Primary targets:

- `codex_app_server_models.dart`
- `runtime_event_mapper_transport_mapper.dart`
- transcript block/surface files
- workspace transport-loss reason if no longer emitted

Reason:

- once the old remote owner path is gone, these become dead product surface
  area

### 3. Delete or narrow the stale tests and Widgetbook stories

Reason:

- downstream fixtures should track app truth, not preserve removed runtime
  narratives

### 4. Resolve the recovery-surface ambiguity

Primary targets:

- `connection_workspace_state.dart`
- `connection_workspace_copy.dart`
- `workspace_live_lane_surface.dart`

### 5. Replace the dormant-only saved inventory model

Primary targets:

- `workspace_dormant_roster_content.dart`
- `workspace_desktop_shell_sidebar_expanded.dart`
- related saved-connections tests

Reason:

- connection-owned server truth should remain visible from the saved inventory
  even when a lane is already open

## Final Audit Summary

### Delete

- remote SSH stdio ownership as a generic fallback
- remote launch / remote process started event family
- workspace `sshRemoteLaunchFailed` transport-loss classification if no longer
  emitted
- downstream tests/stories/fixtures that only exist for the deleted remote
  owner model
- the dormant-only `Saved connections` inventory model

### Narrow

- prompt-send `resumeThreadId` behavior:
  keep it for explicit continue-thread flows, but stop treating it as normal
  reconnect-time continuity
- conversation history repository:
  stop allowing remote fallback without a managed owner identity
- recovery UI/runtime vocabulary:
  either surface the precise states or remove unused internal distinctions
- `Open lanes`:
  keep only as quick-switch UI if it remains

### Keep

- local `stdio://` launch behavior
- SSH bootstrap, host-key, auth, and port-forward failure surfaces
- truthful `thread/read` fallback after real continuity loss
- explicit user-owned remote server start/stop/restart
- `Saved connections` as the canonical inventory of all saved connections
