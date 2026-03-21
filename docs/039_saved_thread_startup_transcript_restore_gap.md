# 039 Saved Thread Startup Transcript Restore Gap

## Status

Completed follow-up implementation and verification.

This document narrows the remaining historical-transcript work after PR 7.

The broader architecture plan in
`docs/032_codex_history_transcript_restoration_upgrade_plan.md` remains
correct. The `thread/read` contract capture work in
`docs/033_thread-read-contract-phase-0.md` is also complete.

The restore gap documented here is now closed.

Implemented result:

- `ChatSessionController.initialize()` now restores persisted
  `selectedThreadId` history on startup instead of waiting for the next
  `sendPrompt()`
- recreated lanes now reuse the same initialization-owned historical restore
  rule during resume and reconnect flows
- focused controller and widget tests now cover startup restore, unavailable
  upstream history, reconnect rehydration, and live-lane replacement restore

What is not complete is the product behavior for one critical restore path:

- a lane starts with a persisted `selectedThreadId`
- Pocket Relay knows which historical thread should be resumed
- but the transcript wall is not hydrated immediately from upstream Codex
  history

That means the app can remember historical resume intent without actually
showing the historical conversation wall.

## Why This Exists

PR 7 was merged as:

- `WIP: Harden Codex historical transcript restoration`

That work successfully landed most of the supporting architecture:

- Codex-backed history discovery
- `thread/read(includeTurns: true)` contract hardening
- dedicated history decoder models
- normalized historical conversation mapping
- explicit historical restore UI states
- explicit history-row resume restoration

However, the remaining startup restore gap is still large enough to fail the
real product expectation:

- if a user resumes a historical conversation, the transcript wall should fill
  with that historical conversation before the next prompt is sent

## Current Reality

### What already works

The explicit history-row restore path is implemented.

Current path:

1. workspace history row selection
2. `ConnectionWorkspaceController.resumeConversation(...)`
3. `ChatSessionController.selectConversationForResume(...)`
4. `ChatSessionController._restoreConversationTranscript(...)`
5. `readThreadWithTurns(threadId: ...)`
6. historical normalizer
7. historical restorer
8. transcript wall populated from Codex history

That path is already covered by focused tests.

### What is still broken

The startup/plain lane restore path is incomplete.

Current startup behavior:

1. a persisted `selectedThreadId` is loaded into
   `SavedConnectionConversationState`
2. that thread id is injected into `ChatConversationSelectionCoordinator`
3. the coordinator keeps it as future resume intent
4. no automatic historical transcript hydration happens on lane startup
5. the saved thread id is only used later when `sendPrompt()` starts or resumes
   a session

So the app remembers:

- which thread should continue

But it does not reliably do the product-critical part:

- load and render that thread's historical transcript wall immediately

## Why This Is Not Done

This gap means the repo still fails the definition of done already stated in
`docs/032_codex_history_transcript_restoration_upgrade_plan.md`.

That plan says the work is done only when restoring a historical conversation
either:

- shows the real transcript on screen, or
- shows an explicit honest state that Codex did not provide enough history

The startup gap does neither reliably enough.

## Existing Evidence In The Repo

The repo already contains evidence for both the working slice and the missing
slice.

Evidence that the explicit restore path works:

- `test/chat_session_controller_test.dart`
- `test/connection_workspace_controller_test.dart`
- `test/connection_workspace_desktop_shell_test.dart`

Evidence that the startup path is still treated mostly as resume intent:

- `test/chat_session_controller_test.dart`
  includes restart behavior that verifies the next `sendPrompt()` resumes the
  saved thread id
- that test does not require transcript hydration before sending

This is the key mismatch:

- the architecture work mostly exists
- the end-user startup behavior is still incomplete

## Non-Negotiable Constraints

- Do not introduce a Pocket Relay-owned persisted transcript archive.
- Do not add a local transcript cache as the primary restore mechanism.
- Historical transcript content must still come from upstream Codex
  `thread/read(includeTurns: true)`.
- `selectedThreadId` remains narrow lane state only.
- Honest unavailable or failed restore states must remain visible when upstream
  history is missing or unusable.

## Remaining Work

## Phase 1. Auto-Restore On Lane Startup

### Goal

If a lane starts with a persisted `selectedThreadId`, Pocket Relay should
attempt historical transcript restoration immediately.

### Work

1. Add a startup restore trigger for the initial saved thread selection.
2. Do not wait for `sendPrompt()` to perform the first historical hydration.
3. Reuse the existing Codex-backed restore path instead of adding a second
   restore implementation.

### Expected result

- a reopened lane with saved conversation state shows the historical transcript
  wall immediately
- if Codex does not provide usable history, the lane shows the existing honest
  restore state instead of an empty transcript pretending to be ready

## Phase 2. Unify Restore Trigger Ownership

### Goal

Make all historical-resume entry points use one restore rule.

### Required entry points

- explicit conversation-history row resume
- lane startup with persisted `selectedThreadId`
- live-lane replacement during `resumeConversation(...)`
- reconnect flows that recreate the lane binding while preserving conversation
  selection

### Work

1. Audit where `initialConversationState.selectedThreadId` enters the lane.
2. Ensure every lane re-creation path either:
   - triggers the same historical restore flow, or
   - deliberately clears historical selection when that is the intended product
     behavior
3. Remove any path where saved thread id exists without a matching attempt to
   hydrate transcript history.

### Expected result

- one restore rule
- no hidden difference between “history row resume” and “startup resume”
- less future churn in workspace and chat ownership boundaries

## Phase 3. Verification

### Goal

Prove the missing user-visible behavior, not only the mapping internals.

### Required tests

1. `ChatSessionController` startup test:
   - initial saved `selectedThreadId`
   - historical thread fixture available
   - transcript hydrates without calling `sendPrompt()`

2. `ChatSessionController` startup unavailable-history test:
   - initial saved `selectedThreadId`
   - no usable turns from Codex
   - explicit unavailable restore state is shown

3. `ConnectionWorkspaceController` initialization test:
   - connection state store already contains `selectedThreadId`
   - first live lane hydrates the transcript wall on startup

4. reconnect/replacement-lane test:
   - lane is recreated with saved thread selection
   - transcript restoration still happens

5. widget-level verification:
   - restored historical transcript is visible after startup
   - honest unavailable state is visible when applicable

### Existing tests that should remain

- explicit history-row restore tests
- decoder tests
- normalizer tests
- historical restorer tests

## Expected Files

- `lib/src/features/chat/application/chat_session_controller.dart`
- `lib/src/features/chat/application/chat_conversation_selection_coordinator.dart`
- `lib/src/features/workspace/presentation/connection_workspace_controller.dart`
- `lib/src/features/chat/presentation/connection_lane_binding.dart`
- `test/chat_session_controller_test.dart`
- `test/connection_workspace_controller_test.dart`
- relevant desktop/mobile shell widget tests

## Definition Of Done

This gap is closed only when all of the following are true:

1. A lane with persisted `selectedThreadId` attempts historical restoration
   automatically on startup.
2. That startup path uses upstream Codex history, not app-local transcript
   persistence.
3. The transcript wall is populated before the user sends a new prompt when
   usable upstream history exists.
4. The app shows an explicit honest unavailable or failed state when usable
   upstream history does not exist.
5. The same restore behavior applies consistently across startup, explicit
   history-row resume, and lane recreation flows.
6. Tests prove the real user-visible startup behavior, not only decoder or
   mapper internals.
