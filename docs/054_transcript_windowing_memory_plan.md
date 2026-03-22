# Transcript Windowing Memory Plan

## Status

This document defines the first memory-limiting step for Pocket Relay:

- transcript windowing first
- large visible window
- not unlimited

This is intentionally narrower than full memory budgeting. It does not claim to
solve all iPhone memory pressure by itself. It defines the first structural
change we should make before considering deeper eviction or pruning work.

This plan follows the constraints already laid out in:

- [`docs/052_ios_background_ssh_resilience_plan.md`](../docs/052_ios_background_ssh_resilience_plan.md)

## Problem

Right now the selected transcript surface projects and renders all transcript
items for the selected lane.

Relevant current code:

- [`chat_transcript_surface_projector.dart`](../lib/src/features/chat/transcript/presentation/chat_transcript_surface_projector.dart)
- [`chat_screen_contract.dart`](../lib/src/features/chat/lane/presentation/chat_screen_contract.dart)
- [`chat_screen_presenter.dart`](../lib/src/features/chat/lane/presentation/chat_screen_presenter.dart)
- [`transcript_list.dart`](../lib/src/features/chat/transcript/presentation/widgets/transcript/transcript_list.dart)

That means:

- the full selected transcript block list is still projected into UI contracts
- the full contract list is still handed to the transcript list
- the transcript list still exposes all items to the render tree

Flutter lazily builds visible list children, but that is not the same as
windowing. The app still carries the full selected transcript projection path.

## Goal

Limit rendered transcript memory by showing only a bounded slice of the
selected transcript at a time while preserving:

- upstream transcript truth
- honest restore behavior
- active live-tail usability
- draft safety

The initial target is:

- default visible tail window: `160` main transcript items
- no older-window expansion in the first shipped step
- a plain top-of-window notice when older transcript items are hidden

These are starting values, not sacred constants. They should be easy to tune.

## Non-Goals

This phase must not:

- truncate or delete transcript truth from `CodexSessionState`
- create a Pocket Relay-owned local transcript history cache
- redesign the transcript surface
- invent new product states beyond the minimum needed to navigate a bounded
  transcript window
- solve all memory issues through heuristics without measurement

## Ownership

### 1. Transcript truth stays in runtime/domain state

Full transcript state continues to live in:

- [`codex_session_state_session.dart`](../lib/src/features/chat/transcript/domain/codex_session_state_session.dart)

Do not mutate transcript truth just to save memory in phase 1.

### 2. The first shipped step is projector-owned

The first shipped step is intentionally narrower than the original host-based
plan:

- the projector applies a hard tail window
- the transcript surface contract carries hidden-count metadata
- the transcript list renders a plain top-of-window notice when the user
  reaches the oldest visible item

This keeps the first memory limit:

- in app-owned `lib/src/...` code
- out of runtime transcript truth
- out of preview-only glue
- small enough to ship before we decide whether explicit older navigation is
  worth the added state

## Proposed Structure

### 1. Extend screen/presentation contracts

Extend:

- [`chat_screen_contract.dart`](../lib/src/features/chat/lane/presentation/chat_screen_contract.dart)

Add bounded transcript metadata such as:

- `totalMainItemCount`
- `hiddenOlderItemCount`

Do not hide this behind a fake transcript item. This is window metadata, not a
real conversation entry.

### 2. Project only the visible tail

Extend:

- [`chat_transcript_surface_projector.dart`](../lib/src/features/chat/transcript/presentation/chat_transcript_surface_projector.dart)

The projector should:

- keep total transcript block count
- map only the newest `160` transcript blocks into `mainItems`

That is the key savings for phase 1:

- fewer projected item contracts
- fewer projected work-log rows and card inputs
- fewer rendered transcript widgets

## Windowing Behavior

### Default behavior

When the selected transcript is first shown:

- show only the newest `160` main transcript items
- keep pinned request items outside this limit
- preserve the current live-tail follow behavior

### Older navigation

The first shipped step does not provide older-window navigation.

Instead:

- scrolling upward stops at the oldest item inside the bounded window
- the top of that window shows plain text explaining that older transcript
  activity is not shown in this view

This is a deliberate product constraint for the first memory-limiting change,
not an accidental omission.

### Pinned requests

Pinned approval/user-input surfaces remain separate and unwindowed:

- `pinnedItems` are not part of the bounded main transcript window

## UI Scope

Keep UI change narrow.

Allowed:

- one slim top-of-transcript text notice when older items are hidden
- simple hidden-count copy such as:
  - `Showing the most recent 160 of 842 items`
  - `Older activity is not shown in this view`

Not allowed:

- card redesign
- extra panel chrome
- transcript restyling
- speculative summary surfaces

## Known Follow-On Problem

Transcript windowing creates one important follow-on usability problem that
must be solved in a later step:

- users currently reach older user prompts by scrolling upward in the full
  transcript
- from there they can long-press a historical user prompt and use the existing
  `Continue From Here` flow
- if transcript windowing hides those older prompts behind a bounded visible
  slice, that restart path becomes harder or impossible to reach unless the
  user can intentionally navigate to the older window that contains the target
  prompt

This means the first shipped memory limit knowingly narrows access to older
restart points. That is acceptable only as an intermediate step and must be
followed by a deliberate product decision about whether to restore older-window
navigation later.

## Initial Constants

Start with:

- `defaultVisibleMainItemCount = 160`

Rationale:

- large enough to keep recent context usable
- bounded enough to stop unlimited projection growth
- simple enough to reason about in tests

Do not overfit these numbers before measurement.

## Implementation Sequence

### Phase 1: Infrastructure

1. Add transcript window metadata to `ChatTranscriptSurfaceContract`.
2. Add a fixed visible tail limit to `ChatTranscriptSurfaceProjector`.

### Phase 2: Project only the visible range

3. Update `ChatTranscriptSurfaceProjector` to map only the newest visible slice
   of `sessionState.transcriptBlocks`.
4. Keep `pinnedItems` unchanged.
5. Keep empty-state and restore-state behavior unchanged.

### Phase 3: Surface controls

6. Add a top-of-transcript notice row in `TranscriptList`.
7. Do not add `Load older` or `Jump to latest` controls in the first shipped
   step.

### Phase 4: Stabilization

8. Tune the default limit only after real-device measurement.
9. If still needed later, consider weighted budgeting for expensive item kinds
   such as large diffs.

## Verification

### Unit/presenter tests

Add focused tests proving:

- newest `N` items are projected by default
- pinned items stay visible
- hidden older count is exposed through the surface contract

### Widget tests

Add focused tests for:

- top notice appears when older items are hidden
- top notice stays absent when the transcript fits inside the limit
- auto-follow still works for the bounded latest window

### Real-device measurement

Use a real iPhone and record before/after:

- memory after cold restoring a long conversation
- memory after scrolling through a long conversation
- memory after switching between multiple live lanes
- memory with changed-files and large diff surfaces

Tools:

- Xcode Instruments Allocations
- Xcode Instruments VM Tracker
- Memory Graph

## Expected Outcome

After phase 1 transcript windowing, Pocket Relay should:

- stop projecting unlimited transcript history into the active transcript
  surface
- render a large but bounded recent window by default
- stop upward scrolling at the oldest visible bounded item
- explain that limit with plain transcript text
- keep upstream transcript truth intact

## Follow-On Risks

Transcript windowing reduces one major source of memory growth, but it does not
guarantee iPhone safety on its own.

If memory pressure still remains high after this:

- inspect offscreen live-lane retention in mobile shell
- inspect expensive surfaces like large diffs and image-heavy items
- inspect restore-time object retention during cold-start transcript rebuild

Those are follow-on steps, not reasons to skip windowing first.
