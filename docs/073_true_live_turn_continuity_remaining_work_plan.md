# True Live-Turn Continuity Remaining Work Plan

## Purpose

This document starts from the current implementation state on
`feat/true-live-turn-continuity` and lists only the work that remains.

It does not replace the full architecture docs. It is the execution checklist
for the unfinished work after:

- Phase 0 completed
- Phase 1 completed
- Phase 2 Slice 2.1 completed
- Phase 2 Slice 2.2 completed
- Phase 2 Slice 2.3 completed

It is derived from:

- [`069_true_live_turn_continuity_contract.md`](./069_true_live_turn_continuity_contract.md)
- [`070_true_live_turn_continuity_migration_map.md`](./070_true_live_turn_continuity_migration_map.md)
- [`071_tmux_required_execution_plan.md`](./071_tmux_required_execution_plan.md)
- [`072_true_live_turn_continuity_slice_plan.md`](./072_true_live_turn_continuity_slice_plan.md)

## Current Baseline

The branch already has these foundations:

- same-process transport recovery preserves an existing live lane instead of
  rebuilding it from history
- the app-server connection boundary is transport-shaped instead of
  spawned-process-shaped
- remote owner responsibilities have a dedicated seam instead of being hidden
  in generic SSH helpers
- host capability runtime state exists and distinguishes supported,
  unsupported, and probe-failed host states
- host capability probing is real and explicitly checks `tmux` and configured
  `codex`
- owner inspection is real and distinguishes:
  - server not running
  - server unhealthy
  - server running and connectable

The branch does not have these yet:

- owner discovery state wired into workspace/runtime surfaces with real owner
  ids
- explicit user-owned `Start server`, `Stop server`, and `Restart server`
- websocket transport and SSH forwarding to an already-running server
- reconnect-time `thread/resume` live reattach
- deletion of the old SSH stdio remote model

## Remaining Work Overview

| Remaining phase | Outcome | Remaining slices |
| --- | --- | --- |
| 2 | Discovery truth is visible to the app | 1 |
| 3 | Remote server lifetime becomes explicit user action | 4 |
| 4 | Pocket Relay connects to existing `tmux`-owned websocket servers | 4 |
| 5 | Reconnect becomes live reattach | 4 |
| 6 | Old remote model is deleted and hardened | 4 |

## Global Rules For The Remaining Work

Every remaining phase must continue to obey these constraints:

- do not auto-start a remote server during reconnect
- do not auto-stop a remote server on disconnect, backgrounding, or short app
  switching
- do not silently replace a missing or unhealthy owner with a new one
- do not use `thread/read` as the default reconnect answer
- do not treat a named `tmux` session as enough proof of health
- do not keep SSH stdio as a hidden remote default while claiming websocket
  phases are complete
- do not store local transcript history as truth

If a remaining slice requires one of those shortcuts to pass, the slice is
wrong or the phase order is wrong.

## Remaining Phase 2

### Slice 2.4: Surface Discovery State In Workspace And Settings

Goal:

- make real discovery state visible to the app and settings flow using the
  actual connection/owner identity

Required work:

- thread a real owner id into the settings/runtime probe path
- make workspace/runtime state carry the inspected server state for saved
  remote connections
- surface the distinction between:
  - host unsupported
  - host probe failed
  - server not running
  - server unhealthy
  - server running

Primary files:

- `lib/src/features/workspace/application/...`
- `lib/src/features/workspace/domain/...`
- `lib/src/features/connection_settings/application/...`
- `lib/src/features/connection_settings/presentation/...`

Must not do:

- do not add `Start server` / `Stop server` UI yet
- do not invent placeholder owner ids in widget code
- do not blur `probe failed` with `unsupported host`
- do not keep server state local to the settings sheet only

Exit criteria:

- saved remote connections can surface truthful owner/server state
- settings and workspace layers agree on the same runtime vocabulary
- a known owner id can drive real owner inspection

## Remaining Phase 3

### Purpose

Make remote server lifetime explicit user action instead of reconnect policy.

### Slice 3.1: Define Explicit Server Lifecycle Actions

Goal:

- add application-level actions for `Start server`, `Stop server`, and
  `Restart server`

Required work:

- introduce explicit workspace/application actions
- define success/failure runtime transitions
- keep lifecycle ownership out of transport-layer abstractions

Must not do:

- do not bury server lifecycle under generic reconnect or refresh actions
- do not let settings widgets own the lifecycle decisions

Exit criteria:

- app layer can intentionally request start, stop, and restart

### Slice 3.2: Implement `Start server`

Goal:

- intentionally create the expected `tmux` owner and launch a websocket
  app-server

Required work:

- define the exact `tmux` session naming contract used for start/inspect
- define the initial websocket endpoint contract
- launch the server only on explicit user action
- verify the result through the same discovery/health path from Phase 2

Must not do:

- do not auto-run start on connect, reconnect, or lane open
- do not claim success without discovery seeing the same healthy owner

Exit criteria:

- explicit start creates a healthy owner
- later discovery sees the same owner as running and connectable

### Slice 3.3: Implement `Stop server` And `Restart server`

Goal:

- complete the explicit user-owned lifecycle loop

Required work:

- stop tears down only the expected owner
- restart is explicit replacement of that same owner id
- runtime state updates truthfully through stop/restart transitions

Must not do:

- do not treat reconnect failure as permission to restart
- do not stop on disconnect/backgrounding

Exit criteria:

- user can intentionally stop or restart the owner
- runtime state reflects the action honestly afterward

### Slice 3.4: Wire Real UI Controls

Goal:

- surface explicit lifecycle controls only after the actions are real

Required work:

- expose truthful action affordances in the appropriate workspace/settings
  surfaces
- disable or hide actions when prerequisite/runtime state does not allow them

Must not do:

- do not land UI-only buttons ahead of real behavior
- do not present lifecycle controls on unsupported hosts as if they could work

Exit criteria:

- lifecycle controls are real, not placeholders
- reconnect is no longer the hidden owner of server lifetime

## Remaining Phase 4

### Purpose

Connect Pocket Relay to an already-running user-owned websocket server.

### Slice 4.1: Add Websocket Transport Implementation

Goal:

- implement the actual app-server websocket transport under the Phase 1 seam

Required work:

- add websocket transport open/close/message handling
- keep initialization and event flow aligned with the existing app-server
  contract

Must not do:

- do not let websocket transport decide server lifecycle
- do not keep process-shaped assumptions in the transport code

Exit criteria:

- websocket transport can host the same request/event model as stdio

### Slice 4.2: Add SSH Forwarding For Existing Servers

Goal:

- let Pocket Relay reach a remote websocket server securely without recreating
  ownership

Required work:

- implement SSH port-forward or equivalent secure reachability
- bind the forward to the inspected owner endpoint
- keep failure reporting distinct from owner-health reporting

Must not do:

- do not create a new server when forwarding fails
- do not infer owner health from forward success alone

Exit criteria:

- Pocket Relay can reach an already-running inspected server through SSH

### Slice 4.3: Connect Only To Existing Healthy Owners

Goal:

- use discovery truth as the only gate for remote websocket attach

Required work:

- connect only when discovery says `running and connectable`
- surface `server not running` and `server unhealthy` as truthful states
- keep connect separate from lifecycle controls

Must not do:

- do not silently fall back to remote SSH stdio
- do not implicitly start or replace the server from the connect path

Exit criteria:

- remote connect path attaches only to an existing healthy server

### Slice 4.4: Re-baseline Transport And Workspace Tests

Goal:

- prove the websocket attach path works without regressing the lane/runtime
  behavior already fixed in earlier phases

Required work:

- add focused transport and workspace tests for websocket attach
- preserve same-process continuity behavior from Phase 0

Must not do:

- do not skip tests because the seam compiles

Exit criteria:

- websocket attach path is verified before live reattach work begins

## Remaining Phase 5

### Purpose

Replace history-first reconnect with real live reattach.

### Slice 5.1: Define Reattach State Machine

Goal:

- specify the exact runtime sequence for reconnect-time live reattach

Required work:

- define:
  - transport lost
  - reconnecting
  - owner missing
  - owner unhealthy
  - live reattached
  - truthful fallback restore
- make the state machine explicit in controller/runtime code

Must not do:

- do not hide reattach state inside ad hoc controller branches

Exit criteria:

- reconnect has one explicit state machine instead of implicit branching

### Slice 5.2: Implement Reconnect-Time `thread/resume`

Goal:

- reattach to the live thread immediately after reconnect instead of waiting
  for the next prompt

Required work:

- reconnect flow issues `thread/resume` for the selected live thread
- restore live thread subscription and active-turn state on reconnect
- keep `thread/read` as fallback only

Must not do:

- do not leave prompt-send resume as the primary reattach path
- do not treat history restore as sufficient continuity

Exit criteria:

- reconnect-time live reattach exists and is the default when continuity is
  still possible

### Slice 5.3: Restore Pending Turn Interaction State

Goal:

- make reconnect truthful for in-flight approvals, prompts, and active-turn
  runtime state

Required work:

- restore pending approval/input state after live reattach
- preserve selected thread and lane identity through reconnect

Must not do:

- do not fake continuity by showing only static message history

Exit criteria:

- a reconnecting user can return to the same live turn interaction state

### Slice 5.4: Keep Truthful Fallback Restore For Real Failures

Goal:

- preserve honest recovery when live continuity is no longer possible

Required work:

- use `thread/read` only when the owner is gone, the server is no longer
  healthy, or the turn has already finished outside the live path
- keep truthful UI/runtime messaging for those cases

Must not do:

- do not delete truthful fallback restore entirely

Exit criteria:

- live continuity is the default when possible
- truthful fallback restore remains for real external failure

## Remaining Phase 6

### Purpose

Delete the old remote model and harden the final one.

### Slice 6.1: Remove Remote SSH Stdio As A Supported Remote Continuity Path

Goal:

- stop shipping the old remote ownership model once websocket attach and live
  reattach are real

Required work:

- delete the old remote stdio path from supported remote continuity flows
- preserve only what is still needed for local mode or explicitly temporary
  compatibility, if any

Must not do:

- do not leave SSH stdio as a hidden default

Exit criteria:

- supported remote continuity no longer depends on SSH stdio ownership

### Slice 6.2: Delete History-First Reconnect Defaults

Goal:

- remove the old reconnect behavior that recreates the lane or restores from
  history by default

Required work:

- delete reconnect-time history-first branches that have been replaced by live
  reattach

Must not do:

- do not remove truthful fallback restore branches that still serve real
  failures

Exit criteria:

- reconnect defaults to live reattach, not history restore

### Slice 6.3: End-To-End Failure Matrix Hardening

Goal:

- verify the final continuity model against the product contract

Required work:

- test:
  - brief post-turn lock/unlock
  - active-turn continuity through ordinary backgrounding
  - missing `tmux`
  - server not running
  - server unhealthy
  - SSH forward failure
  - websocket disconnect and reconnect
  - true cold start
  - remote host death / owner loss fallback

Must not do:

- do not use narrow happy-path tests as the final release bar

Exit criteria:

- the hard product constraint is verified across the real failure matrix

### Slice 6.4: Cleanup, Docs, And Release Gating

Goal:

- leave the repo in a clean post-migration state

Required work:

- remove obsolete docs/comments/tests that describe the deleted remote model
- update implementation docs to reflect the final architecture
- make the release gate explicit

Must not do:

- do not leave speculative transitional docs as if they were still current

Exit criteria:

- repo and docs reflect one coherent remote continuity architecture

## Immediate Next Slice

The next correct slice is still Phase 2 Slice 2.4.

That slice should land before any explicit lifecycle controls or websocket
transport work because the app still needs one truthful shared runtime path for
owner discovery state.

## Definition Of Remaining Completion

The remaining work is complete only when all of the following are true:

- remote server lifetime is explicit user action
- Pocket Relay discovers and connects only to existing healthy managed owners
- reconnect uses live reattach by default
- truthful fallback restore exists only for real external failure
- remote SSH stdio is no longer the supported continuity path
- the failure matrix proves the hard continuity contract
