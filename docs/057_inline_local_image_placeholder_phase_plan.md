# Inline Local Image Placeholder Phase Plan

## Purpose

Define a phased implementation plan for one specific behavior:

- inserting a local image attachment into the composer at the current caret
  position as an inline placeholder inside the sentence text

This plan is intentionally narrower than general "image support."

It exists to prevent wrong work:

- no speculative remote-image feature work
- no broader transcript redesign
- no Widgetbook-owned implementation
- no fake visual parity work that bypasses transport or restore correctness

## Branch

Implementation branch for this work:

- `inline-local-image-placeholders`

## Requested Behavior

Pocket Relay should support the Codex-style local-image composer behavior where:

- the user picks a local image file
- the composer inserts an atomic placeholder such as `[Image #1]` at the
  current caret position
- the placeholder can sit in the middle of an otherwise normal sentence
- the attachment survives editing, send, and in-session recall
- the submitted turn is serialized as structured user input, not as plain text

## Explicit Non-Goals

Not part of this phase plan unless explicitly requested later:

- remote image URL entry
- camera capture flows
- gallery-specific UX
- drag-and-drop image support
- image-generation transcript polish
- view-image tool-result redesign
- broad transcript restyling
- card/panel treatment changes

## Visual Boundary

Allowed to change:

- the composer body only as needed to expose a local-image attach action and
  render inline placeholder behavior
- user-message rendering only as needed to truthfully show image-bearing turns

Must remain materially unchanged:

- surrounding lane chrome
- transcript layout unrelated to image-bearing user messages
- sidebar, headers, menus, and unrelated desktop/mobile shells
- existing non-card visual language

## Recommended Technical Direction

Use the pragmatic Codex-compatible approach first:

- keep the editable field text-based
- insert a placeholder token such as `[Image #N]` into the text buffer
- track attachment metadata separately in app-owned state
- track placeholder ranges as structured text elements

Do not start with inline embedded Flutter widgets inside the editable field.
That is harder, less stable, and not required to match the requested behavior.

## Current Constraints

Current repo facts:

- `ChatComposerContract` is text-only
- `ChatComposerSurface` owns a plain `TextEditingController`
- transport `sendUserMessage(...)` is text-only
- repo currently has no image/file picker dependency

Implication:

The correct first work is ownership and transport scaffolding, not visual polish.

## Phase 0: Contract Lock And Seam Selection

Goal:

- lock the narrow target and the concrete implementation seam before touching
  visible behavior

Tasks:

1. Verify the exact live `turn/start` app-server payload shape for local image
   input against the running Codex build.
2. Confirm the app-owned representation for composer draft state:
   - text buffer
   - text elements
   - local image attachments
   - caret/selection insertion semantics
3. Pick the file-selection dependency.

Recommended default:

- `file_picker`

Reason:

- there is no existing picker package in the repo
- the requested target is local file attachment, not camera/gallery product UX
- it is a smaller fit than designing a photo-library flow now

Exit criteria:

- the verified wire contract is documented
- the internal draft model shape is decided
- the dependency choice is explicit

## Phase 1: Composer Ownership Refactor

Goal:

- replace the text-only composer contract with an app-owned structured draft
  model without materially changing the UI yet

Tasks:

1. Introduce app-owned draft models under `lib/src/...` for:
   - composer draft text
   - placeholder/text-element metadata
   - local image attachment metadata
2. Upgrade screen/composer contracts so controller state no longer collapses the
   draft down to a plain string.
3. Keep the existing composer appearance materially the same during this phase.

Why this phase exists:

- it creates the ownership boundary needed for insertion, deletion, restore, and
  send behavior without externalizing that cost into later turns

Exit criteria:

- draft state is structured
- existing text-only behavior still works
- no UI redesign has leaked into surrounding surfaces

## Phase 2: Local Image Acquisition And Inline Insertion

Goal:

- allow the user to choose a local image and insert its placeholder at the
  current caret position

Tasks:

1. Add a single local-image attach affordance to the composer.
2. Use the chosen picker flow to return a local file path.
3. Insert `[Image #N]` at the current selection/caret location.
4. Record the matching attachment mapping in draft state.
5. Keep numbering deterministic and stable within the draft.

Behavior that must be proven:

- insert at start of sentence
- insert in middle of sentence
- insert at end of sentence
- insert adjacent to text and adjacent to another placeholder

Exit criteria:

- placeholder insertion works at the caret
- attachment metadata stays aligned with placeholder numbering

## Phase 3: Atomic Editing Semantics

Goal:

- make inline image placeholders behave like atomic elements rather than normal
  loose text fragments

Tasks:

1. Intercept backspace/delete behavior around placeholder ranges.
2. Remove the attachment mapping when its placeholder is deleted.
3. Renumber remaining placeholders when needed.
4. Handle text replacement and external draft mutation safely.
5. Ensure multiline editing does not corrupt placeholder ranges.

Important note:

This is the phase where Flutter complexity lives. The issue is not whether
Flutter can do it. The issue is maintaining correct controller text, selection,
and attachment metadata under edits.

Exit criteria:

- placeholders delete atomically
- partial edits inside a placeholder cannot corrupt draft state
- duplicate and adjacent placeholder cases behave predictably

## Phase 4: Transport Upgrade And Capability Gating

Goal:

- send image-bearing turns correctly and only when the selected model supports
  images

Tasks:

1. Replace the text-only send path with structured user input serialization.
2. Serialize text plus text elements plus local image attachments into the
   verified upstream `turn/start` shape.
3. Thread model `input_modalities` into the chat lane state.
4. Gate attach/send behavior when images are unsupported.
5. Preserve the draft and show a warning instead of silently dropping
   attachments.

Exit criteria:

- the outgoing payload is structured, not text-only
- unsupported-image models do not lose draft state

## Phase 5: Recall, Restore, And Rewind Correctness

Goal:

- preserve inline local image placeholders across the real editing lifecycle

Tasks:

1. Restore inline placeholders from local in-session history.
2. Rehydrate placeholders when prefilling from rewind/backtrack.
3. Ensure attachment mappings survive controller reloads and screen rebuilds.
4. Upgrade history normalization if upstream payloads already carry enough raw
   data to restore local image attachments.

Exit criteria:

- a sent image-bearing draft can be recalled in-session
- rewind/backtrack does not collapse the draft back to plain text

## Phase 6: Truthful Transcript Rendering

Goal:

- show image-bearing user turns honestly after send

Tasks:

1. Update user-message transcript rendering so image-bearing turns are not
   flattened into misleading plain text.
2. Decide the minimum truthful display:
   - placeholder-only display
   - placeholder plus filename
   - placeholder plus local preview if justified

Recommended default:

- start with placeholder plus filename or other lightweight metadata

Reason:

- it is enough to preserve user-visible truth without forcing an immediate image
  gallery design

Exit criteria:

- the transcript does not pretend an image-bearing turn was text-only

## Phase 7: Verification And Hardening

Goal:

- prove the ownership, lifecycle, and transport behavior at the smallest
  correct scopes

Required test coverage:

1. Composer insertion tests:
   - start
   - middle
   - end
   - adjacent placeholders
2. Atomic editing tests:
   - backspace/delete around placeholders
   - selection replacement
   - renumbering after deletion
3. Transport tests:
   - structured payload generation
   - unsupported-image model gating
4. Lifecycle tests:
   - local recall
   - rewind/backtrack prefill
5. Presentation tests:
   - truthful user-turn rendering

Manual verification:

- desktop
- one mobile target

## Review Gates

Stop and review before moving on after:

1. Phase 1: confirm the structured draft ownership feels right before attaching
   visible UI
2. Phase 3: confirm atomic editing semantics before transport wiring
3. Phase 4: confirm live payload correctness before restore work
4. Phase 6: confirm the transcript display is truthful without widening into a
   redesign

## Suggested Execution Order

If we start implementation immediately after planning, the recommended order is:

1. Phase 0
2. Phase 1
3. Phase 2
4. Phase 3
5. Phase 4
6. Phase 5
7. Phase 6
8. Phase 7

## Honest Risk Assessment

Low-risk:

- creating the structured draft models
- inserting placeholder text at the caret
- adding a local file picker dependency

Medium-risk:

- capability gating via upstream model metadata
- truthful transcript rendering after send

Higher-risk:

- atomic placeholder editing inside Flutter text controls
- restore/rewind correctness without regressions
- final transport serialization until the live payload shape is verified

## Definition Of Done For This Work

This work is done when all of the following are true:

- a local image can be inserted in the middle of a sentence in the composer
- the placeholder behaves atomically under editing
- the image-bearing turn is sent as structured input
- unsupported-image models preserve draft state and warn
- in-session recall and rewind preserve the placeholder and attachment mapping
- the transcript shows the sent turn truthfully
- surrounding surfaces remain materially the same
