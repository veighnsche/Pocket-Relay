# Apple Glass Migration Plan

## Purpose

This document is the source of truth for preparing Pocket Relay for future
Apple-native glass surfaces without duplicating product behavior across Flutter
and native renderers.

The immediate goal is not to ship glass components.

The immediate goal is to move product UI behavior into shared presentation
contracts so Flutter becomes one renderer of those contracts and a future native
renderer can consume the same ownership model.

## Non-Negotiable Rules

- Do the migration the hard and correct way.
- Do not land cosmetic abstractions that leave real ownership in Flutter.
- Do not leave split ownership behind as deferred cleanup if that split will
  make later migration harder.
- Do not start a new slice until that slice is written down in this document.
- Do not treat chat history as the source of truth for migration status.

## Current Status

- Phase 1, top-level chat screen ownership move: completed on this branch
- Phase 2, connection settings form contract extraction: completed on this
  branch
- Phase 3, pending user-input form contract extraction: completed on this
  branch
- Root architectural adapter work: not started
- Apple-native glass components: not started

## What Is Already Solid

- `ChatSessionController` remains application logic plus side effects, not
  widget logic.
- `TranscriptReducer` and the transcript policy layer still centralize runtime
  event handling.
- `CodexSessionState` remains the main runtime projection layer for transcript
  behavior.
- The top-level chat screen already renders from a shared screen contract.
- The connection settings surface already renders from a shared form contract.
- Pending user-input requests already render from a shared request contract and
  request-keyed form-state host.

These are the parts we should build on, not reopen.

## What Is Still Not Ready For Native Ownership

- Transcript item dispatch is still mostly a Flutter-only block-to-widget
  switch.
- Changed-file diff presentation still originates inside a Flutter card.
- Transcript follow behavior is still widget-local.
- The screen-level transcript contract still collapses pending requests to the
  primary approval and primary user-input items.

## Target Architecture

### Layer 1: Domain and application

Keep the reducer, policies, session state, app-server integration, and
controller-based flow as the source of truth for business behavior and remote
session state.

### Layer 2: Shared presentation contracts

The app should own shared presentation contracts for:

- top-level chat screen state
- connection settings form state
- pending user-input request form state
- overlay and effect boundaries needed above renderer code

Flutter and Apple-native renderers should consume these contracts instead of
re-deriving behavior locally.

### Layer 3: Renderer implementations

Flutter remains the active renderer for now. Native renderers should be added
only after the next remaining interactive surfaces have shared contracts.

### Layer 4: Root architectural adapter

Only after the shared contracts are stable should the app introduce a root
adapter capable of selecting or embedding renderer ownership for major regions.

## Completed Work

### Phase 1 Completed Scope

Phase 1 is complete and delivered:

- one top-level chat screen contract derived from raw top-level application
  state
- one transcript surface contract derived from `CodexSessionState`
- top-level screen action definitions owned by the presentation layer
- composer state owned by the presentation layer
- turn indicator visibility owned by the presentation layer
- connection settings launch payload and launch effect owned by the
  presentation layer
- top-level snackbar effects mapped through a screen effect boundary
- `ChatScreen` reduced to controller host, effect executor, and renderer of the
  shared screen contract

### Phase 2 Completed Scope

Phase 2 is complete and delivered:

- one renderer-neutral connection settings draft model built from
  `ConnectionProfile` and `ConnectionSecrets`
- one connection settings form state model controlling validation visibility
- one connection settings contract owning sections, field descriptors, auth-mode
  selection, run-mode toggles, validation, dirty-state, submit-state, and save
  payload
- one connection settings presenter deriving that contract from initial raw
  state plus current form state
- `ConnectionSheet` reduced to Flutter renderer and input plumbing over the
  shared draft/state/contract path

### Phase 3 Completed Scope

Phase 3 is complete and delivered:

- one renderer-neutral pending user-input draft model and form-state model
- one pending user-input contract and presenter
- one request-keyed pending user-input form host above the transcript card layer
- transcript routing of pending user-input items through that shared host
- `UserInputRequestCard` reduced to Flutter controller/layout plumbing over the
  shared contract
- widget coverage for submit flow, option-chip updates, request replacement,
  and draft persistence across transcript movement
- app-level coverage for both standard tool-input submission and MCP
  elicitation submission through the existing controller transport boundary

## Phase 3 Deep Investigation

Phase 3 covered:

- pending user-input form contract extraction

This section records the initial investigation that defined Phase 3. Slice 1
and slice 2 have since completed. The findings below describe the baseline that
justified that work plus the constraints that still matter for slice 3.

### Findings

#### 1. Before slice 2, `UserInputRequestCard` owned real behavior

Original file:

- `lib/src/features/chat/presentation/widgets/transcript/cards/user_input_request_card.dart`

At that point the card still owned:

- dynamic `TextEditingController` creation
- field identity and answer synchronization
- option-tap behavior
- fallback single-field creation when no questions exist
- answer payload assembly on submit

That was the ownership problem slice 2 needed to remove.

#### 2. The application layer already owns transport branching

Current file:

- `lib/src/features/chat/application/chat_session_controller.dart`

`ChatSessionController.submitUserInput` already decides whether a request is
answered through:

- `answerUserInput(...)` for standard tool-input requests
- `respondToElicitation(...)` for MCP elicitation requests

That branching should stay in the controller. Phase 3 should stop at a
normalized submit payload contract of `Map<String, List<String>>`.

#### 3. The runtime question model is intentionally underspecified

Current file:

- `lib/src/features/chat/models/codex_runtime_event.dart`

The runtime model currently gives us:

- `id`
- `header`
- `question`
- `options`
- `isOther`
- `isSecret`

It does not give us:

- required vs optional markers
- multiple-choice vs single-choice semantics
- stable option IDs separate from labels
- a validation schema

So Phase 3 should not invent stronger form rules than the runtime model
supports. It should preserve current semantics and make them explicit in the
shared contract.

#### 4. The screen contract only exposes the primary pending input request

Current files:

- `lib/src/features/chat/models/codex_session_state.dart`
- `lib/src/features/chat/presentation/chat_transcript_surface_projector.dart`

The runtime state can hold multiple pending user-input requests, but the
screen-level transcript surface currently projects only the primary pending
user-input block.

Phase 3 should not silently broaden product behavior, but it also must not bake
this limitation into widget-local form state. The shared request-form state must
be keyed by `requestId`, not by widget instance and not by a singleton "current
input form" assumption.

#### 5. MCP elicitation already uses the same UI lane

Current file:

- `lib/src/features/chat/application/transcript_request_policy.dart`

MCP elicitation requests already appear as pending user-input requests and
currently fall back to a single `response` field when no question list is
available.

That fallback must move into the shared presenter. It should not remain a
widget-only special case.

#### 6. Before slice 2, tests proved rendering more than ownership

At that point the tests proved that Flutter could render and submit the current
card, but they did not yet prove:

- request-form ownership above the card
- request-keyed draft persistence
- elicitation fallback field modeling
- submission lifecycle behavior such as duplicate-submit prevention

Slice 2 added the widget-level ownership coverage. Slice 3 still needs the
remaining app-level runtime verification before native parity work becomes
credible.

## Phase 3 Slice Breakdown

Phase 3 is intentionally split into 3 slices.

### Slice 1: Shared request contract

This slice is complete on this branch.

Slice 1 covers:

- `PendingUserInputDraft`
- `PendingUserInputFormState`
- `PendingUserInputContract`
- `PendingUserInputPresenter`
- presenter-focused tests for:
  - question-to-field mapping
  - option mapping
  - elicitation fallback field derivation
  - answer normalization
  - resolved and submitting state

Slice 1 explicitly does not cover:

- moving form state ownership above the card
- refactoring `UserInputRequestCard`
- runtime path changes

Slice 1 completed scope:

- `PendingUserInputDraft`
- `PendingUserInputFormState`
- `PendingUserInputContract`
- `PendingUserInputPresenter`
- presenter-focused tests for:
  - question-to-field mapping
  - option mapping
  - elicitation fallback field derivation
  - answer normalization
  - resolved and submitting state

### Slice 2: Request-state host and card refactor

This slice is complete on this branch.

Slice 2 covers:

- request state ownership above the card keyed by `requestId`
- routing the shared request contract into transcript rendering
- reducing `UserInputRequestCard` to renderer and input plumbing
- preserving pending request drafts across transcript rebuilds and movement
- pruning stale request form state when a request disappears from the active
  pending set
- widget coverage for:
  - submit flow through the shared draft host
  - option-chip updates through the shared draft host
  - request replacement by `requestId`
  - draft persistence across transcript movement

### Slice 3: Runtime path verification

This slice is complete on this branch.

Slice 3 covers:

- app-level verification that the shared request contract still submits through
  the existing controller path
- MCP elicitation path coverage
- any remaining end-to-end request lifecycle checks not already covered by
  slice 2

## Best Upgrade Path For Phase 3

The best Phase 3 path is to extract a request-specific presentation seam without
pretending to solve every transcript card at once.

### Recommended shared pieces

Add the following shared presentation components:

- `PendingUserInputDraft`
- `PendingUserInputFormState`
- `PendingUserInputContract`
- `PendingUserInputPresenter`

Add one request-form host above the card layer that owns request state by
`requestId`.

That host can live alongside the existing chat screen presentation host for
now. It should be treated as presentation-state ownership, not as a Flutter
widget detail.

### Recommended integration path

1. Keep `ChatSessionController` as the source of truth for pending requests and
   remote submission.
2. Add a request-keyed form-state host above transcript cards.
3. Have a presenter derive one request contract from:
   - `CodexUserInputRequestBlock` or
     `CodexSessionPendingUserInputRequest`
   - request-local form state
   - request-local submission state
4. Thread that contract into transcript rendering for user-input request items.
5. Reduce `UserInputRequestCard` to Flutter controller/focus plumbing and
   rendering.

### Why this is the best path

- It removes the real behavior owner from the widget.
- It does not force a full transcript-card redesign in the same slice.
- It preserves the current controller and transport boundaries.
- It gives native parity one request contract instead of two renderer-specific
  form implementations.

## Phase 3 Execution Spec

### Scope

Phase 3 must extract the following into shared presentation code:

- one request draft model storing current answers by field ID
- one request form-state model storing:
  - the draft
  - validation visibility, if any
  - submission lifecycle state
- one request contract owning:
  - request metadata
  - question-derived field descriptors
  - current answers
  - option descriptors including labels and descriptions
  - secret-field behavior
  - fallback single-response field behavior
  - resolved/read-only state
  - submit enablement
  - normalized submit payload
- one presenter deriving the full contract from:
  - the pending request block or request state
  - request-local form state

### Explicit Non-Goals

Phase 3 must not:

- redesign all transcript cards
- introduce Apple-native rendering
- invent validation rules that do not exist in the runtime model
- change the transport payload shape away from `Map<String, List<String>>`
- broaden the visible transcript behavior from primary pending request to
  multiple simultaneous input cards unless requested separately
- build a generic app-wide form framework

### Required Ownership Boundary

After Phase 3:

- `UserInputRequestCard` may still own Flutter `TextEditingController`s, focus,
  and layout mechanics
- `UserInputRequestCard` must not remain the owner of:
  - draft answer state
  - answer resynchronization rules
  - fallback field creation
  - option selection semantics
  - submit payload construction
  - submit enablement
  - duplicate-submit prevention

Those behaviors must live in the shared request draft/state/presenter path.

### Required Semantics To Preserve

Until the runtime model becomes richer, Phase 3 should preserve these current
product semantics explicitly:

- option selection uses the option label as the answer value
- answers are submitted as `Map<String, List<String>>`
- MCP elicitation without questions is represented as a single `response` field
- secret questions remain obscured in the renderer
- resolved requests remain visible as read-only submitted content

### Submission Lifecycle Recommendation

Phase 3 should include a shared request-local submission state such as:

- idle
- submitting

This is the correct time to add duplicate-submit prevention. Leaving submission
lifecycle undefined would force each renderer to rediscover it later.

### Request State Ownership Recommendation

The request form state must be stored by `requestId`, not by widget identity.

That state store must be able to:

- initialize draft state when a pending request first appears
- preserve draft state across transcript rebuilds and item movement
- drop stale form state when the request resolves or disappears from the pending
  set

## Phase 3 Exit Criteria

Phase 3 is complete only when all of the following are true:

- the user-input card renders from one shared request contract
- the card no longer derives field shape or answer payloads from the raw block
- the fallback single-response field for elicitation is owned by the presenter
- draft state survives widget rebuilds because it is owned above the card by
  `requestId`
- submit enablement and submission lifecycle are modeled outside the widget
- `ChatSessionController.submitUserInput` remains the only owner of transport
  submission behavior

## Phase 3 Verification Plan

Phase 3 verification must include:

- presenter tests for:
  - question-to-field mapping
  - option descriptor mapping
  - fallback elicitation field derivation
  - answer normalization
  - resolved/read-only state
  - submit enablement and submission lifecycle
- widget tests proving:
  - the card renders from the shared contract
  - local text edits round-trip through the shared request-state host
  - option taps update shared draft state rather than widget-local payload
    assembly
- app-level tests proving:
  - standard tool user-input requests still submit through the app-server client
  - MCP elicitation requests still resolve through the existing controller
    transport path once UI coverage is added

## What Comes After Phase 3

### Phase 4

Tighten the remaining transcript-card and overlay seams that still live inside
Flutter renderers, especially:

- changed-file diff ownership
- transcript item contract shape below the screen level
- transcript follow behavior if it needs renderer parity

### Phase 5

Introduce the first root architectural adapter once the remaining shared
contracts are in place.

### Phase 6

Begin Apple-native glass work only after the above contracts and adapter
boundaries are stable.

The best first native candidates are still:

- connection settings sheet
- composer
- top-level app chrome

The transcript feed should remain Flutter-owned until the lower-level transcript
contracts are more stable and interaction tradeoffs are better understood.

## Minimum Outcome Required Before Any Glass Work

Before Apple-native glass work begins, this repo must have:

- one screen-level presentation contract for chat
- one transcript-level contract that owns pending request placement
- one settings form contract
- one user-input request contract
- overlay intents/effects for top-level surfaces
- one presenter/mapping layer that derives those contracts from raw top-level
  app state
- one chat renderer host that consumes those contracts and executes effects
- tests proving ownership for:
  - pending request placement
  - settings launch effects
  - settings form behavior
  - user-input request form behavior

## Verification Strategy

### Presenter and unit tests

Add tests that assert:

- screen contracts derived from controller state remain stable
- settings contracts remain stable
- user-input request contracts derive field shape, fallback behavior, and submit
  payloads correctly

### Widget tests

Keep Flutter widget tests, but verify that Flutter renders and updates from the
shared contracts instead of owning the behavior directly.

### App-level parity tests

Before introducing native renderers, verify that the Flutter renderer is fully
driven by the extracted contracts for the surfaces in scope.

## Definition Of Done For The Prep Step

The prep step is done when:

- top-level chat UI policy is represented in shared presentation contracts
- settings and user-input flows have shared form descriptors and state ownership
- pending request placement is an explicit contract
- overlay presentation is modeled as intents and effects where needed above the
  renderer layer
- Flutter acts as one renderer over those contracts
- tests verify ownership and placement behavior, not only rendered text

The prep step is not done if the code merely looks more abstract while Flutter
still owns the real product decisions.

The prep step is also not done if any new presentation seam leaves unresolved
split ownership that will have to be unwound before native rendering can adopt
it honestly.

Only after that point is the codebase ready for a root architectural adapter.
Only after that point should Apple-native glass work begin.
