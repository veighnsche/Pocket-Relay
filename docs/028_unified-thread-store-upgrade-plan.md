# Unified Thread Store Upgrade Plan

## Goal

The highest-priority architecture fix is to remove the persisted conversation
identity split between:

- `lib/src/core/storage/codex_connection_handoff_store.dart`
- `lib/src/core/storage/codex_connection_conversation_history_store.dart`

These two stores should be replaced by one thread-based persistence model
keyed by:

- `connectionId`
- `threadId`

This plan describes the best upgrade path for that consolidation.

## Why This Is The Highest-Priority Fix

The app currently persists conversation identity in two places:

- handoff store for the current resume thread
- history store for known conversation rows

That is already causing product problems:

- history can go empty while a valid saved resume thread still exists
- features need merge logic to reconcile the two stores
- the app has two persistence worlds for one conversation identity

This is exactly the kind of duplicate source of truth that should be removed,
not normalized.

## Target Architecture

Pocket Relay should persist one connection-scoped conversation state model.

That model should treat `threadId` as the only identity.

### Recommended persisted shape

`SavedConnectionConversationState`

- `selectedThreadId`
- `threads`

`SavedConnectionConversationThread`

- `threadId`
- `preview`
- `messageCount`
- `firstPromptAt`
- `lastActivityAt`

Important rules:

- `threadId` is the identity
- metadata is attached to `threadId`
- the selected resume target is just a pointer to one of those `threadId`s
- there is no second local conversation id

## What This Fixes

After the migration:

- the conversation list reads from one store
- resume target reads from one store
- send/resume updates write to one store
- the app no longer needs handoff/history merge logic
- existing thread-backed conversations remain visible and resumable through one
  model

## Upgrade Principles

### 1. Migrate ownership, not just storage shape

This is not just a persistence schema change.

It is an ownership correction:

- one persisted source of truth for known conversations
- one persisted field for the selected resume thread

### 2. Keep `threadId` as the only identity

The migration must not introduce:

- a Pocket Relay conversation id
- a history-row id
- a parallel resume id

### 3. Use compatibility bridges only as migration steps

Reading the old handoff store temporarily may be necessary.
Keeping permanent dual-read reconciliation is not acceptable as the end state.

## Recommended Implementation Sequence

## Phase 1: Introduce The Unified Store

Add a new persistence seam that replaces both old concepts.

Recommended file direction:

- add a new store file or refactor
  `codex_connection_conversation_history_store.dart`
  into the unified model

The new store should support:

- load connection conversation state
- save connection conversation state
- delete connection conversation state

At this phase, do not remove old stores yet.

## Phase 2: Retarget Reads

Update the read paths so the app uses the unified store for:

- conversation history list
- selected resume thread resolution

This means:

- `ConnectionScopedConversationHistoryStore` should stop merging handoff and
  history as separate concepts
- it should load only from the unified thread state

At this stage, if necessary, the unified store loader may import old handoff
data into the returned state as a temporary migration bridge.

That bridge belongs inside the unified store boundary, not scattered across the
UI or controller.

## Phase 3: Retarget Writes

Update all thread-related writes so they go to the unified store.

### Chat session writes

In `ChatSessionController`:

- when `thread/start` succeeds, register the `threadId`
- when `thread/resume` succeeds, register the `threadId`
- when `turn/start` succeeds, update metadata for the `threadId`
- when continuation thread changes, update `selectedThreadId`

### Workspace resume writes

In `ConnectionWorkspaceController.resumeConversation(...)`:

- set the unified store's `selectedThreadId`
- ensure the selected `threadId` exists in the thread list
- reload the live lane using that selected `threadId`

At the end of this phase, handoff persistence should no longer be the place
where conversation identity is written.

## Phase 4: Migrate Existing Data

Add a bounded migration step from old handoff state into the unified store.

Recommended behavior:

- if unified conversation state already exists for a connection, trust it
- otherwise, if old handoff state exists, seed the unified state with:
  - `selectedThreadId = handoff.resumeThreadId`
  - one thread record keyed by that `threadId`
- do not keep dual-write or dual-read behavior beyond migration

This migration should be:

- deterministic
- one-way
- encapsulated in storage

It should not become part of steady-state app logic.

## Phase 5: Remove The Old Handoff Identity Path

Once reads and writes are moved:

- remove conversation-identity usage from
  `codex_connection_handoff_store.dart`
- either delete that store or reduce it to a compatibility shim during a short
  cleanup window

The app should no longer require a separate handoff store to answer:

- what conversations exist?
- which conversation is selected for resume?

## Phase 6: Rename Types To Match The Real Model

The code currently still carries some misleading terminology such as
"resumable conversation".

After the storage model is unified, rename types so they reflect the actual
product model:

- conversation records keyed by `threadId`
- selected thread pointer
- conversation metadata cache

The code should not imply a second identity category where there is none.

## Files Expected To Change

Primary files:

- `lib/src/core/storage/codex_connection_conversation_history_store.dart`
- `lib/src/core/storage/codex_connection_handoff_store.dart`
- `lib/src/core/storage/connection_scoped_stores.dart`
- `lib/src/features/chat/application/chat_session_controller.dart`
- `lib/src/features/workspace/presentation/connection_workspace_controller.dart`

Likely follow-on files:

- `lib/src/app.dart`
- `lib/src/features/workspace/presentation/widgets/connection_workspace_live_lane_surface.dart`
- associated storage and workspace tests

## Test Plan

The migration is complete only when tests prove there is one persisted
conversation truth.

Required coverage:

1. Unified store loads a connection's thread list and selected thread.
2. A migrated old handoff thread appears as a real conversation record.
3. History list reads from the unified store only.
4. Resume updates the unified store only.
5. Send/start/resume paths upsert thread metadata into the unified store.
6. No feature requires separate handoff-store reconciliation to function.

## Risks

### Risk 1: Breaking existing saved resume threads

If migration is not handled, users could lose visibility into already saved
conversations.

Mitigation:

- seed unified state from existing handoff state during migration

### Risk 2: Leaving dual ownership in place

If old and new stores both remain active, the codebase will keep drifting.

Mitigation:

- time-box compatibility
- remove old conversation-identity writes after retargeting

### Risk 3: Over-expanding the migration

This fix is about identity ownership, not transcript hydration, search, or
full history parity.

Mitigation:

- keep scope strict
- solve only the persisted identity split first

## Definition Of Done

This fix is done when:

- one persisted store owns known conversations by `threadId`
- one persisted field owns the selected resume thread
- history and resume both read from that same store
- no permanent handoff/history merge logic remains
- the codebase no longer treats handoff and history as separate identity worlds

## Decision

The best upgrade path is:

1. introduce a unified `threadId`-based store
2. retarget reads
3. retarget writes
4. migrate old handoff data
5. remove the old handoff identity path
6. rename types to match the real model

That path fixes the actual source-of-truth problem without inventing a Pocket
Relay-specific conversation identity.
