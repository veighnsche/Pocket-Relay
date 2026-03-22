# iPhone Background SSH Resilience Plan

## Status

This document defines what Pocket Relay must do so an iPhone background
transition, suspension, or process termination does not fatally destroy the
user experience for an active SSH-backed Codex session.

The core constraint is not negotiable:

- iPhone can suspend the app shortly after it backgrounds
- iPhone can later terminate the suspended process to reclaim memory or for
  general system resource management
- a normal in-process SSH connection is not a background-resilient system
  transfer primitive

So the goal is not "keep SSH alive forever in the background."

The goal is:

- assume live SSH can disappear while the app is backgrounded
- preserve enough truth to reconnect safely
- restore the conversation honestly on return
- avoid losing the active lane just because iOS killed the process

## Product Constraint

For Pocket Relay, silent loss of the SSH connection is fatal if it also means:

- the active lane forgets what conversation it belonged to
- the active draft disappears
- the user returns to an empty or misleading transcript
- the app pretends the live session is still healthy when it is gone

This is not just a transport bug. It is a product continuity requirement.

## What Must Be True

### 1. Live SSH is disposable

The app must treat the live SSH/app-server process as disposable runtime state,
not as durable truth.

That means:

- do not assume a backgrounded app will keep its SSH socket
- do not assume a remote app-server process is still attached when the app
  returns
- do not model "backgrounded but probably still connected" as equivalent to a
  healthy foreground session

### 2. Conversation identity must survive process death

The app must persist enough lane identity to reconnect to the correct upstream
conversation after a cold restart.

At minimum that means preserving:

- connection profile identity
- selected lane/thread identity
- active conversation thread id or resume target
- current draft text
- any user-visible lane metadata needed to restore the active screen

This must not become a Pocket Relay-owned local transcript history store. It is
lane state, not historical truth.

### 3. Upstream history must restore the transcript

After reconnect or cold restart, transcript restoration must come from Codex
thread history and runtime restore paths, not from a fake local transcript
cache.

That means:

- reattach or resume the real upstream thread when possible
- re-read upstream thread history
- rebuild transcript UI from authoritative upstream payloads
- show honest loading or restore-failure states if upstream restoration is not
  yet complete

### 4. The app must distinguish suspension from termination

These are different:

- app merely backgrounded and resumed before process death
- app suspended and later killed by iOS
- app foregrounded with a stale or severed SSH session

The UI and controller logic must not flatten those into one vague "disconnected"
state.

## Current Risk Indicators In This Repo

The current codebase already has strong thread restore and history-source-of-
truth rules, but it does not appear to have a dedicated app lifecycle strategy
for SSH-backed sessions.

Relevant signals today:

- [display_wake_lock_host.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/device/display_wake_lock_host.dart)
  observes app lifecycle, but that is only for wake-lock behavior
- SSH transport lifecycle exists, but it is connection-centric rather than
  iPhone background-resilience-centric:
  [codex_app_server_connection.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/transport/app_server/codex_app_server_connection.dart)
- conversation restore and resume already exist and should be reused rather
  than replaced with local transcript persistence:
  [chat_session_controller_history.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/lane/application/chat_session_controller_history.dart)
  [codex_connection_conversation_state_store.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/storage/codex_connection_conversation_state_store.dart)

So the app is not starting from zero, but the background-kill problem is not
yet explicitly owned end-to-end.

## Required Workstreams

### Workstream 1: Explicit app lifecycle handling for live lanes

Add an app lifecycle owner for chat/workspace session behavior.

Requirements:

- observe foreground/background/inactive transitions
- snapshot active lane state before suspension risk
- mark live SSH-backed lanes as needing reconnection when the app returns
- avoid pretending a previously attached transport is still valid after a long
  background gap

Concrete outputs:

- one lifecycle coordinator above lane/session controllers
- one explicit policy for what happens on:
  - `inactive`
  - `paused`
  - `resumed`
- timestamps for last foreground/background transitions

### Workstream 2: Durable lane-state persistence

Persist the minimum state required to recover after iOS kills the process.

Persist:

- selected thread id
- active thread id if different from selected thread id
- profile/connection identifier
- draft text
- enough lane-selection metadata to reopen the correct lane

Do not persist:

- authoritative transcript history
- synthetic local transcript archives
- fake SSH session state claiming the connection is still alive

### Workstream 3: Reconnect-first foreground recovery

On foreground after background or cold restart, the controller must explicitly
re-establish transport state instead of assuming the old session survived.

Requirements:

- attempt reconnect or session bootstrap from saved lane/profile state
- attempt thread resume using the preserved upstream thread identity
- if reconnect succeeds, re-read upstream thread history
- if reconnect fails, keep the lane visible with an honest failure state and
  preserved draft

The user must not land in a blank lane with silent state loss.

### Workstream 4: Honest restore UX

The UI must show the truth while foreground recovery is happening.

Required visible states:

- reconnecting to remote session
- restoring conversation history
- remote session unavailable
- conversation restore failed
- draft preserved but live transport lost

The UI must not:

- show stale transcript as if it were live
- silently clear the lane
- hide restore failure behind generic empty state

### Workstream 5: Remote process ownership strategy

Decide what Pocket Relay assumes about the remote app-server process after the
iPhone app backgrounds.

Questions the implementation must answer explicitly:

- Is the remote app-server expected to die when the SSH channel dies?
- If it stays alive, can Pocket Relay safely reattach?
- If it dies, is cold restart acceptable as long as the thread identity and
  transcript restore survive?

The app must be built around the real backend/transport behavior, not the most
convenient assumption.

### Workstream 6: Transcript memory budgeting

Unlimited visible history may contribute to memory pressure, but it must be
measured rather than guessed.

Requirements:

- profile memory cost of dense transcript lanes on iPhone
- measure cold-start restore cost for long conversations
- identify which parts of transcript rendering are retained in memory
- identify whether image-heavy, syntax-heavy, or large-diff surfaces are the
  main contributors

Do not start by inventing transcript truncation rules without measurement.

Possible mitigations after measurement:

- windowed transcript rendering
- lazy loading of older transcript sections
- collapsing expensive surfaces until opened
- reducing retained presentation objects for long lanes

### Workstream 7: Draft safety

Draft preservation is mandatory.

Requirements:

- backgrounding must not drop the current composer text
- termination must not drop the current composer text
- foreground reconnect failure must still preserve the draft visibly

### Workstream 8: Observability and diagnostics

The app needs enough telemetry to know which failure actually happened.

Capture at minimum:

- app background timestamp
- app resume timestamp
- whether process was cold-started
- whether saved lane state existed
- whether transport reconnect succeeded
- whether thread resume succeeded
- whether thread/read restoration succeeded
- whether the previous SSH session was explicitly disconnected or silently lost
- memory warnings / memory-pressure signals if available

Without this, the app will misdiagnose "history bug" vs "iOS killed the app" vs
"SSH died" vs "restore mapper bug."

## Required Architecture Rules

### Rule 1: No local transcript history fallback

Do not solve this by caching full transcript history locally and pretending it
is authoritative.

This repo already has the right rule:

- Codex history is upstream truth

Keep that rule.

### Rule 2: Live transport state must be reconstructible

Anything required to continue a lane after termination must be reconstructible
from:

- saved lane state
- connection profile
- upstream thread identity
- upstream history read

If a live session can only survive by keeping the original process in RAM, the
product will be fragile on iPhone.

### Rule 3: Cold-start recovery is a first-class path

Cold-start restore after iOS termination is not an edge case. It is a primary
mobile path.

The app must treat:

- fresh launch into saved active lane
- resume after background kill
- foreground after stale transport

as explicitly designed flows with tests.

## Verification Matrix

The implementation is not done until all of these are covered.

### Lifecycle tests

- app backgrounds while SSH lane is active
- app resumes quickly without process death
- app resumes after simulated cold restart
- app returns with dead transport and preserved lane state

### Restore tests

- saved lane restores the selected thread id
- reconnect triggers real thread resume
- upstream thread history repopulates transcript
- restore failure shows honest state instead of empty transcript

### Draft tests

- draft survives background
- draft survives termination/restart
- draft survives reconnect failure

### Memory tests

- long transcript lane memory profile on iPhone
- changed-files and large diff surfaces memory profile
- repeated lane switching memory profile

### UX tests

- loading copy while reconnecting
- error copy when remote session is gone
- no fake "connected" state after silent loss

## Hard Conclusions

### What will not work

- trying to rely on a live SSH socket surviving arbitrary iPhone backgrounding
- treating iOS background behavior as a bug to outsmart
- using local transcript persistence as the primary restore mechanism
- guessing that unlimited history is the only cause without measurement

### What must happen instead

- preserve lane identity and drafts locally
- reconnect explicitly on foreground/cold start
- restore transcript from upstream thread history
- design for termination as a normal mobile condition
- measure memory and rendering cost before changing history policy

## Recommended Implementation Order

1. Add app lifecycle ownership for active SSH-backed lanes.
2. Persist the minimum lane/session recovery state needed after process death.
3. Make cold-start foreground recovery reconnect and restore the real upstream
   thread.
4. Add honest reconnect/restore UI states.
5. Instrument termination, reconnect, and restore outcomes.
6. Measure transcript memory cost on iPhone.
7. Only then decide whether transcript rendering/windowing changes are needed.

## Definition Of Done

This problem is solved when:

- Pocket Relay can be backgrounded on iPhone during an SSH-backed session
- the process may be killed
- the user can return later
- the app restores the correct lane and draft
- the app either reconnects and restores the real upstream conversation or
  shows an honest recoverable failure state
- no app-local fake transcript history is used as the source of truth
