# Remaining Source Of Truth Audit

## Goal

This document records where Pocket Relay still has duplicated sources of truth,
which duplicates are acceptable, and which ones should be removed.

It is a follow-up to:

- [`026_threadid-identity-architecture.md`](./026_threadid-identity-architecture.md)

That document established the core identity rule:

- a conversation is a `threadId`

This document focuses on the remaining places where the codebase still carries
the same product fact in more than one place.

## Standard For This Audit

Not all duplicated state is bad.

A duplicate is acceptable when:

- one layer owns the truth
- another layer holds a clearly derived runtime projection or cache
- the distinction is part of the product behavior and easy to explain

A duplicate is bad when:

- two layers both behave like the authoritative owner
- the same concept is persisted in multiple places
- features have to merge or reconcile the copies to behave correctly
- the UI can tell different stories depending on which copy is read

## Bad Duplicate 1: Conversation Handoff Versus Conversation History

### Where it exists

- `lib/src/core/storage/codex_connection_handoff_store.dart`
- `lib/src/core/storage/codex_connection_conversation_history_store.dart`
- `lib/src/core/storage/connection_scoped_stores.dart`

### Why it is bad

Both stores know about `threadId`.

That means the app currently persists conversation identity in two places:

- one store for "current handoff"
- one store for "known conversations"

This is the worst remaining duplicate because it already caused a user-visible
bug:

- the history list went empty after the new history store was introduced
- existing users still had valid resume state in the handoff store
- the app had to merge the two worlds during load

Any time a feature needs fallback merging between two stores that both know the
same identity, the architecture is already warning us that ownership is wrong.

### Correct end state

There should be one `threadId`-based persistence model for known
conversations.

The "handoff" concept should not be a separate identity store.
It should become:

- either a pointer to the currently selected `threadId`
- or a field inside the same thread-based record system

### Priority

High.

This is the most urgent consolidation target.

## Bad Duplicate 2: Current Conversation Thread In The Chat Controller

### Where it exists

Inside `lib/src/features/chat/application/chat_session_controller.dart`, the
controller currently reasons across:

- `_resumeThreadId`
- `_sessionState.rootThreadId`
- `appServerClient.threadId`

Supporting types also carry overlapping thread identity:

- `lib/src/features/chat/models/codex_session_state.dart`
- `lib/src/features/chat/infrastructure/app_server/codex_app_server_connection.dart`

### Why it is bad

These values are not identical in ownership:

- transport tracks the app-server thread
- session state tracks the visible/root transcript thread
- controller keeps a separate resume candidate

That split is understandable historically, but it creates too much identity
reconciliation inside one controller.

The controller now has helper methods just to answer:

- what is the active conversation thread?
- what is the resume thread?
- should we reuse the tracked app-server thread?

That is a sign that identity resolution is too distributed.

### Correct end state

One layer should own "current conversation thread" for the lane.

The likely shape is:

- session state owns the lane's current thread identity
- transport tracks what the app-server reports
- controller translates transport events into session state
- controller should not need a semi-independent private thread identity unless
  there is a very specific recovery reason

The app may still need transitional fields, but they should be minimized and
documented as such.

### Priority

Medium-high.

This is the next identity cleanup after the handoff/history merge.

## Acceptable Duplicate 1: Saved Connection Definition Versus Running Lane Definition

### Where it exists

- saved connection catalog and storage in
  `lib/src/core/storage/codex_connection_repository.dart`
- active lane profile and secrets in
  `lib/src/features/chat/application/chat_session_controller.dart`

### Why it is acceptable

This split is part of the product behavior.

Pocket Relay intentionally supports:

- saved connection edits
- live running lanes
- reconnect-required state when saved values diverge from the running lane

So the product genuinely has two states:

- the saved definition
- the currently running definition

This is not a hidden duplicate.
It is an explicit product mode.

### Requirement for it to stay acceptable

The UI must stay truthful about the difference.

That means:

- saved edits should not pretend they already changed the live lane
- reconnect-required state should be explicit
- the app should never silently pick whichever copy is convenient

### Priority

No consolidation needed right now.

## Acceptable Duplicate 2: Workspace Runtime Selection State

### Where it exists

- `lib/src/features/workspace/models/connection_workspace_state.dart`

Examples:

- `selectedConnectionId`
- `liveConnectionIds`
- `viewport`
- `reconnectRequiredConnectionIds`

### Why it is acceptable

This is runtime UI state, not a second persisted source of truth.

It describes:

- what is open
- what is selected
- which viewport is visible
- which live lanes need reconnect

That is exactly what a workspace state object should own.

### Priority

No change needed.

## Acceptable Duplicate 3: Thread Registry Versus Timelines

### Where it exists

- `lib/src/features/chat/models/codex_session_state.dart`

Examples:

- thread registry entries
- timeline states keyed by thread

### Why it is acceptable

These are not two identities for a conversation.
They are two runtime projections around the same `threadId`:

- registry for ordering and thread metadata
- timelines for per-thread activity and transcript state

This area may still benefit from simplification, but it is not the same kind of
problem as inventing a second conversation identity.

### Priority

Low.

Keep under observation, but do not treat it like the current identity blocker.

## What The Codebase Should Stop Doing

The codebase should stop solving source-of-truth drift with merge logic as the
long-term answer.

Merge logic is sometimes a valid migration bridge.
It is not a valid permanent ownership model.

If a feature must read two stores and reconcile them to answer one simple
question, the architecture should be corrected rather than normalized in the
UI.

## Recommended Consolidation Order

### 1. Merge handoff and conversation history into one thread store

This should become the single persisted conversation source keyed by
`threadId`.

The old "handoff" concept should become an attribute or selection pointer
within that same thread-based world.

### 2. Simplify thread identity inside `ChatSessionController`

Reduce the number of places the controller uses to resolve the current lane
thread.

The controller should not remain the place where transport thread state,
private resume state, and transcript thread state are all independently
authoritative.

### 3. Leave saved-versus-live connection state as-is

That split is real product behavior and should stay explicit.

### 4. Re-evaluate registry-versus-timeline state only after the identity work

That seam is less dangerous and should not distract from the real problem.

## Decision

The codebase still has duplicated sources of truth, but only some of them are
architecturally harmful.

The highest-priority harmful duplicate is:

- persisted conversation identity split between handoff and history

The next harmful duplicate is:

- current conversation thread identity split across controller private state,
  session state, and transport state

Those should be consolidated.

The saved-versus-live connection split and workspace runtime state should stay,
because they are part of the product model rather than accidental parallel
ownership.
