# 030 Behavior Preserving Architecture Simplification Plan

## Status

Accepted refactor plan.

This document records the remaining architecture simplification work after the
first chat-root cleanup pass landed.

## Goal

Reduce the number of moving parts without changing product behavior.

That means:

- simplify ownership
- remove duplicate representations of the same runtime facts
- remove forwarding layers that only wrap one implementation

That does not mean:

- redesigning the product
- changing visible workflow semantics
- removing seams that still carry real behavior

## Non-Negotiable Constraint

This is a behavior-preserving refactor.

The following behaviors must remain the same unless a later product decision
explicitly changes them:

- session start, resume, and recovery behavior
- transcript ordering and visible transcript content
- settings sheet behavior and validation behavior
- workspace lane selection, reopening, and closing behavior
- conversation history loading and resume behavior

If a simplification would change behavior, it is not an acceptable refactor
under this plan.

Historical conversation truth is also non-negotiable.

- Pocket Relay will not own a persisted local history or transcript archive
- historical conversation discovery must come from Codex
- historical transcript restoration must come from Codex thread history
- Pocket Relay may still own local live lane/session state, including live
  conversation descriptors and runtime metadata that do not claim to be the
  authoritative historical record
- local persistence may only remember narrow lane state such as
  `selectedThreadId`

## Already Completed

The first simplification slice is done.

Completed removals:

- dead chat-root region policy plumbing
- dead chat-root renderer delegate plumbing

Result:

- `ChatRootAdapter` now composes the real Flutter renderer directly
- `PocketPlatformPolicy` no longer carries chat-root rendering policy state
- tests were updated to verify real ownership boundaries instead of stale
  combined-text assumptions

## Remaining Refactor Slices

## 1. Unify `selectedThreadId` Ownership

### Problem

`selectedThreadId` persistence is still written from more than one layer.

Today it is written from both:

- `lib/src/features/chat/application/chat_session_controller.dart`
- `lib/src/features/workspace/presentation/connection_workspace_controller.dart`

That means one persisted fact has split ownership.

### Target

One layer owns persistence of selected thread state.

Recommended owner:

- `ChatSessionController`

Reason:

- it already knows the active thread
- it already knows resume/fresh/alternate-session transitions
- it is the runtime authority for when thread selection should be cleared or
  advanced

### Result

- workspace controller issues intent only
- chat session controller performs the actual persistence write
- thread selection persistence has one owner

### Expected files

- `lib/src/features/chat/application/chat_session_controller.dart`
- `lib/src/features/workspace/presentation/connection_workspace_controller.dart`

## 2. Split `ChatSessionController` Into Real Application Ownership Boundaries

### Problem

`ChatSessionController` still owns too much:

- transport lifecycle
- session boot/resume routing
- conversation recovery behavior
- persistence writes
- runtime state application
- some UI-facing side effects

That is too much concentrated ownership for one controller.

### Target

Keep `ChatSessionController` as the orchestration surface, but move distinct
responsibilities into smaller collaborators.

Likely collaborators:

- session bootstrap/resume coordinator
- conversation-selection persistence helper
- recovery-state decision helper
- runtime event applier or reducer-facing adapter

### Result

- smaller ownership boundaries
- easier reasoning about lifecycle rules
- less risk that thread persistence, transport decisions, and UI recovery logic
  drift together accidentally

### Expected files

- `lib/src/features/chat/application/chat_session_controller.dart`
- likely one or more new files under
  `lib/src/features/chat/application/`

## 3. Simplify The Settings Form Stack

### Problem

The settings path still has more indirection than the product needs:

- host
- presenter
- large contract tree
- sheet surface
- overlay delegate

The overlay delegate is real.
The rest needs a sharper ownership review.

### Target

Keep the overlay boundary because it carries real modal-launch behavior.

Reduce internal presentation indirection so the form state and rendered sheet
 are easier to follow.

Most likely simplification:

- keep host-owned draft state
- keep the sheet surface
- collapse unnecessary presenter/contract expansion where it only mirrors form
  state without adding a second renderer path

### Result

- fewer settings-specific types
- less duplicated form state representation
- same validation and save behavior

### Expected files

- `lib/src/features/settings/presentation/connection_settings_host.dart`
- `lib/src/features/settings/presentation/connection_settings_presenter.dart`
- `lib/src/features/settings/presentation/connection_settings_contract.dart`
- `lib/src/features/settings/presentation/connection_settings_sheet_surface.dart`

## 4. Clean Up Conversation-State Store Semantics

### Problem

The local storage file still carries history-oriented naming and legacy baggage
that no longer matches the real architecture.

Current reality:

- local steady-state persistence is mostly `selectedThreadId`
- authoritative history rows come from Codex through the workspace history
  repository
- authoritative historical transcript content must also come from Codex, not
  Pocket Relay persistence

But the store file still contains:

- `SavedConversationThread`
- legacy history compatibility code
- migration naming that implies Pocket Relay owns historical conversation lists

### Target

Make the storage boundary reflect what it actually owns.

Two acceptable directions:

1. Reduce the file to connection-scoped conversation selection state plus a
   bounded migration shim.
2. Split legacy migration logic from steady-state selection persistence.

### Result

- storage names match real ownership
- less chance of reintroducing Pocket Relay-owned history truth by accident

### Expected files

- `lib/src/core/storage/codex_connection_conversation_history_store.dart`
- possibly a new dedicated migration file under `lib/src/core/storage/`

## 5. Collapse The Transcript Representation Chain

### Problem

This is the largest remaining simplification target.

One turn still moves through too many representations:

- active runtime item
- turn artifact
- UI block
- transcript item contract

Those layers are spread across:

- `lib/src/features/chat/application/transcript_item_policy.dart`
- `lib/src/features/chat/application/transcript_turn_segmenter.dart`
- `lib/src/features/chat/models/codex_session_state.dart`
- `lib/src/features/chat/presentation/chat_transcript_surface_projector.dart`
- `lib/src/features/chat/presentation/chat_transcript_item_projector.dart`

Not every layer is wrong, but the chain is longer than necessary.

### Target

Remove at least one middle representation.

The end state should preserve:

- transcript grouping
- streaming behavior
- pending-request placement
- changed-files grouping
- work-log grouping
- approval and user-input chronology

### Result

- fewer transformations per runtime event
- less duplicated mapping logic
- easier maintenance when new transcript item types are added

### Risk

This is the riskiest remaining slice.

It should only be attempted after the cheaper ownership simplifications above
are complete.

### Expected files

- `lib/src/features/chat/application/transcript_item_policy.dart`
- `lib/src/features/chat/application/transcript_turn_segmenter.dart`
- `lib/src/features/chat/models/codex_session_state.dart`
- `lib/src/features/chat/presentation/chat_transcript_surface_projector.dart`
- `lib/src/features/chat/presentation/chat_transcript_item_projector.dart`

## Implementation Order

Recommended order:

1. unify `selectedThreadId` ownership
2. split `ChatSessionController`
3. simplify settings form stack
4. clean up conversation-state store semantics
5. collapse transcript representation chain

Reason for this order:

- the first four are mostly ownership simplifications with bounded runtime risk
- the transcript chain is the most valuable remaining cleanup, but also the
  easiest place to introduce behavioral regressions

## Recommended Next Implementation

The next slice to implement is:

- unify `selectedThreadId` ownership

Why this should go next:

- it removes a real split source of truth
- it is smaller than the transcript refactor
- it reduces controller ambiguity before the larger `ChatSessionController`
  split

## Definition Of Done For Each Slice

Each simplification slice is only done when:

- the ownership model is clearer than before
- the removed layer is actually gone, not just bypassed
- the same behaviors are still covered by tests
- old hosts no longer secretly own the moved behavior

## Verification Rule

Every slice must verify behavior, not just compile state.

Required verification should match the risk of the slice, but at minimum:

- `dart analyze`
- focused tests for the changed ownership boundary
- full test suite when shared infrastructure changes
