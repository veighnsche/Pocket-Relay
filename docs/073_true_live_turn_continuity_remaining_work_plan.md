# True Live-Turn Continuity Remaining Work Plan

## Purpose

This document starts from the current implementation state on
`feat/true-live-turn-continuity` and lists only the work that remains.

It does not replace the full architecture docs. It is the execution checklist
for the unfinished work after:

- Phase 0 completed
- Phase 1 completed
- Phase 2 completed
- Phase 3 completed
- Phase 4 completed
- Phase 5 completed

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
- owner discovery state is wired into workspace/runtime surfaces using the real
  connection owner identity
- explicit user-owned `Start server`, `Stop server`, and `Restart server`
  actions exist in the workspace/application layer
- real SSH-backed `tmux` owner control exists for explicit start/stop/restart
- connection settings can surface truthful remote server state and real saved
  connection lifecycle controls without mixing that lifecycle into staged draft
  edits
- remote lanes connect through discovered `tmux`-owned websocket servers instead
  of remote SSH stdio ownership
- reconnect uses live `thread/resume` before truthful `thread/read` fallback
- pending approval and input requests are replayed across live reattach
- workspace recovery already distinguishes owner missing, owner unhealthy, live
  reattach, and truthful fallback internally

The branch does not have these yet:

- deletion of the old SSH stdio remote model
- removal of the dormant-only `Saved connections` inventory model
- final cleanup of legacy ambiguous recovery presentation

## Remaining Work Overview

| Remaining phase | Outcome | Remaining slices |
| --- | --- | --- |
| 6 | Old remote model is deleted, saved inventory ownership is corrected, and release is hardened | 5 |

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
- do not let `Saved connections` hide active/open connections while claiming
  connection-owned server state is surfaced honestly

If a remaining slice requires one of those shortcuts to pass, the slice is
wrong or the phase order is wrong.

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

### Slice 4.4: Handle Server-Not-Running And Server-Unhealthy States Honestly

Goal:

- make remote attach failure truthful without auto-start

Required work:

- surface stopped and unhealthy owners as explicit runtime states
- keep those states distinct from generic disconnect or reconnect copy

Must not do:

- do not auto-start the server from the failure path
- do not disguise stopped or unhealthy server states as generic disconnects

Exit criteria:

- stopped and unhealthy owners are surfaced honestly during remote attach

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

### Slice 5.2: Expose Reconnect-Time `thread/resume` In The Client Layer

Goal:

- make reconnect-time resume a first-class app-server request path

Required work:

- expose an explicit reconnect-time `thread/resume` request in the client layer
- keep it separate from prompt-send or lazy session start behavior

Must not do:

- do not leave reconnect-time `thread/resume` hidden behind prompt-send flow
- do not treat `thread/start` or lazy session start as equivalent

Exit criteria:

- the client layer can explicitly issue reconnect-time `thread/resume`

### Slice 5.3: Make Recovery Attempt Live Reattach First

Goal:

- move the workspace/chat recovery path away from history-first restore

Required work:

- recovery attempts live reattach before `thread/read`
- reconnect restores live thread subscription and active-turn state first

Must not do:

- do not recreate the lane before attempting live reattach
- do not use history restore as the default fallback in this slice

Exit criteria:

- reconnect-time live reattach exists and is the default when continuity is
  still possible

### Slice 5.4: Restore Pending Turn Interaction State

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

### Slice 5.5: Keep Truthful Fallback Restore For Real Failures

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

### Slice 6.2: Remove Prompt-Send Resume As The Normal Reattach Path

Goal:

- finish deleting the lazy resume behavior after live reattach exists

Required work:

- remove prompt-send-triggered resume as the normal way a live thread becomes
  active again
- delete any remaining history-first reconnect defaults already replaced by
  live reattach

Must not do:

- do not remove truthful fallback restore branches that still serve real
  failures

Exit criteria:

- reconnect no longer waits for the next user prompt to make the thread live

### Slice 6.3: Remove Legacy Ambiguous Recovery States

Goal:

- collapse the old reconnect/rebuild ambiguity into precise server and
  continuity states
- make `Saved connections` the canonical inventory of all saved connections

Required work:

- remove generic reconnect UI/runtime states that hide:
  - host unsupported
  - server stopped
  - server unhealthy
  - live reattached
  - truthful fallback restore
- stop filtering active/open connections out of the saved-connections surface
- show connection-owned open/selected state and remote server state from that
  saved inventory surface
- keep `Open lanes`, if retained, as quick-switch UI only

Must not do:

- do not preserve ambiguous UI states just because they are already wired
- do not keep connection-owned server truth visible only when the lane is closed

Exit criteria:

- UI/runtime no longer blur the new explicit states together
- `Saved connections` remains the canonical inventory including active/open
  connections

### Slice 6.4: End-To-End Failure Matrix Hardening

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

### Slice 6.5: Cleanup, Docs, And Release Gating

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

The next correct slice is Phase 6 Slice 6.1.

That slice should land before the saved-connections inventory cleanup in Slice
6.3 so the hidden remote SSH stdio fallback is deleted before UI cleanup claims
the final remote architecture is in place.

## Definition Of Remaining Completion

The remaining work is complete only when all of the following are true:

- remote server lifetime is explicit user action
- Pocket Relay discovers and connects only to existing healthy managed owners
- reconnect uses live reattach by default
- truthful fallback restore exists only for real external failure
- remote SSH stdio is no longer the supported continuity path
- `Saved connections` is the canonical inventory of all saved connections,
  including active/open ones
- the failure matrix proves the hard continuity contract
