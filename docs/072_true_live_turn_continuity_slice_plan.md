# True Live-Turn Continuity Slice Plan

## Status

This document decomposes the final remote continuity execution plan into
landable phases and smaller implementation slices.

Current implementation progress as of 2026-03-24:

- complete: Phase 0
- complete: Phase 1
- complete: Phase 2 Slice 2.1
- complete: Phase 2 Slice 2.2
- complete: Phase 2 Slice 2.3
- next planned slice: Phase 2 Slice 2.4

The remaining-work view that starts from the current branch state lives in:

- [`073_true_live_turn_continuity_remaining_work_plan.md`](./073_true_live_turn_continuity_remaining_work_plan.md)

It is derived from:

- [`069_true_live_turn_continuity_contract.md`](./069_true_live_turn_continuity_contract.md)
- [`070_true_live_turn_continuity_migration_map.md`](./070_true_live_turn_continuity_migration_map.md)
- [`071_tmux_required_execution_plan.md`](./071_tmux_required_execution_plan.md)

Its purpose is practical:

- each phase has a clear goal
- each phase is broken into smaller slices
- each slice has a narrow write scope, dependencies, and exit criteria

## Slice Rules

Every slice must satisfy these rules:

- land in a buildable state
- preserve the no-self-disconnect rule during ordinary app switching
- avoid mixing ownership changes and UI redesign in the same cut
- add or update tests for the behavior it changes
- not delete old behavior before its replacement exists
- not leave remote server lifetime implicit

## Anti-Shortcut Rules

Do not mark any slice complete by doing any of the following:

- using `thread/read` as the default reconnect path and calling that continuity
- auto-starting a new server during reconnect instead of surfacing
  `server not running`
- auto-stopping the remote server on disconnect/backgrounding
- treating a prompt-send-triggered `thread/resume` as reconnect-time live
  reattach
- landing only presentation states for `Start server`, `Stop server`, or
  `Restart server` without real remote behavior
- treating a named `tmux` session as enough proof of health without real
  verification
- keeping remote SSH stdio as an undeleted hidden default while claiming later
  phases are complete
- storing local transcript truth to paper over missing upstream recovery

If a slice needs one of those to "pass," the slice is underspecified or the
phase order is wrong.

## Phase Overview

| Phase | Outcome | Slices |
| --- | --- | --- |
| 0 | Same-process transport recovery preserves the lane | 3 |
| 1 | Remote transport and ownership seams exist | 4 |
| 2 | Host capability and server discovery are real | 4 |
| 3 | Remote server lifetime becomes explicit user action | 4 |
| 4 | Pocket Relay connects to existing `tmux`-owned websocket servers | 4 |
| 5 | Reconnect becomes live reattach instead of history-first restore | 4 |
| 6 | Old remote model is deleted and release hardening is complete | 4 |

## Phase 0: Preserve Existing Lane On Pure Transport Recovery

### Goal

Remove the avoidable current regression where a brief post-turn lock/unlock
rebuilds the lane from history even though the same process and binding
survived.

### Phase must not do

- treat same-process transport recovery like cold-start restore
- widen the phase into websocket or `tmux` migration work
- claim success without proving the post-turn lane-preservation behavior

### Slice 0.1: Lock The Same-Process Recovery Contract In Tests

Purpose:

- prove the current failure mode and freeze the intended behavior

Primary files:

- `test/connection_workspace_controller_test.dart`
- `test/workspace_app_lifecycle_host_test.dart`

Keep out:

- transport abstraction work
- websocket work
- `tmux` work

Must not do:

- do not treat existing vague tests as enough
- do not rewrite recovery behavior inside this test slice

Exit criteria:

- tests prove that ordinary short background/resume does not recreate the lane
- tests prove that brief post-turn resume does not force history rebuild

### Slice 0.2: Reconnect Through The Existing Binding

Purpose:

- make pure transport recovery reuse the existing lane binding when saved
  settings did not change

Primary files:

- `lib/src/features/workspace/application/connection_workspace_controller_lifecycle.dart`

Dependencies:

- Slice 0.1

Must not do:

- do not recreate the lane by default on pure reconnect
- do not use `thread/read` as the normal answer here

Exit criteria:

- pure transport reconnect no longer defaults to lane recreation
- same-process recovery preserves in-memory detail

### Slice 0.3: Verify No Regression In Lifecycle Hosts

Purpose:

- make sure the app lifecycle host and workspace ownership still preserve the
  live lane correctly after the reconnect policy change

Primary files:

- `test/workspace_app_lifecycle_host_test.dart`
- `test/connection_workspace_controller_test.dart`

Dependencies:

- Slice 0.2

Must not do:

- do not skip lifecycle-host verification because controller tests pass
- do not widen this validation slice into transport seam work

Exit criteria:

- focused lifecycle tests pass
- Phase 0 behavior is safe to carry into the larger transport rewrite

## Phase 1: Introduce The Ownership And Transport Seams

### Goal

Stop the remote path from being hard-wired to SSH-launched stdio ownership.

### Phase must not do

- keep spawned-process ownership hidden behind renamed types
- smuggle remote server lifecycle policy into the generic transport seam
- break the current path before temporary compatibility exists

### Slice 1.1: Define A Transport-Shaped Connection Boundary

Purpose:

- replace the current spawned-process assumption with a transport interface the
  rest of the app can depend on

Primary files:

- `lib/src/features/chat/transport/app_server/codex_app_server_connection.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_models.dart`

Keep out:

- real websocket connection logic
- server discovery/control

Must not do:

- do not let the new boundary still require `stdin` / `stdout` semantics
- do not encode lifecycle policy into this transport interface

Exit criteria:

- the connection layer can host more than one transport shape
- current stdio behavior still works through the new abstraction

### Slice 1.2: Adapt Current Remote SSH Stdio To The New Boundary

Purpose:

- keep the current remote path working temporarily while removing it as the
  only ownership model

Primary files:

- `lib/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_connection_lifecycle.dart`

Dependencies:

- Slice 1.1

Must not do:

- do not preserve stdio as the long-term primary remote path
- do not let adapter code leak ownership assumptions upward

Exit criteria:

- current stdio path still passes through the new transport seam

### Slice 1.3: Separate SSH Bootstrap From Remote Server Discovery/Control

Purpose:

- prevent future `tmux` inventory/start/stop logic from being hidden inside
  generic transport code

Primary files:

- `lib/src/features/chat/transport/app_server/...`

Add:

- discovery/control seam types only, without full behavior yet

Dependencies:

- Slice 1.1

Must not do:

- do not hide discovery/start/stop concerns inside generic SSH helpers
- do not auto-start servers as part of seam extraction

Exit criteria:

- repo has a dedicated ownership seam for remote server lifecycle work

### Slice 1.4: Re-baseline Transport-Layer Tests

Purpose:

- prove the seam extraction did not change current behavior unintentionally

Primary files:

- `test/codex_app_server_client_test.dart`
- transport-layer tests near `app_server/`

Dependencies:

- Slices 1.2 and 1.3

Must not do:

- do not treat compile success as enough verification
- do not skip parity tests for the temporary stdio adapter

Exit criteria:

- transport seam refactor is verified before `tmux` and websocket work begins

## Phase 2: Implement Capability Probe And Server Discovery

### Goal

Make the host prerequisite and running-server inventory real.

### Phase must not do

- collapse unsupported host, stopped server, and unhealthy server into one
  generic state
- infer remote readiness from saved config alone
- use loose scanning when deterministic discovery is required

### Slice 2.1: Define Capability And Server Inventory Models

Purpose:

- create the runtime models for:
  - missing `tmux`
  - missing `codex`
  - server not running
  - server unhealthy
  - server running

Primary files:

- `lib/src/features/workspace/domain/...`
- `lib/src/features/connection_settings/domain/...`

Must not do:

- do not store capability results as saved profile truth
- do not erase the distinction between host capability and server runtime state

Exit criteria:

- the app has a precise runtime vocabulary for host and server state

### Slice 2.2: Implement Host Capability Probe

Purpose:

- ask the remote host whether it can support the continuity path at all

Primary files:

- `lib/src/features/chat/transport/app_server/...`
- `lib/src/features/connection_settings/application/...`

Dependencies:

- Slice 2.1

Must not do:

- do not infer `tmux` or `codex` presence without real host commands
- do not silently downgrade when the host fails the probe

Exit criteria:

- `tmux` and configured `codex` availability are checked explicitly

### Slice 2.3: Implement Server Discovery And Health Verification

Purpose:

- deterministically find Pocket Relay-managed servers and classify whether they
  are healthy enough to attach to

Primary files:

- remote discovery/control seam introduced in Phase 1

Dependencies:

- Slice 2.1

Must not do:

- do not treat `tmux` naming alone as health verification
- do not create a server in order to discover whether one exists

Exit criteria:

- Pocket Relay can tell whether a server is:
  - not running
  - unhealthy
  - running and connectable

### Slice 2.4: Surface Discovery State In Workspace And Settings

Purpose:

- make host/server state visible to the app without starting lifecycle control
  yet

Primary files:

- `lib/src/features/workspace/application/...`
- `lib/src/features/connection_settings/application/...`

Dependencies:

- Slices 2.2 and 2.3

Must not do:

- do not surface fake lifecycle controls before discovery truth exists
- do not blur `host unsupported` with `server stopped`

Exit criteria:

- UI/runtime can distinguish unsupported host from stopped or unhealthy server

## Phase 3: Implement Explicit Remote Server Controls

### Goal

Make remote server lifetime a deliberate user action instead of a connect-side
effect.

### Phase must not do

- leave server lifetime as a hidden reconnect side effect
- land only button/UI affordances without real remote behavior
- treat disconnect as an implicit stop signal

### Slice 3.1: Define Start/Stop/Restart Application Actions

Purpose:

- add explicit application-level commands for remote server ownership

Primary files:

- `lib/src/features/workspace/application/...`
- `lib/src/features/workspace/domain/...`

Dependencies:

- Phase 2 complete

Must not do:

- do not hide start/stop/restart behind generic reconnect actions
- do not place ownership decisions in the transport layer

Exit criteria:

- the application layer can request explicit server start, stop, and restart

### Slice 3.2: Implement `Start server`

Purpose:

- intentionally create the Pocket Relay-managed `tmux` owner and launch the
  websocket app-server

Primary files:

- remote discovery/control helper
- SSH control/bootstrap files under `app_server/`

Dependencies:

- Slice 3.1

Must not do:

- do not auto-run this slice on lane open or reconnect
- do not report success before health verification and discovery agree

Exit criteria:

- user action can start a healthy server intentionally
- discovery sees the newly started server afterward

### Slice 3.3: Implement `Stop server` And `Restart server`

Purpose:

- close the loop on explicit user-owned lifecycle

Primary files:

- remote discovery/control helper
- workspace application layer

Dependencies:

- Slice 3.2

Must not do:

- do not map ordinary disconnect to `Stop server`
- do not treat restart as a silent recovery fallback

Exit criteria:

- stop removes the running server intentionally
- restart replaces it intentionally and discoverably

### Slice 3.4: Add Explicit UI For Server Controls And Server State

Purpose:

- expose server ownership truthfully in the product surface

Primary files:

- `lib/src/features/workspace/presentation/...`
- `lib/src/features/connection_settings/presentation/...`

Dependencies:

- Slices 3.1 to 3.3

Must not do:

- do not ship UI-only controls
- do not collapse stopped, unhealthy, and unsupported into generic reconnect
  copy

Exit criteria:

- user can see and trigger `Start server`, `Stop server`, and `Restart server`
- UI distinguishes:
  - prerequisite missing
  - server stopped
  - server unhealthy
  - server running

## Phase 4: Connect To The Existing `tmux`-Owned Websocket Server

### Goal

Reach the already-running server without recreating ownership on every connect.

### Phase must not do

- auto-start a replacement server when attach fails
- keep SSH stdio as a hidden default remote path
- let transport establishment decide server lifetime

### Slice 4.1: Implement Websocket Transport

Purpose:

- add the reconnectable transport implementation itself

Primary files:

- `lib/src/features/chat/transport/app_server/...`

Dependencies:

- Phase 1 complete

Must not do:

- do not couple websocket transport to discovery or server control logic
- do not fake reconnectability by tunneling current stdio semantics unchanged

Exit criteria:

- Pocket Relay can speak app-server JSON-RPC over websocket

### Slice 4.2: Implement SSH Forwarding To The Discovered Endpoint

Purpose:

- secure websocket connectivity to the discovered remote server

Primary files:

- SSH/bootstrap and transport files under `app_server/`

Dependencies:

- Slice 4.1
- Phase 2 discovery in place

Must not do:

- do not hardcode endpoint assumptions outside discovery metadata
- do not expose an insecure direct remote listener as the default path

Exit criteria:

- discovered server endpoints can be reached through the chosen forwarding path

### Slice 4.3: Switch Remote Connect Flow To "Discover Then Connect"

Purpose:

- make remote connect attach to an existing server instead of launching SSH
  stdio as the default

Primary files:

- `lib/src/features/workspace/application/...`
- `lib/src/features/chat/transport/app_server/...`

Dependencies:

- Slices 4.1 and 4.2
- Phase 3 server controls

Must not do:

- do not silently create a server during ordinary attach
- do not keep stdio launch as a hidden fallback default

Exit criteria:

- remote connect no longer silently creates ownership during ordinary attach

### Slice 4.4: Handle Server-Not-Running And Server-Unhealthy States Honestly

Purpose:

- make remote attach failure truthful without auto-start

Primary files:

- workspace/application and presentation layers

Dependencies:

- Slice 4.3

Must not do:

- do not auto-start the server from the error path
- do not disguise stopped or unhealthy server states as generic disconnects

Exit criteria:

- stopped or unhealthy server states are surfaced clearly
- no implicit server start is triggered by ordinary reconnect

## Phase 5: Implement Real Live Reattach

### Goal

Turn reconnect into live thread re-entry instead of history-first recovery.

### Phase must not do

- call `thread/read` first and label that continuity
- delay live thread attachment until the next user prompt
- synthesize pending state locally and call that successful reattach

### Slice 5.1: Expose Reconnect-Time `thread/resume` In The Client Layer

Purpose:

- make reconnect-time resume a first-class app-server request path

Primary files:

- `lib/src/features/chat/transport/app_server/codex_app_server_request_api_session_thread.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_client.dart`

Dependencies:

- Phase 4 complete

Must not do:

- do not leave reconnect-time `thread/resume` hidden behind prompt-send flow
- do not treat `thread/start` or lazy session start as equivalent

Exit criteria:

- the client layer can explicitly issue reconnect-time `thread/resume`

### Slice 5.2: Make Recovery Attempt Live Reattach First

Purpose:

- move the workspace/chat recovery path away from history-first restore

Primary files:

- `lib/src/features/chat/lane/application/chat_session_controller_recovery.dart`
- `lib/src/features/workspace/application/connection_workspace_controller_lifecycle.dart`

Dependencies:

- Slice 5.1

Must not do:

- do not recreate the lane before attempting live reattach
- do not use history restore as the default fallback in this slice

Exit criteria:

- reconnect path attempts live reattach before `thread/read`

### Slice 5.3: Restore Pending Approval And User-Input State

Purpose:

- make reconnect feel like the same live run, not just a reopened thread

Primary files:

- chat session recovery and runtime mapping layers

Dependencies:

- Slice 5.2

Must not do:

- do not invent pending approval or input state locally
- do not treat missing replay from upstream as successful continuity

Exit criteria:

- pending approval/input state survives reconnect when upstream still has it

### Slice 5.4: Restrict `thread/read` To True Fallback Only

Purpose:

- make history restore the fallback path instead of the default

Primary files:

- `lib/src/features/chat/lane/application/chat_session_controller_history.dart`
- `lib/src/features/chat/transcript/...`

Dependencies:

- Slices 5.2 and 5.3

Must not do:

- do not leave `thread/read` as the normal reconnect path
- do not use app-local transcript storage as fallback truth

Exit criteria:

- history restore only happens when continuity is unavailable or the turn is
  already finished

## Phase 6: Remove The Old Remote Model And Harden Release

### Goal

Delete the wrong default architecture and prove the final path is shippable.

### Phase must not do

- leave any hidden remote SSH stdio ownership path reachable
- keep ambiguous legacy reconnect states for convenience
- declare completion before the delete list and verification matrix are both
  satisfied

### Slice 6.1: Remove Remote SSH Stdio As The Primary Remote Owner Model

Purpose:

- stop carrying the wrong remote ownership model as the default

Primary files:

- transport/bootstrap files under `app_server/`

Dependencies:

- Phase 4 complete

Must not do:

- do not leave shadow stdio ownership branches reachable in remote mode
- do not claim this slice is done while the old remote default still exists

Exit criteria:

- remote mode no longer defaults to SSH-launched stdio ownership

### Slice 6.2: Remove Prompt-Send Resume As The Normal Reattach Path

Purpose:

- finish deleting the lazy resume behavior after live reattach exists

Primary files:

- `lib/src/features/chat/lane/application/chat_session_controller_history.dart`
- `lib/src/features/chat/lane/application/chat_session_controller.dart`

Dependencies:

- Phase 5 complete

Must not do:

- do not keep lazy resume as a silent fallback once live reattach exists
- do not require a new user prompt to recover a live thread

Exit criteria:

- reconnect no longer waits for the next user prompt to make the thread live

### Slice 6.3: Remove Legacy Ambiguous Recovery States

Purpose:

- collapse the old reconnect/rebuild ambiguity into the new precise server and
  continuity states

Primary files:

- workspace presentation/application layers

Dependencies:

- Phases 3 to 5 complete

Must not do:

- do not leave generic reconnect banners hiding explicit server states
- do not preserve ambiguous UI states just because they are already wired

Exit criteria:

- UI/runtime no longer blur together:
  - host unsupported
  - server stopped
  - server unhealthy
  - live reattach
  - truthful fallback restore

### Slice 6.4: Release Hardening And Matrix Verification

Purpose:

- prove the final path is trustworthy enough to ship

Verification matrix:

- ordinary app switching
- brief post-turn lock/unlock
- active-turn continuity through disconnect/reconnect
- server stopped
- server unhealthy
- missing `tmux`
- cold-start truthful fallback
- pending approval/input continuity
- network drop and reconnect

Dependencies:

- all prior phases

Must not do:

- do not declare done from simulator or happy-path verification alone
- do not skip stopped-server, unhealthy-server, or fallback-truth cases

Exit criteria:

- final release claim matches tested behavior

## Recommended Landing Order

The intended landing order is:

1. Phase 0 completely
2. Phase 1 completely
3. Phase 2 completely
4. Phase 3 slices 3.1 to 3.4
5. Phase 4 slices 4.1 to 4.4
6. Phase 5 slices 5.1 to 5.4
7. Phase 6 slices 6.1 to 6.4

Do not skip ahead to live reattach before:

- discovery exists
- explicit server controls exist
- websocket transport exists

Must not do:

- do not treat later-phase shortcuts as a substitute for unfinished earlier
  slices
- do not claim a phase is complete while its per-slice "Must not do" rules are
  still being violated
- do not reorder slices in a way that makes server lifetime implicit again

## Good First Slice

If implementation starts immediately on this branch, the correct first slice is:

- Slice 0.1, then Slice 0.2

Reason:

- it fixes a current user-visible regression
- it is compatible with the final architecture
- it reduces churn before the transport rewrite starts
