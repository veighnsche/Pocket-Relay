# Background Execution Publishability Phased Plan

## Status

This document is the aligned publishability-phase precursor to the final remote
continuity plan.

It no longer uses the old `Release Bar A` / `Release Bar B` shorthand.

Use these literal names instead:

- `Truthful Recovery`
- `True Live-Turn Continuity`

The definitive remote continuity contract and execution plan now live in:

- [`069_true_live_turn_continuity_contract.md`](./069_true_live_turn_continuity_contract.md)
- [`070_true_live_turn_continuity_migration_map.md`](./070_true_live_turn_continuity_migration_map.md)
- [`071_tmux_required_execution_plan.md`](./071_tmux_required_execution_plan.md)

## Product Framing

### Truthful Recovery

This means:

- ordinary app switching does not make Pocket Relay sever the live lane
- if the app is later suspended or killed, the user returns to the same lane
  identity and draft
- Pocket Relay reconnects honestly and restores upstream history truthfully

### True Live-Turn Continuity

This means:

- the live Codex run keeps going while the phone app is away
- the user returns to the same still-running remote server and thread
- reconnect is live re-entry, not only post-fact history restore

For remote mode, the architecture is now fixed around the stronger target:

- `tmux` is required
- the remote app-server lifecycle is user-owned
- the user explicitly starts and stops the remote server
- Pocket Relay may rediscover and reconnect to an already-running server
- Pocket Relay must not implicitly stop that server on disconnect or
  backgrounding
- websocket is the reconnectable transport to that surviving server
- reconnect-time `thread/resume` is the live reattach path

## Non-Negotiable Rules

- do not disconnect, dispose, rebuild, or mark live lanes stale on ordinary
  `inactive` / `hidden` / `paused` / `resumed` transitions without confirmed
  transport loss
- do not add Pocket Relay-owned transcript history as fallback truth
- do not solve background-kill recovery by degrading the normal live-turn path
- do not silently start, replace, or stop a remote continuity server during
  reconnect
- do not claim seamless continuity if the implementation only restores history
  after reconnect

## Phase 0: Protect The Existing Lane

### Goal

Eliminate avoidable same-process regressions before changing the remote
ownership model.

### Deliverables

- preserve the selected lane and draft through ordinary app switching
- preserve the existing in-memory lane on pure transport recovery when the
  binding still exists
- prevent brief post-turn lock/unlock from rebuilding the lane from history

### Exit Criteria

- ordinary app switching does not sever the lane
- short post-turn lock/unlock does not discard surviving in-memory detail

## Phase 1: Finish Truthful Recovery Foundations

### Goal

Guarantee honest recovery after confirmed loss, independent of the final remote
continuity architecture.

### Deliverables

- recovery-state persistence for selected lane identity and draft
- explicit transport-loss classification
- reconnect-required only on confirmed loss
- reconnect plus truthful `thread/read` restore
- honest restore UI states
- narrow platform grace work:
  - iOS finite background grace for persistence/housekeeping only
  - Android foreground-service work only while a live turn is active

### Exit Criteria

- same lane and draft recover honestly after cold start
- no normal app-switch path breaks the live lane
- restore UX is truthful when continuity is unavailable

## Phase 2: Introduce The Right Seams

### Goal

Stop the remote continuity path from being hard-wired to SSH-launched stdio
ownership.

### Deliverables

- transport abstraction above spawned-process stdio
- separation between:
  - SSH bootstrap
  - remote server discovery/control
  - live transport connection
- temporary stdio compatibility while migration is underway

### Exit Criteria

- remote continuity work no longer depends on process-shaped transport as the
  only model

## Phase 3: Add Explicit Remote Server Ownership

### Goal

Make remote server lifetime a deliberate user action instead of an implicit
side effect of connect/disconnect.

### Deliverables

- hard prerequisite enforcement for remote `tmux`
- explicit remote capability probe for:
  - `tmux`
  - configured `codex` launcher
- deterministic discovery of Pocket Relay-managed remote servers
- explicit user actions:
  - `Start server`
  - `Stop server`
  - `Restart server`
- explicit runtime states:
  - prerequisite missing
  - server not running
  - server running
  - server unhealthy

### Exit Criteria

- Pocket Relay no longer decides server lifetime implicitly
- reconnect can attach to an existing server without starting one

## Phase 4: Connect To The Existing Server

### Goal

Reach a running user-owned remote server without recreating ownership on every
connect.

### Deliverables

- remote app-server runs inside `tmux`
- app-server listens on websocket
- Pocket Relay reaches it through secure SSH-forwarded connectivity
- server discovery returns machine-readable server metadata such as:
  - session identity
  - websocket endpoint details
  - health/readiness state

### Exit Criteria

- a user-started remote server survives phone disconnect/backgrounding
- Pocket Relay can reconnect to the same server later without starting a
  replacement

## Phase 5: Implement Live Reattach

### Goal

Turn reconnect into real live-thread re-entry instead of history-first
recovery.

### Deliverables

- `initialize` on the new transport connection
- reconnect-time `thread/resume(selectedThreadId)`
- pending approval/input restoration onto the reattached lane
- `thread/read` only as fallback when the server is gone, the turn already
  finished, or continuity can no longer be proven

### Exit Criteria

- reconnect returns to the same live thread when it still exists
- history restore is no longer the primary answer to interrupted continuity

## Phase 6: Delete The Old Remote Model And Harden Release

### Goal

Remove the wrong default architecture and prove the final path is shippable.

### Delete

- remote SSH stdio as the primary remote owner model
- implicit remote owner creation during ordinary connect/reconnect
- implicit remote owner stop semantics tied to disconnect
- history-first reconnect as the continuity default
- prompt-send-triggered resume as the normal reattach path

### Verify

- long-turn backgrounding
- lock/unlock
- network drop and reconnect
- server stopped vs server missing vs prerequisite missing
- cold-start truthful fallback
- pending approval/input continuity

### Exit Criteria

- the shipped product claim matches the tested behavior
- only one coherent remote continuity path remains

## Recommended Ordering

1. Land Phase 0 and Phase 1 first.
2. Introduce the transport and ownership seams from Phase 2.
3. Add explicit server ownership and discovery from Phase 3.
4. Connect to the existing `tmux`-owned websocket server in Phase 4.
5. Add reconnect-time live reattach in Phase 5.
6. Delete the old remote model and harden release in Phase 6.

## Relationship To The Final Plan

This document now exists as the publishability-oriented phase framing.

For implementation, the repo should follow:

- [`071_tmux_required_execution_plan.md`](./071_tmux_required_execution_plan.md)

That document is the final execution plan for the chosen architecture.

## Primary References

- [`052_ios_background_ssh_resilience_plan.md`](./052_ios_background_ssh_resilience_plan.md)
- [`053_ios_background_restore_handoff.md`](./053_ios_background_restore_handoff.md)
- [`059_background_execution_publishability_findings.md`](./059_background_execution_publishability_findings.md)
- [`069_true_live_turn_continuity_contract.md`](./069_true_live_turn_continuity_contract.md)
- [`070_true_live_turn_continuity_migration_map.md`](./070_true_live_turn_continuity_migration_map.md)
- [`071_tmux_required_execution_plan.md`](./071_tmux_required_execution_plan.md)
