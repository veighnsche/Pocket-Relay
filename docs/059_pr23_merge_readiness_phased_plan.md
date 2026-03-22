# PR 23 Merge Readiness Phased Plan

## Goal

Make PR #23 (`fix/rebuild-and-recovery-simplification`) safe to merge into
current `master` without regressing the inline-image composer work from PR #21
 and without weakening workspace recovery correctness.

This plan assumes the PR will be rebased onto current `master` before merge.

## Current Blockers

- The chat presenter split in PR #23 is still built around the older text-only
  composer contract.
- The debounced recovery persistence path can drop the last pending snapshot on
  controller teardown or dependency swap.
- Recovery-critical identity changes such as active thread selection can remain
  stale during long-running streamed turns because they currently wait on the
  same debounce path as noisy draft updates.

## Phase 1: Rebase Onto Current Master

### Objective

Move the branch onto the real merge target first so all follow-up work happens
against the current structured composer and inline-image behavior.

### Work

- Rebase `fix/rebuild-and-recovery-simplification` onto current `master`.
- Resolve all chat-composer conflicts in favor of the current `master`
  ownership model:
  - `ChatComposerDraft` stays the structured app-owned draft type.
  - `ChatComposerContract` keeps `draft`, `allowsImageAttachment`, and the
    existing image-capability seam.
  - `ChatComposerDraftHost` remains the owner of full draft updates, not just
    plain text replacement.
- Re-run the branch diff after rebase and delete any stale pre-PR-21 contract
  simplifications that only existed to make the earlier branch compile.

### Exit Criteria

- The branch builds on top of current `master`.
- No chat-composer file is downgraded back to a text-only surface.

## Phase 2: Preserve the Rebuild Optimization Without Regressing the Composer

### Objective

Keep the session/transcript/composer rebuild split, but adapt it to the real
 structured composer contract now on `master`.

### Work

- Keep the session projection split in:
  - `chat_root_adapter.dart`
  - `chat_screen_contract.dart`
  - `chat_screen_presenter.dart`
- Update `ChatScreenSessionContract` so `compose()` builds a full
  `ChatComposerContract` from the live `ChatComposerDraft`, not only
  `draft.text`.
- Preserve `allowsImageAttachment` in the composed contract so model-gated image
  input still works.
- Make `_ChatComposerRegionHost` pass full draft updates through
  `composerDraftHost.updateDraft`.
- Keep the transcript-follow optimization isolated from composer-draft updates.
- Keep the session projection isolated from transcript-follow and composer-draft
  churn.

### Exit Criteria

- Composer typing no longer rebuilds the session projection.
- Transcript-follow changes no longer rebuild the session projection.
- Image attachments, text elements, and plain text all continue to round-trip
  through the composer region.

## Phase 3: Fix Recovery Persistence Teardown Correctness

### Objective

Make the debounced persistence path safe under controlled teardown and
 controller replacement.

### Work

- Add an explicit recovery-persistence flush path in
  `connection_workspace_controller.dart`.
- Ensure pending debounced snapshots are forced through the recovery store
  before the controller is disposed or swapped out by a higher-level owner.
- Keep best-effort persistence behavior, but do not silently discard the last
  queued state on normal teardown.
- Add debug-only logging for recovery-store save failures so persistence issues
  are diagnosable without crashing the app.

### Notes

- `dispose()` itself cannot `await`, so the controller owner needs an explicit
  async handoff point before disposal.
- This should be designed as a real ownership seam, not a timer hack inside the
  widget layer.

### Exit Criteria

- A pending draft/thread snapshot survives controller replacement.
- Dependency swaps and normal app-owned teardown no longer lose the last queued
  recovery state.

## Phase 4: Persist Recovery Identity Changes Immediately

### Objective

Separate recovery-critical identity changes from noisy draft/session churn.

### Work

- Keep debounce for high-frequency draft edits and routine runtime deltas.
- Bypass debounce for recovery identity changes, including:
  - selected live connection changes
  - selected thread changes
  - active thread transitions that update the lane’s effective current thread
- Audit the selected-lane listener and state-application paths so recovery
  identity is saved as soon as it changes.
- Preserve the current dedupe behavior so identical snapshots still do not
  rewrite storage unnecessarily.

### Exit Criteria

- A new thread id is persisted even if the turn keeps streaming afterward.
- Recovery state reflects the lane the user actually moved to, not the last
  stream-idle snapshot.

## Phase 5: Verification

### Objective

Prove both correctness and the intended performance win.

### Tests To Add Or Update

- Presenter split tests:
  - composer draft changes do not rebuild the session projection
  - transcript-follow changes do not rebuild the session projection
  - structured composer drafts with images still flow through unchanged
- Recovery persistence tests:
  - pending debounced snapshot flushes before controller disposal/swap
  - thread-selection changes persist immediately even during an active streamed
    turn
  - non-selected lane churn still does not spam writes
- Existing recovery lifecycle tests should stay green after the refactor.

### Verification Commands

- `dart analyze`
- targeted Flutter tests for:
  - `test/chat_root_adapter_test.dart`
  - `test/connection_workspace_controller_test.dart`
- run any adjacent workspace/chat tests if the rebase causes wider presenter or
  lifecycle fallout

### Exit Criteria

- Analyzer is clean.
- Targeted tests are green.
- No regression is observed in the current inline-image composer behavior from
  PR #21.

## Merge Gate

PR #23 is merge-ready only when all of the following are true:

- it is rebased onto current `master`
- the structured composer contract from PR #21 is preserved
- pending recovery snapshots flush before controller teardown
- thread-selection recovery state persists without waiting for stream idle
- targeted tests and analyzer are green
