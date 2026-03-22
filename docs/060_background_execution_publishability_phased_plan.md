# Background Execution Publishability Phased Plan

## Status

This document turns the findings in
[`059_background_execution_publishability_findings.md`](./059_background_execution_publishability_findings.md)
into an execution plan.

The goal is not just resilience in the abstract. The goal is to make Pocket
Relay publishable for its real use case:

- a user monitors and steers a live Codex session from a phone
- ordinary app switching must not kill the live lane
- if the phone app is suspended or killed, the app must recover honestly
- if the product promise is stronger than that, the transport/backend ownership
  model must change

## Release Bars

There are two different release bars. They must not be conflated.

### Release Bar A: Truthful recovery

This bar means:

- short backgrounding does not make Pocket Relay disconnect by itself
- if the app is later suspended or killed, the user returns to the same lane,
  same draft, and real upstream conversation state
- the app reconnects and restores honestly from upstream truth

This is the minimum publishable bar for a mobile client unless the marketing and
product promise explicitly claim stronger continuity.

### Release Bar B: True live-turn continuity

This bar means:

- a live Codex turn can keep running while the phone app is backgrounded
- the user can return and reattach to the same still-running session/turn
- continuity is not only historical restore after the fact

This bar is stricter and requires backend/transport ownership changes, not just
Flutter lifecycle work.

## Recommendation

Pocket Relay should not ship until Release Bar A is complete.

If the intended product claim remains:

- "Pocket Relay preserves a live Codex turn while the user briefly does
  something else on the phone"

then Release Bar B should also be treated as required before release.

## Non-Negotiable Rules

These rules apply to every phase:

- do not disconnect, dispose, rebuild, or mark live lanes stale on ordinary
  `inactive` / `hidden` / `paused` / `resumed` transitions without confirmed
  transport loss
- do not add Pocket Relay-owned transcript history as fallback truth
- do not solve background-kill recovery by degrading the normal live-turn path
- do not claim seamless continuity if the implementation only restores history
  after reconnect

## Phase 0: Lock The Product Contract

### Goal

Remove ambiguity about what "publishable" means for this feature.

### Scope

- decide whether release messaging promises Release Bar A or Release Bar B
- decide whether the product is allowed to recover after loss or must truly
  reattach to the same live turn
- decide whether non-selected live lanes matter for this release or only the
  selected active lane

### Deliverables

- one written product statement in docs
- one acceptance matrix for:
  - brief app switch
  - phone lock
  - multitasking
  - suspension
  - process kill
  - reconnect failure
- explicit release gate tied to either Bar A or Bar B

### Exit Criteria

- no unresolved ambiguity remains about whether truthful restore is enough
- engineering knows whether detached remote execution is mandatory for release

### Why This Phase Exists

Without this decision, the team can accidentally "finish" a recovery flow that
still fails the real product promise.

## Phase 1: Instrument The Failure Modes

### Goal

Make the app able to tell the difference between:

- ordinary backgrounding
- stale transport on resume
- app-server session exit
- SSH transport loss
- cold-start recovery after process kill

### Scope

- add lifecycle timestamps
- add selected-lane recovery diagnostics
- add transport/session-loss diagnostics
- add logs or state markers that identify whether the app process survived
- add test seams so lifecycle and disconnect scenarios can be simulated

### Deliverables

- structured recovery diagnostics stored with narrow runtime scope
- controller-visible transport-loss reason
- tests covering transport loss while backgrounded

### Exit Criteria

- every failure path produces a concrete classification instead of a vague
  disconnected state
- logs can answer why the lane was lost

### Why This Phase Exists

Without observability, the team cannot distinguish:

- iOS suspension behavior
- remote app-server exit
- restore-mapper bugs
- transport bugs introduced by Pocket Relay itself

## Phase 2: Finish Release Bar A Recovery

### Goal

Guarantee that Pocket Relay preserves the selected lane identity and restores it
truthfully after confirmed loss.

### Scope

- keep the current no-self-disconnect lifecycle behavior
- detect confirmed transport/session loss on foreground or cold start
- mark the selected lane as reconnect-required only on confirmed loss
- reconnect transport
- resume the real upstream thread
- restore transcript from upstream `thread/read`
- preserve draft text throughout
- show explicit recovery states instead of empty/fake live UI

### Deliverables

- loss-aware reconnect policy in workspace/session ownership code
- honest UI states for:
  - reconnecting
  - restoring conversation
  - remote session unavailable
  - restore failed
  - draft preserved
- widget and controller tests proving:
  - short app switch does not rebuild or disconnect the live lane
  - cold start restores lane and draft
  - transport loss triggers reconnect and upstream history restore
  - reconnect failure keeps the lane visible and honest

### Exit Criteria

- Release Bar A is satisfied for the selected active lane
- no ordinary app-switching path severs a live lane
- no confirmed-loss path returns the user to a blank or misleading lane

### Why This Phase Exists

This is the minimum publishable behavior if the app is allowed to restore after
loss instead of guaranteeing uninterrupted live continuity.

## Phase 3: Add Platform-Specific Resilience

### Goal

Reduce avoidable loss without pretending the platform can be bypassed.

### Scope

#### iOS

- add finite background-task handling around background transitions
- use it only for narrow grace work such as state persistence and immediate
  shutdown bookkeeping
- do not model it as indefinite SSH survival

#### Android

- add a foreground service while a live turn is actively running
- show a required visible notification
- stop the foreground service when the turn ends

### Deliverables

- iOS lifecycle bridge for finite background grace
- Android foreground-service implementation tied to active turns
- tests and device verification for both paths

### Exit Criteria

- the app gains best-effort platform resilience beyond Flutter-only lifecycle
  handling
- Android active-turn continuity is materially improved
- iOS behavior is more orderly on background transition but still honest about
  platform limits

### Why This Phase Exists

This phase reduces avoidable churn and makes the app more robust, but it does
not solve true live-turn continuity on iPhone by itself.

## Phase 4: Move Durable Execution Off The Phone

### Goal

Make the running Codex session durable even when the phone-owned client
transport disappears.

### Scope

- stop treating the phone-owned SSH stdio session as the durable owner of the
  remote run
- design a detached or reattachable remote execution model
- determine whether this happens through:
  - a detached remote `codex app-server`
  - a remote supervisor
  - a gateway/service layer
  - upstream app-server session support
- preserve real upstream ownership and avoid local fake state

### Deliverables

- chosen remote execution ownership design
- session identity or reattachment token model if supported
- updated protocol/transport contract documentation
- implementation plan for the remote side if work must happen outside this repo

### Exit Criteria

- a live remote Codex run no longer depends on the phone process staying alive
- engineering knows exactly how a new mobile client transport can find and
  reattach to that remote run

### Why This Phase Exists

Release Bar B is not credible until durable execution ownership moves off the
phone-owned SSH session.

## Phase 5: Implement True Reattachment

### Goal

Allow Pocket Relay to return to the same still-running live session instead of
only restoring history after the turn finishes or after transport loss.

### Scope

- connect a new transport to the still-running remote execution owner
- reattach to the active session or turn
- resume live event delivery
- fill any transcript gap from upstream history as needed
- keep fallback behavior honest if reattachment fails

### Deliverables

- app-server/client support for reattachment
- controller logic that distinguishes:
  - reattached live session
  - recovered historical session
  - remote session gone
- tests proving:
  - turn continues while client transport is absent
  - client returns and reattaches
  - transcript remains coherent if a partial history gap must be filled

### Exit Criteria

- Release Bar B is satisfied
- the user can background the phone app, return, and continue the same live run
  when the remote execution owner is still alive

### Why This Phase Exists

This is the phase that converts Pocket Relay from "truthful mobile recovery
client" into "true live continuity client."

## Phase 6: Release Hardening

### Goal

Prove the implementation is robust enough to ship.

### Scope

- full device matrix verification on current iPhone and Android versions
- long-turn verification
- lock-screen and multitasking verification
- airplane-mode / network-drop verification
- reconnect failure verification
- memory-pressure verification on long transcripts
- copy review for recovery states
- App Store / Play Store review-risk check for background behavior

### Deliverables

- manual test matrix with pass/fail results
- automated regression coverage for the critical lifecycle and restore paths
- release notes / product copy aligned with the actual implementation

### Exit Criteria

- the shipped product claim matches the tested behavior
- lifecycle regressions are covered by automated tests
- app-review risk for background behavior is understood and acceptable

## Suggested Ordering And Dependencies

1. Phase 0 first. Do not build against an ambiguous product promise.
2. Phase 1 next. Observability is needed before judging success.
3. Phase 2 next. This gets Pocket Relay to Release Bar A.
4. Phase 3 after Phase 2. Platform resilience should improve the real path, not
   replace it.
5. Phase 4 is mandatory before any credible Release Bar B commitment.
6. Phase 5 depends on Phase 4 and any upstream/backend support it requires.
7. Phase 6 happens before release regardless of which bar is chosen.

## What Each Phase Actually Solves

### After Phase 2

Pocket Relay can honestly recover the selected active lane after suspension or
kill.

It still cannot claim:

- the same live turn definitely stayed alive in the background
- the same in-flight live stream was reattached

### After Phase 3

Pocket Relay becomes more resilient on-device, especially on Android.

It still cannot claim true live continuity on iPhone.

### After Phase 5

Pocket Relay can credibly claim live continuity across background interruption,
assuming the remote execution owner remains alive and reachable.

## Recommended Release Strategy

### Conservative Strategy

Ship after Phase 3 if product messaging is aligned to Release Bar A:

- Pocket Relay preserves your live lane, draft, and upstream conversation state
- if the app is suspended or killed, it reconnects and restores the real
  session on return

### Strict Strategy

Do not ship until Phase 5 if product messaging is aligned to Release Bar B:

- Pocket Relay keeps your live Codex run going while you briefly use something
  else and lets you come back to the same still-running session

## Repo Ownership Guidance

Likely ownership by layer:

- lifecycle/recovery policy:
  [`lib/src/features/workspace/`](../lib/src/features/workspace/)
- selected-lane restore and session logic:
  [`lib/src/features/chat/lane/`](../lib/src/features/chat/lane/)
- transport and protocol work:
  [`lib/src/features/chat/transport/app_server/`](../lib/src/features/chat/transport/app_server/)
- iOS platform glue:
  [`ios/`](../ios/)
- Android foreground-service work:
  [`android/`](../android/)

## Primary References

- [`docs/052_ios_background_ssh_resilience_plan.md`](./052_ios_background_ssh_resilience_plan.md)
- [`docs/053_ios_background_restore_handoff.md`](./053_ios_background_restore_handoff.md)
- [`docs/059_background_execution_publishability_findings.md`](./059_background_execution_publishability_findings.md)
