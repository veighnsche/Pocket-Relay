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
- Phase 4, transcript card and overlay seam tightening: completed on this
  branch
- Phase 5, transcript surface parity and pending-request placement: completed
  on this branch
- Phase 6, root architectural adapter: completed on this branch
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
- Pending pinned approval and user-input request shaping is now owned by shared
  presentation request contracts and projectors rather than runtime-shaped
  transcript blocks.
- Pending-request selection rules and pinned ordering are now routed through a
  shared presentation placement projector and surface contract seam.
- Active pending user-input request IDs are now explicit transcript-surface
  contract data instead of being rediscovered inside `TranscriptList`.
- Pending-request promotion, non-broadening behavior, and pending-input draft
  continuity are now covered at projector, widget, and app levels.
- Changed-files rows and per-file diff sheets now render from shared contracts,
  with diff-sheet launch owned above the card widget.
- Transcript follow behavior is now modeled above `TranscriptList` and routed
  through a shared follow contract and host.
- Live composer draft ownership now sits above the Flutter renderer through a
  shared presentation draft host and screen-contract field instead of a
  screen-owned `TextEditingController`.
- The current Flutter chat UI now renders through an extracted
  `FlutterChatScreenRenderer` widget that consumes the shared screen contract
  and forwards callbacks back to the screen host.
- `PocketRelayApp` now routes through a root `ChatRootAdapter` host instead of
  jumping directly to `ChatScreen`.
- Top-level settings, changed-file diff, and snackbar execution now route
  through an adapter-owned `ChatRootOverlayDelegate`.
- Renderer ownership is now explicit for app chrome, transcript, composer, and
  settings overlay through `ChatRootRegionPolicy`, with all-Flutter as the
  current default path.
- Adapter-side renderer selection now routes through `ChatRootRendererDelegate`,
  and injected renderer-path tests prove the adapter still owns settings, diff,
  and send behavior.

These are the parts we should build on, not reopen.

## What Is Still Not Ready For Native Ownership

- Apple-native renderer implementations are still not started.
- Default iOS enablement is still not turned on at the app root.
- Top-level changed-file diff presentation still follows the Flutter transcript
  lane.
- The transcript feed is still intentionally Flutter-owned while the first
  native surfaces are cut.

## Next Active Work

Phase 6 is complete.

Phase 7 is now in progress on this branch.

The next thing to do is Phase 7 Slice 6:

- default iOS enablement and parity hardening

Reason:

- Slices 4 and 5 removed the remaining highest-visibility Material shell cues
  from the explicit iOS foundation path
- the last Phase 7 ownership gate is making that iOS path the default on
  iPhone without regressing the existing adapter and shared-contract behavior
- transcript ownership still needs to remain on the Flutter lane while the
  surrounding shell becomes Cupertino-first

## Phase 7 Start Checklist

Phase 7 is now started in a meaningful way. Slice 1 closed the shell-selection
and platform-policy foundation items below, and Slice 2 closed the settings
host/renderer split items. The remaining unchecked items are the structural
gates for later Phase 7 slices.

### Structural checklist

- the root adapter can select the outer screen shell, not only inject regions
  into `FlutterChatScreenRenderer`
- renderer policy can express a mixed iOS profile where:
  - app chrome is Cupertino
  - settings presentation is Cupertino
  - composer is Cupertino
  - transcript remains Flutter
- the current all-Flutter path remains explicit and testable
- settings state and submit plumbing live above `ConnectionSheet`
- Cupertino settings rendering can consume the same settings host and contract
  as the Material settings renderer
- top-level feedback for the iOS path is not hardwired to `SnackBar`

### Ownership checklist

- iOS shell selection is owned by `ChatRootAdapter`, not by widget-local
  `Theme.of(context).platform` branching deep in renderers
- settings validation, draft sync, auth-mode changes, toggle updates, and save
  payload construction are not duplicated across Material and Cupertino sheets
- composer draft ownership stays above both renderer paths
- transcript remains consumed through the shared transcript contract and is not
  reopened as part of the shell work

### Verification checklist

- tests prove the all-Flutter path still behaves the same after shell-selection
  refactoring
- tests prove the iOS path still routes settings, send, and top-level actions
  through adapter-owned callbacks
- tests prove the shared settings host drives both Material and Cupertino
  settings renderers with the same submit semantics
- tests prove transcript remains Flutter-owned under the mixed iOS renderer
  profile

Any remaining false item above is a blocker for the next Cupertino surface
slice, not a reason to treat Phase 7 itself as not started.

## Target Architecture

### Layer 1: Domain and application

Keep the reducer, policies, session state, app-server integration, and
controller-based flow as the source of truth for business behavior and remote
session state.

### Layer 2: Shared presentation contracts

The app should own shared presentation contracts for:

- top-level chat screen state
- transcript surface item placement and pending-request visibility
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

### Phase 4 Completed Scope

Phase 4 is complete and delivered:

- one transcript item contract layer below the screen contract
- one changed-files presentation contract and projector for file rows, summary
  stats, and per-file diff sheet content
- one screen-level effect boundary for changed-file diff opening
- one shared transcript follow contract and host above `TranscriptList`
- modeled follow requests for send, clear, and new-thread actions
- transcript-list rendering reduced to scroll geometry, viewport reporting, and
  card rendering over shared contracts
- projector, widget, and app-level coverage proving changed-files and
  follow-behavior ownership no longer originates in the renderer

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

## Phase 4 Deep Investigation

Phase 4 is the next migration phase:

- transcript card and overlay seam tightening

This section records the current Phase 4 investigation and the recommended
upgrade path.

### Findings

#### 1. Transcript items still have no real presentation contract below the screen level

Current files:

- `lib/src/features/chat/presentation/chat_screen_contract.dart`
- `lib/src/features/chat/presentation/chat_transcript_surface_projector.dart`

`ChatTranscriptItemContract` still just wraps a raw `CodexUiBlock`, and the
surface projector still maps blocks directly into `mainItems` and `pinnedItems`.

That means the transcript surface contract is still too thin to carry
renderer-neutral item behavior. Flutter still has to inspect block types later
and decide how each row should behave.

#### 2. `ConversationEntryCard` is still a Flutter-owned block-to-widget dispatcher

Current file:

- `lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart`

The transcript renderer still switches directly on raw block types. It also
still performs presentation shaping inside the renderer, most notably turning a
single `CodexWorkLogEntryBlock` into a synthetic `CodexWorkLogGroupBlock`
before rendering.

That is exactly the kind of view shaping that should move out of Flutter before
a second renderer is added.

#### 3. `ChangedFilesCard` still owns both view shaping and overlay lifecycle

Current file:

- `lib/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart`

The changed-files surface still owns:

- unified diff parsing into patch objects
- file-row display shaping and stat fallback logic
- diff-line classification for display
- diff preview truncation state
- `showModalBottomSheet(...)` ownership for the per-file diff sheet

This is the largest remaining card-level ownership gap after Phase 3.

#### 4. Diff semantics are duplicated between application code and widget code

Current files:

- `lib/src/features/chat/application/transcript_changed_files_parser.dart`
- `lib/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart`

The application layer already parses and synthesizes changed-file data for
`CodexChangedFilesBlock`, while `ChangedFilesCard` performs another widget-local
diff parse for file patch matching, per-file stats fallback, rename handling,
and display lines.

That duplication is manageable today, but it is the wrong ownership model for
future renderer parity. If left in place, native diff presentation would need
to reimplement widget-local logic that should instead be shared once.

#### 5. Transcript follow policy is still widget-local

Current files:

- `lib/src/features/chat/presentation/widgets/transcript/transcript_list.dart`
- `lib/src/features/chat/presentation/chat_screen.dart`

`TranscriptList` still owns:

- the follow flag
- the near-bottom heuristic
- scroll animation policy
- the translation from user scrolling into follow enablement

`ChatScreen` can only request follow imperatively through
`TranscriptListController.requestFollow()`.

That is acceptable while Flutter owns the feed, but it is still hidden behavior
at the widget layer rather than an explicit transcript behavior contract.

#### 6. Existing tests prove behavior, but not shared ownership, for the remaining Phase 4 seams

Current files:

- `test/codex_ui_block_card_test.dart`
- `test/chat_screen_app_server_test.dart`

The current tests are good at proving that:

- changed-files rows render correctly
- diff sheets open and preview correctly
- scrolling does not yank the transcript while scrolled up

What they do not yet prove is that:

- changed-files rows and diff sheets are derived from a shared presentation contract
- diff-sheet opening is a modeled effect boundary instead of a widget-local modal call
- transcript follow behavior is driven by explicit presentation policy

So Phase 4 needs to add ownership-oriented tests, not just preserve rendering
tests.

## Best Upgrade Path For Phase 4

The best Phase 4 path is not to start by patching `ChangedFilesCard` in place.

The correct order is:

1. introduce a real transcript item contract layer below the screen contract
2. move changed-files presentation and diff-sheet launch onto that layer
3. only then extract transcript follow behavior if it still blocks renderer parity

That order matters because changed-files ownership should not become another
one-off exception hanging off a transcript surface that still only carries raw
blocks.

## Phase 4 Slice Breakdown

Phase 4 should be split into 3 slices.

### Slice 1: Transcript item contract foundation

This slice is complete on this branch.

Slice 1 covers:

- replacing `ChatTranscriptItemContract(block: ...)` with a real transcript item
  contract hierarchy
- moving transcript item shaping out of `ConversationEntryCard`
- moving renderer-facing item classification out of the raw block switch
- preserving current visible transcript behavior without broadening product scope
- moving work-log entry normalization into the transcript item projector
- projector coverage proving work-log shaping no longer originates in the
  renderer

This slice is the foundation. Without it, changed-files extraction risks
becoming another special-case seam instead of the start of a coherent
transcript item layer.

### Slice 2: Changed-files contract and diff overlay boundary

This slice is complete on this branch.

Slice 2 covers:

- one renderer-neutral changed-files item contract
- file-row contracts with display labels, availability state, and summary stats
- one diff-sheet contract for the selected file patch
- a modeled event/effect boundary for opening a diff sheet from a transcript row
- removing widget-local diff parsing and sheet launching from `ChangedFilesCard`

This slice removed the largest remaining card-local ownership gap in the
transcript.

### Slice 3: Transcript follow behavior contract

This slice is complete on this branch.

Slice 3 covers:

- one explicit transcript follow behavior contract or host
- modeled follow requests from screen actions such as send, clear, and new thread
- explicit auto-follow eligibility derived from transcript behavior policy
- keeping `TranscriptList` as scroll/render plumbing rather than the source of
  follow rules

This slice is structurally important, but it comes after the transcript item
contract and changed-files ownership work because the transcript feed is still
Flutter-owned for now.

## Phase 4 Execution Spec

### Scope

Phase 4 must extract the following into shared presentation code:

- one transcript item contract layer below the screen contract
- one changed-files presentation contract owning:
  - header stats
  - file rows
  - row availability for diff opening
  - per-file diff sheet content
  - preview/full-diff state inputs if that state remains in Flutter for now
- one overlay or event boundary for opening changed-file diffs
- one transcript follow behavior contract or host if follow remains in scope for
  renderer parity

### Explicit Non-Goals

Phase 4 must not:

- redesign every transcript card in one pass
- broaden pending request visibility from the current product behavior unless
  that behavior is explicitly requested
- move the whole transcript feed to native ownership
- introduce Apple-native glass components
- treat a one-off changed-files presenter as sufficient if transcript items
  still fundamentally depend on raw block dispatch

### Required Ownership Boundary

After Phase 4:

- `ConversationEntryCard` may still be a Flutter renderer entry point
- `ConversationEntryCard` must no longer be the source of transcript item
  shaping rules
- `ChangedFilesCard` may still own Flutter layout and local preview toggle state
  if needed
- `ChangedFilesCard` must not remain the owner of:
  - diff parsing
  - file-row contract derivation
  - per-file diff selection semantics
  - diff-sheet launch ownership
- `TranscriptList` may still own the `ScrollController`
- `TranscriptList` must not remain the only owner of follow policy if follow is
  kept in Phase 4 scope

### Recommended First Slice

The recommended first Phase 4 slice is:

- transcript item contract foundation

Reason:

- it unlocks changed-files extraction without introducing a new special-case
  ownership path
- it moves existing renderer-only shaping such as work-log entry normalization
  out of Flutter
- it gives the transcript surface a place to carry future changed-files and
  overlay contracts cleanly

## Phase 4 Exit Criteria

Phase 4 is complete only when all of the following are true:

- transcript items are no longer represented only as raw `CodexUiBlock`
  wrappers
- transcript item shaping is owned above Flutter renderer code
- changed-files rows and diff-sheet content are derived from shared presentation
  contracts
- changed-file diff opening is modeled above the card widget
- transcript follow behavior is either explicitly modeled or deliberately
  documented as out of scope for a later phase with a reason that does not
  create duplicate renderer work

## Phase 4 Verification Plan

Phase 4 verification must include:

- presenter or projector tests for transcript item contract derivation
- tests proving work-log and changed-files shaping no longer originates in the
  renderer
- widget tests proving changed-files rows and diff sheets render from shared
  contracts
- tests proving diff opening is routed through the new boundary instead of a
  widget-local `showModalBottomSheet(...)`
- transcript behavior tests for follow policy if slice 3 is included

## What Comes After Phase 4

### Phase 5

Make pending-request visibility and pinned placement a fully explicit
presentation-owned transcript surface contract.

## Phase 5 Deep Investigation

Phase 5 is the next migration phase:

- transcript surface parity and pending-request placement

This section records the current Phase 5 investigation and the recommended
upgrade path.

### Findings

#### 1. Pending-request visibility originally came from runtime-state convenience getters

Current files:

- `lib/src/features/chat/models/codex_session_state.dart`
- `lib/src/features/chat/presentation/chat_transcript_surface_projector.dart`

Before slices 2 through 5, `CodexSessionState` exposed:

- `primaryPendingApprovalRequest`
- `primaryPendingUserInputRequest`

Before slice 3, `ChatTranscriptSurfaceProjector` used those getters to decide
which pending requests appeared in `pinnedItems`.

That means the transcript surface still does not own one of its most important
remaining product decisions:

- which pending requests are visible
- which pending requests are suppressed
- why those requests appear in the pinned region at all

As long as that policy remains hidden in runtime-state convenience getters, the
transcript surface contract is still incomplete for adapter and native-parity
work.

#### 2. The current placement semantics are real product behavior, but they are implicit

Current file:

- `lib/src/features/chat/models/codex_session_state.dart`

`_firstPendingBlock(...)` sorts candidate blocks by `createdAt` ascending and
returns the first entry.

Combined with the current surface projector, the visible behavior today is:

- at most one pending approval request is visible
- at most one pending user-input request is visible
- the oldest request wins within each type
- pinned-region ordering is approval first, then user-input

Those are product semantics, not implementation trivia. If Phase 5 preserves
them, it must preserve them explicitly in presentation code.

#### 3. Slice 1 closed the pinned-request shaping gap, but not the placement gap

Current file:

- `lib/src/features/chat/presentation/chat_request_projector.dart`

Slice 1 moved pinned pending-request shaping out of runtime state and into a
presentation-owned request projector plus request contracts.

That means title/body derivation for pending pinned requests is no longer the
open ownership problem.

The remaining Phase 5 problem is narrower:

- which pending requests are visible
- how those visible requests are selected and ordered in the pinned region

#### 4. Pending user-input form activation still depends on widget-side item scanning

Current files:

- `lib/src/features/chat/presentation/widgets/transcript/transcript_list.dart`
- `lib/src/features/chat/presentation/pending_user_input_form_scope.dart`

`TranscriptList` still discovers active pending user-input request IDs by
scanning `mainItems` and `pinnedItems`, then passes that derived set into
`PendingUserInputFormScope`.

That is a smaller gap than the selection problem, but it is the same class of
problem:

- the widget layer is rediscovering transcript-surface policy from rendered
  items
- request-form lifetime is not yet driven by one explicit placement contract

Phase 5 should decide whether active pending user-input request IDs are part of
the transcript surface contract. If they are not, the document should say why.
If they are, `TranscriptList` should stop deriving them locally.

#### 5. Live request history now has an artifact path, but pending placement still does not

Current files:

- `lib/src/features/chat/models/codex_session_state.dart`
- `lib/src/features/chat/application/transcript_request_policy.dart`

The latest `master` changes moved live transcript projection onto explicit turn
artifacts.

That matters for Phase 5 because resolved request history now already has a
clear runtime path:

- pending request state still lives in active-turn pending maps
- resolved request events are converted into resolved request blocks
- those resolved request blocks are inserted or replaced through the active-turn
  artifact path and later appear in transcript history

So Phase 5 does not need to invent request lifetime or transcript-history
placement from scratch.

Phase 5 still must remove the remaining hidden seam:

- selection of which pending requests are visible while unresolved
- pinned-region shaping for those visible pending requests
- any request-activation data the pending-input form host depends on

#### 6. Existing tests prove one mixed pinned pair, not placement ownership

Current files:

- `test/chat_screen_presentation_test.dart`
- `test/codex_session_reducer_test.dart`

Current tests prove:

- pending approvals and pending user-input requests can exist in runtime state
- one approval and one user-input item can appear in `pinnedItems`
- resolved request history remains visible in the transcript after resolution

Current tests do not yet prove:

- which request wins when multiple approvals are pending
- which request wins when multiple user-input requests are pending
- whether pinned ordering is presentation-owned instead of inherited from
  runtime convenience getters
- whether visible pending-user-input IDs for the form scope derive from the
  same contract as pinned placement
- whether resolving the visible request promotes the next correct request

So Phase 5 must add ownership-oriented placement tests, not just preserve the
current one-approval-plus-one-input rendering check.

#### 7. The root adapter should not be introduced around this still-hidden transcript seam

Current files:

- `lib/src/features/chat/presentation/chat_screen_contract.dart`
- `lib/src/features/chat/presentation/chat_transcript_surface_projector.dart`

The transcript surface is now substantially cleaner after Phase 4, but it still
does not explicitly own pending-request placement.

If the root architectural adapter is introduced before this seam is fixed, the
adapter boundary would freeze an incomplete transcript contract into the next
architecture layer.

That would make later native parity harder, not easier.

## Best Upgrade Path For Phase 5

The best Phase 5 path is not to start by adding the root architectural adapter.

The correct order is:

1. extract presentation-owned pending-request shaping primitives below the chat
   screen contract
2. define a presentation-owned placement projector over raw pending maps
3. integrate that placement projector into the transcript surface contract
4. thread any request-activation data needed by the pending-input form host
   through that same surface contract
5. clean up remaining runtime and controller convenience seams
6. only then begin root architectural adapter work

That order matters because the transcript surface still has one last important
hidden behavior seam.

The `master` merge narrows the scope, but it does not change the order:

- keep the active-turn artifact model for resolved request history
- focus Phase 5 on unresolved pending-request selection, pinned placement, and
  request-activation ownership

## Phase 5 Slice Breakdown

Phase 5 should be split into 6 slices.

Each slice should be independently landable and should leave the transcript
surface in a coherent intermediate state.

### Slice 1: Pending-request presentation primitives

Slice 1 is completed on this branch.

Slice 1 covered:

- one presentation-owned pending-request contract or projector input model
- extraction of pinned pending-request shaping from
  runtime-state helpers into presentation projectors
- explicit renderer-neutral shaping for approval and user-input pending blocks
- tests proving the new presentation-owned shaping matches current card inputs
- preserving the current active-turn artifact path for resolved request history

This slice did not change placement behavior. It only moved pending
pinned-request representation above runtime state.

### Slice 2: Placement rule projector

Slice 2 is completed on this branch.

Slice 2 covered:

- one presentation-owned pending-request placement projector
- explicit current-behavior selection rules for pending approvals and pending
  user-input requests
- explicit pinned-region ordering rules
- tests for multiple pending requests of the same type
- tests for mixed approval-plus-input ordering

This slice made the current placement semantics explicit:

- oldest approval wins
- oldest user-input request wins
- approval appears before user-input in the pinned region
- at most one item of each type is visible unless broader behavior is requested

### Slice 3: Transcript surface integration

Slice 3 is completed on this branch.

Slice 3 covered:

- threading the new placement projector through
  `ChatTranscriptSurfaceProjector`
- replacing transcript-surface dependence on runtime convenience getters with
  the presentation placement projector
- preserving current empty-state behavior and pinned-region rendering inputs
- presenter or projector tests proving the transcript surface now consumes the
  placement projector instead of runtime convenience getters

This slice is where the transcript surface stopped inheriting hidden pending
placement behavior from runtime state.

### Slice 4: Pending-input activation ownership

Slice 4 is completed on this branch.

Slice 4 covered:

- deciding whether visible pending-user-input request IDs belong in the surface
  contract
- routing `PendingUserInputFormScope` activation from the explicit surface
  contract instead of `TranscriptList` item scanning
- widget tests proving pending-input draft lifetime follows explicit contract
  data rather than renderer-side rediscovery

This slice finished ownership of pending-input activation at the same boundary
as pending placement.

### Slice 5: Runtime and controller seam cleanup

Slice 5 is completed on this branch.

Slice 5 covered:

- cleanup of leftover runtime or controller convenience APIs that still encode
  presentation placement policy
- removing `primaryPendingApprovalRequest`,
  `primaryPendingUserInputRequest`, and any equivalent controller-level
  shortcuts from presentation-facing usage
- ensuring runtime state keeps only raw pending request data, timestamps, and
  resolved-history insertion responsibilities

This slice left the presentation layer dependent on explicit contracts, not
convenience getters.

### Slice 6: Parity hardening and promotion coverage

This slice is complete on this branch.

Slice 6 delivered:

- ownership-oriented widget and app-level tests for placement promotion when the
  visible request resolves
- tests proving the next correct pending request becomes visible after the
  current visible request resolves
- verification that pinned placement does not broaden unexpectedly under
  multiple pending requests
- verification that the pending-input draft host still behaves correctly under
  the explicit placement contract
- deterministic same-timestamp pending-request selection by preserving request
  insertion order
- no-op submission cleanup when a pruned pending-input form entry is already
  gone

This slice completes Phase 5 and is the gate before Phase 6 root adapter work.

## Phase 5 Execution Spec

### Scope

Phase 5 must extract the following into shared presentation code:

- one pending-request placement contract or projector owning:
  - visible pending approval selection
  - visible pending user-input selection
  - pinned-region ordering
  - pinned request item shaping for the transcript surface
  - any visible pending-user-input activation IDs needed by the shared request
    form host
- one transcript-surface integration path that consumes that contract instead of
  runtime-state primary-request getters

### Explicit Non-Goals

Phase 5 must not:

- broaden the visible pending-request surface beyond current product behavior
  unless explicitly requested
- redesign approval and user-input cards
- rework resolved request lifetime or the active-turn artifact model
- move the entire transcript feed to native ownership
- introduce the root architectural adapter before the placement seam is fixed
- start Apple-native glass rendering work

### Required Ownership Boundary

After Phase 5:

- `CodexSessionState` may still store pending request maps and timestamps
- `TranscriptRequestPolicy` may still own resolved-request history insertion
  through the active-turn artifact path
- `CodexSessionState` must not remain the owner of:
  - which pending requests are visible in the transcript surface
  - which pending requests are pinned
  - pinned ordering between approvals and user-input items
  - renderer-facing pinned request shaping
- `ChatTranscriptSurfaceProjector` may still assemble the overall transcript
  surface contract
- `ChatTranscriptSurfaceProjector` must do so through a presentation-owned
  placement contract or projector instead of raw runtime convenience getters
- `TranscriptList` may still host the scroll view and pinned-region layout
- `TranscriptList` must not remain the source of active pending-user-input ID
  derivation if that data is part of the transcript surface contract

### Required Semantics To Preserve

Unless broader behavior is explicitly requested, Phase 5 should preserve:

- at most one visible pending approval request
- at most one visible pending user-input request
- oldest request wins within each type
- pinned-region order remains approval first, then user-input
- resolved requests leave the pinned region and remain visible in the transcript
  as resolved entries

## Phase 5 Exit Criteria

Phase 5 is complete only when all of the following are true:

- pending-request visibility is derived in presentation code rather than runtime
  convenience getters
- pinned request item shaping is owned above the runtime model
- transcript surface placement rules are explicit and test-covered
- visible pending-user-input activation is either explicit in the surface
  contract or deliberately documented as out of scope with a reason
- the root architectural adapter can start without inheriting hidden
  pending-placement behavior

## Phase 5 Verification Plan

Phase 5 verification must include:

- projector or presenter tests proving:
  - multiple pending approvals select the correct visible item
  - multiple pending user-input requests select the correct visible item
  - mixed approval-plus-input ordering remains explicit
  - visible pending-user-input activation IDs match the placement contract if
    that data is in scope
- widget tests proving the transcript renderer consumes the explicit placement
  contract instead of rediscovering placement rules locally
- widget or integration tests proving pending-input draft state remains correct
  as visible pending requests change
- app-level tests proving that when the visible pending request resolves, the
  next correct request becomes visible without broadening the UI unexpectedly

Phase 5 is complete.

Reason:

- the last transcript-surface ownership gap was closing parity and promotion
  coverage around the explicit placement seam
- Slice 6 delivered that coverage and hardened the remaining same-timestamp and
  pruned-form-state edge cases
- later adapter work can now inherit an explicit transcript boundary instead of
  partially implicit pending-request behavior

### Phase 6

Introduce the first root architectural adapter once the remaining shared
contracts, including Phase 5 transcript placement work, are stable.

## Phase 6 Deep Investigation

Phase 6 is the next migration phase:

- root architectural adapter

This section records the current source-level investigation and the recommended
upgrade path.

### Findings

#### 1. `PocketRelayApp` now has a bootstrap-to-adapter seam

Current file:

- `lib/src/app.dart`

`PocketRelayApp` currently owns:

- dependency binding for `CodexProfileStore` and `CodexAppServerClient`
- saved-profile loading
- direct `home: ChatRootAdapter(...)` selection once bootstrap completes

That means the first app-level ownership seam now exists, but region selection
still begins one level down inside the adapter.

#### 2. `ChatRootAdapter` now combines application host plus adapter delegates

Current file:

- `lib/src/features/chat/presentation/chat_root_adapter.dart`

`ChatRootAdapter` currently owns:

- `ChatSessionController` lifecycle
- `ChatTranscriptFollowHost` lifecycle
- screen effect subscription from controller snackbar messages
- action dispatch between contract actions and controller methods
- top-level overlay delegation through `ChatRootOverlayDelegate`
- region selection through `ChatRootRegionPolicy`
- host wiring into the extracted Flutter renderer regions

That means the adapter seam now owns the right categories of work. Phase 6 is
complete, and the next work is using that seam for the first native regions.

#### 3. Composer state is now ready for adapter ownership

Current files:

- `lib/src/features/chat/presentation/chat_screen_contract.dart`
- `lib/src/features/chat/presentation/chat_composer_draft.dart`
- `lib/src/features/chat/presentation/chat_composer_draft_host.dart`
- `lib/src/features/chat/presentation/chat_screen_presenter.dart`
- `lib/src/features/chat/presentation/chat_root_adapter.dart`
- `lib/src/features/chat/presentation/widgets/chat_composer.dart`

Before Slice 1, `ChatComposerContract` already owned:

- busy state
- enabled/disabled state
- primary action kind
- placeholder text

Slice 1 moved the live draft text into a shared presentation draft host and
screen-contract field, while leaving only local controller syncing inside the
Flutter composer renderer.

That blocker is now removed. Slice 2 extracted the pure Flutter screen
renderer away from controller and overlay hosting, Slice 3 moved the host
ownership into the adapter, Slice 4 added explicit overlay and region
delegation, and Slice 5 hardened parity through injected renderer tests. The
next work is Phase 7 native rendering.

#### 4. Overlay payloads are ready, but overlay execution is still Flutter-hardwired

Current files:

- `lib/src/features/chat/presentation/chat_screen_effect.dart`
- `lib/src/features/chat/presentation/chat_screen_effect_mapper.dart`
- `lib/src/features/chat/presentation/chat_root_adapter.dart`

The presentation layer already models:

- settings launch payloads
- changed-file diff launch payloads
- snackbar effects

The default execution still uses Flutter implementations, but it now happens
behind `ChatRootOverlayDelegate`.

That is a good Phase 6 target because the product semantics are already mapped;
only adapter ownership is missing.

#### 5. The first adapter should be region-based, not a full native screen swap

Current files:

- `lib/src/features/chat/presentation/chat_screen_contract.dart`
- `lib/src/features/settings/presentation/connection_settings_contract.dart`
- `lib/src/features/chat/presentation/pending_user_input_contract.dart`

The current contracts are strongest for:

- top-level app chrome
- composer action state
- connection settings sheet content
- pending request and transcript placement

The transcript feed should still remain Flutter-owned for now, but the adapter
should make it possible to keep transcript rendering in Flutter while later
swapping app chrome, composer, and settings surfaces.

#### 6. Current tests now cover injected selection and adapter parity

Current files:

- `test/widget_test.dart`
- `test/chat_screen_app_server_test.dart`
- `test/chat_screen_renderer_test.dart`
- `test/chat_root_adapter_test.dart`

Current tests now prove:

- that `PocketRelayApp` routes through `ChatRootAdapter`
- that the extracted Flutter renderer still forwards host callbacks correctly
- that the all-Flutter adapter path preserves current behavior
- that settings, changed-file diff, and snackbar execution route through the
  adapter overlay delegate
- that an injected renderer path still routes settings, changed-file diffs, and
  send behavior through adapter-owned callbacks

That is enough to treat the root adapter seam as stable for the first native
Phase 7 cuts.

## Best Upgrade Path For Phase 6

The best Phase 6 path is not to start by adding a native renderer.

The correct order is:

1. move live composer draft ownership out of Flutter controller state
2. extract a pure Flutter chat renderer from `ChatScreen`
3. introduce the first root adapter between `PocketRelayApp` and the active
   renderer
4. move top-level overlay execution and region selection into that adapter
5. harden adapter ownership with app and widget tests
6. only then begin Phase 7 native rendering work

Why this is the best path:

- it removes the last major Flutter-only input primitive from the future
  adapter seam
- it keeps transcript ownership stable while still creating a real mixed-renderer
  boundary
- it avoids adding a nominal adapter that still depends on `ChatScreen`
  internals for lifecycle or effects

## Phase 6 Slice Breakdown

Phase 6 should be split into 5 slices.

### Slice 1: Composer draft and adapter-host readiness

This slice is complete on this branch.

Slice 1 delivered:

- moving live composer draft text out of `_composerController`
- introducing a renderer-neutral composer draft model or equivalent
  adapter-owned state
- preserving current semantics:
  - trim-before-send
  - clear after successful send
  - keep draft after failed send
  - disable input while busy
- threading composer draft text through the shared screen contract
- reducing `ChatComposer` to local controller syncing over external draft state
- tests proving the draft lifecycle is owned above the Flutter renderer

This slice is the gate before the renderer extraction, because the adapter
should not own a Flutter `TextEditingController`.

### Slice 2: Pure Flutter screen renderer extraction

This slice is complete on this branch.

Slice 2 delivered:

- extracting `FlutterChatScreenRenderer` from `ChatScreen`
- reducing that renderer to:
  - shared screen-contract rendering
  - local Flutter composer controller syncing only
  - callback forwarding for screen actions, transcript actions, and composer
    actions
- removing controller lifecycle, snackbar subscription, and overlay execution
  ownership from the renderer widget itself
- widget coverage proving the extracted renderer forwards host callbacks
- app coverage proving the current shell renders through the extracted Flutter
  renderer path

This slice creates the renderer object that the first adapter can host.

### Slice 3: Root adapter introduction

This slice is complete on this branch.

Slice 3 delivered:

- replacing the direct `PocketRelayApp -> ChatScreen` handoff with
  `PocketRelayApp -> ChatRootAdapter`
- moving ownership of:
  - `ChatSessionController`
  - `ChatTranscriptFollowHost`
  - composer draft state
  - screen contract derivation
  - action dispatch
  - top-level effect routing
  into `ChatRootAdapter`
- preserving all-Flutter parity by having the adapter host
  `FlutterChatScreenRenderer`
- keeping `ChatScreen` as a compatibility wrapper instead of the app entry seam

This is the slice where the root architectural adapter becomes real.

### Slice 4: Overlay and region delegation

This slice is complete on this branch.

Slice 4 delivered:

- moving settings-sheet, changed-file-diff, and snackbar execution behind
  `ChatRootOverlayDelegate`
- making renderer-region ownership explicit for:
  - app chrome
  - composer
  - settings overlay
  - transcript
  through `ChatRootRegionPolicy`
- preserving transcript as Flutter-owned in the default all-Flutter adapter
  policy
- adding adapter tests that prove settings, snackbar, and changed-file diff
  paths route through the overlay delegate

This slice is where the adapter starts selecting or embedding renderer
ownership for major regions instead of simply wrapping one full-screen widget.

### Slice 5: Adapter parity hardening

This slice is complete on this branch.

Slice 5 delivered:

- ownership-oriented tests proving `PocketRelayApp` depends on the adapter
  rather than `ChatScreen` directly
- tests proving renderer callbacks do not own controller or overlay behavior
- tests proving the all-Flutter adapter mode preserves current behavior
- an injected renderer path through `ChatRootRendererDelegate` proving the
  adapter owns selection rather than the renderer tree

This slice completes Phase 6 and is the gate before Phase 7 glass work.

## Phase 6 Execution Spec

### Scope

Phase 6 must introduce:

- one root adapter host between app bootstrap and the active chat renderer
- one explicit renderer path for the current Flutter screen
- adapter-owned composer draft state
- adapter-owned top-level effect execution
- explicit region ownership for the first major surfaces the adapter will
  eventually switch or embed

### Explicit Non-Goals

Phase 6 must not:

- introduce Apple-native rendering yet
- move the whole transcript feed out of Flutter
- redesign the chat UI
- reopen transcript placement or changed-files ownership
- rewrite `ChatSessionController` behavior as part of the adapter cut

### Required Ownership Boundary

After Phase 6:

- `PocketRelayApp` may still own dependency bootstrap and theming
- the root adapter must own:
  - chat host lifecycle
  - renderer selection
  - top-level effect execution
  - composer draft state
- the active Flutter renderer must not remain the owner of:
  - `ChatSessionController`
  - snackbar subscriptions
  - sheet launch execution
  - adapter-level renderer selection
- transcript rendering may remain Flutter-owned
- the transcript contract must stay shared and adapter-consumed

### Required Semantics To Preserve

Unless broader behavior is explicitly requested, Phase 6 should preserve:

- current chat screen behavior in all-Flutter mode
- current connection settings flow
- current changed-file diff opening flow
- current composer send/stop behavior
- current failed-send draft retention behavior

Phase 6 is now complete.

The next active phase is:

- Phase 7 Apple-native glass work

Reason:

- Slice 1 removed the main remaining Flutter-only input primitive from the
  adapter boundary
- Slice 2 extracted the pure Flutter renderer object the adapter can host
- Slice 3 introduced the adapter host itself
- Slice 4 moved overlay execution and region ownership behind explicit adapter
  delegates
- Slice 5 proved parity and adapter-owned selection with stronger ownership
  tests and an injected renderer path

### Phase 7

Begin Apple-native glass work only after the above contracts and adapter
boundaries are stable.

The best first native candidates are still:

- connection settings sheet
- composer
- top-level app chrome

The transcript feed should remain Flutter-owned until the lower-level transcript
contracts are more stable and interaction tradeoffs are better understood.

## Phase 7 Deep Investigation

Phase 7 is the next migration phase:

- Cupertino-first iPhone rendering over the shared presentation contracts

This section records the current Phase 7 investigation and the recommended
upgrade path after the completed Phase 1 through 6 prep work.

### Findings

#### 1. The current adapter can swap regions, but not the real screen shell

Current files:

- `lib/src/features/chat/presentation/chat_root_adapter.dart`
- `lib/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart`
- `lib/src/features/chat/presentation/chat_root_renderer_delegate.dart`

`ChatRootAdapter` already owns:

- session lifecycle
- draft and follow hosts
- effect execution
- region selection
- renderer delegate routing

But it still always builds the screen through `FlutterChatScreenRenderer`.

That renderer still owns the outer shell:

- `Scaffold`
- loading state container
- gradient page background
- top-level layout structure

So the current seam is not yet enough to render a genuinely iOS-first shell.
At the moment it can only inject alternate app-chrome, transcript, and composer
widgets into a Material screen host.

That is the first Phase 7 blocker.

#### 2. The current region policy cannot express an iOS renderer path yet

Current file:

- `lib/src/features/chat/presentation/chat_root_region_policy.dart`

`ChatRootRegionRenderer` currently has only one value:

- `flutter`

That means there is no explicit way to represent:

- Cupertino app chrome
- Cupertino composer
- Cupertino settings presentation
- a mixed profile where transcript stays Flutter while other surfaces become
  Cupertino

Phase 7 needs an explicit renderer-policy vocabulary for those cases rather
than burying iOS choices in ad hoc branching.

#### 3. The settings contract is ready, but the settings host is still Material-owned

Current files:

- `lib/src/features/settings/presentation/connection_sheet.dart`
- `lib/src/features/settings/presentation/connection_settings_contract.dart`
- `lib/src/features/settings/presentation/connection_settings_presenter.dart`

The good news:

- validation, field descriptors, toggle descriptors, and submit payloads are
  already renderer-neutral

The remaining issue:

- `ConnectionSheet` still owns local form state
- `ConnectionSheet` still owns `TextEditingController` creation and sync
- `ConnectionSheet` still owns auth-mode, toggle, and save event plumbing

That was good enough for one renderer, but it is not a clean base for a second
renderer. If Phase 7 builds a Cupertino settings sheet directly from here, it
will duplicate host logic and reintroduce split ownership.

So Phase 7 needs a renderer-neutral settings host above the Material or
Cupertino sheet widgets.

#### 4. The composer is much closer to Cupertino readiness than settings

Current files:

- `lib/src/features/chat/presentation/chat_composer_draft_host.dart`
- `lib/src/features/chat/presentation/widgets/chat_composer.dart`

The composer already has the right ownership move:

- live draft state is above the renderer
- send/stop behavior is contract-driven
- the widget only owns local `TextEditingController` sync and button rendering

That means the Cupertino composer path can be added as a true renderer widget
without reopening draft ownership. This makes composer a better early native
surface than transcript and a structurally simpler one than settings.

#### 5. Overlay execution still leaks Material in the most visible iPhone surfaces

Current file:

- `lib/src/features/chat/presentation/chat_root_overlay_delegate.dart`

The current default overlay delegate still uses:

- `showModalBottomSheet(...)` for settings
- `showModalBottomSheet(...)` for changed-file diffs
- `ScaffoldMessenger` and `SnackBar` for transient feedback

So even after the adapter work, the visible iPhone interaction lane still
depends on Material presentation at the top level.

Phase 7 does not need to redesign every overlay at once, but it does need:

- Cupertino settings presentation
- a non-Material top-level feedback surface for the iOS path

Changed-file diff presentation can remain on the Flutter path for now because it
belongs to the transcript lane that remains Flutter-owned.

#### 6. High-visibility Material leakage still exists outside the transcript feed

Current files:

- `lib/src/app.dart`
- `lib/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart`
- `lib/src/features/chat/presentation/widgets/empty_state.dart`
- `lib/src/features/chat/presentation/widgets/chat_composer.dart`
- `lib/src/features/settings/presentation/connection_sheet.dart`

The most visible Material-first widgets today are:

- `MaterialApp`
- `Scaffold`
- `AppBar`
- `PopupMenuButton`
- `CircularProgressIndicator`
- `FilledButton`, `OutlinedButton`, and `IconButton.filled`
- `SegmentedButton`
- `SwitchListTile.adaptive`
- `SnackBar`

Not all of these need to be removed in the first Phase 7 slice, but the app
will not feel convincingly iPhone-native while the first-launch, settings, and
composer flows still visibly use them.

#### 7. Transcript ownership can stay Flutter-owned, but not every visible control can stay Material

Current files:

- `lib/src/features/chat/presentation/widgets/transcript/transcript_list.dart`
- `lib/src/features/chat/presentation/widgets/empty_state.dart`

The transcript feed should still remain Flutter-owned in Phase 7.

That does not mean every high-visibility control inside the transcript lane can
stay Material forever. In particular:

- the empty-state configure CTA is part of the first-launch experience
- menu and loading affordances around the transcript remain shell-level
  concerns

So Phase 7 should keep transcript ownership where it is, while still cleaning up
the most visible iOS-breaking controls around it.

## Best Upgrade Path For Phase 7

The best Phase 7 path is not to start by reskinning transcript cards or by
trying to replace `MaterialApp` wholesale.

The correct path is:

1. move screen-shell selection above the fixed Material renderer host
2. extract the settings host so settings can support two renderers honestly
3. add a Cupertino shell path for app chrome and top-level actions
4. add a Cupertino settings presentation path
5. add a Cupertino composer path
6. clean up the remaining high-visibility Material feedback and first-launch
   affordances on iPhone

Why this is the best path:

- it uses the adapter seam we already built instead of bypassing it
- it keeps transcript ownership stable
- it avoids duplicating settings and composer logic per renderer
- it attacks the surfaces that make the app feel Material first
- it preserves the existing shared presentation contracts as the source of
  truth

## Phase 7 Slice Breakdown

Phase 7 should be split into 6 slices.

### Slice 1: Screen shell and platform-policy foundation

This slice is complete on this branch.

Slice 1 delivered:

- moving screen-shell selection above the fixed
  `FlutterChatScreenRenderer`
- introducing explicit `ChatRootScreenShellRenderer`,
  `ChatRootRegionRenderer`, and `ChatRootPlatformPolicy` vocabulary alongside
  the existing Flutter path
- supporting a mixed iOS foundation profile where shell selection is
  Cupertino-aware while transcript remains on the Flutter region path
- preserving the current all-Flutter path as a first-class baseline
- tests proving:
  - the injected renderer path still routes behavior through adapter-owned
    callbacks
  - a Cupertino shell can host the existing Flutter transcript/composer region
    path
  - platform policy selects the mixed iOS profile without an explicit override

This slice should cover:

- moving screen-shell selection above the fixed `FlutterChatScreenRenderer`
- introducing an explicit iOS/Cupertino renderer-policy vocabulary alongside
  the existing Flutter path
- supporting a mixed renderer profile where:
  - app chrome is Cupertino
  - composer is Cupertino
  - settings presentation is Cupertino
  - transcript remains Flutter
- keeping the current all-Flutter path as a first-class baseline

This slice should not yet redesign the screen visually. Its job is to make the
next slices structurally honest.

### Slice 2: Settings host extraction and Cupertino settings renderer

This slice is complete on this branch.

Slice 2 delivered:

- extracting `ConnectionSettingsHost` as the renderer-neutral owner of
  settings draft state, validation reveal state, controller syncing, and
  submit payload construction
- reducing `ConnectionSheet` to the Material settings renderer path only
- adding `CupertinoConnectionSheet` as a second renderer from the same host
  and contract
- routing settings launch through renderer-aware overlay delegate paths:
  Material bottom sheet for the Flutter path and Cupertino popup presentation
  for the iOS path
- tests proving:
  - Material validation and auth-mode switching still come from the shared
    host
  - Cupertino validation and submit behavior come from the same host
  - the root adapter routes iOS foundation settings through the Cupertino
    overlay path
  - shared submit semantics remain identical across both settings renderers

This slice should cover:

- extracting a renderer-neutral settings host above `ConnectionSheet`
- keeping the current Material settings renderer as one renderer path
- adding a Cupertino settings renderer from the same contract and host
- routing settings launch through an iOS-capable overlay delegate path

This is the first place where Phase 7 should add a new real Cupertino surface.

### Slice 3: Cupertino app chrome and shell actions

This slice is complete on this branch.

Slice 3 delivered:

- adding `CupertinoChatAppChrome` as the iOS top app chrome implementation
- routing iOS shell menu actions through `CupertinoActionSheet` presentation
  instead of the Material popup menu path
- removing the iOS shell's dependence on `Scaffold.appBar` by hosting the
  Cupertino chrome directly in `CupertinoChatScreenRenderer`
- preserving the same `ChatScreenContract` action ids and callback routing
- tests proving:
  - toolbar actions still route through adapter-owned callbacks
  - menu actions are presented and selected through the Cupertino action sheet
  - the iOS foundation renderer path now uses `CupertinoChatAppChrome` while
    transcript and composer remain on the Flutter region path

This slice should cover:

- a Cupertino top app chrome implementation
- iOS-appropriate presentation of screen menu actions
- iOS-path loading and shell layout behavior outside transcript rendering
- preserving the same `ChatScreenContract` action semantics

This slice should remove the most obvious Material shell cues on iPhone.

### Slice 4: Cupertino composer surface

This slice is complete on this branch.

Slice 4 delivered:

- adding a real `CupertinoChatComposer` renderer built from the shared composer
  contract
- routing the iOS foundation path to Cupertino send and stop affordances while
  preserving adapter-owned draft state
- parity for disabled, busy, clear-on-success, and retain-on-failure behavior
  under the iOS renderer path
- tests proving:
  - the composer resyncs from the shared contract
  - send and stop actions still forward through adapter-owned callbacks
  - successful sends clear the adapter-owned draft while failed sends retain it

This slice should cover:

- a Cupertino composer renderer built from the existing composer contract
- iOS send and stop affordances
- parity for disabled, busy, clear-on-success, and retain-on-failure behavior

Because draft ownership already moved above the renderer, this slice should be
mostly renderer work, not state work.

### Slice 5: iOS feedback and first-launch cleanup

This slice is complete on this branch.

Slice 5 delivered:

- adding explicit renderer policy for top-level transient feedback and
  first-launch empty-state rendering
- replacing the iOS path's `SnackBar` presentation with a Cupertino transient
  feedback overlay
- adding a Cupertino first-launch empty state and configure CTA while keeping
  transcript ownership in the existing Flutter region
- tests proving:
  - default all-Flutter feedback still routes through the Material overlay path
  - the iOS foundation path now renders Cupertino feedback instead of
    `SnackBar`
  - the iOS foundation path uses the Cupertino empty-state CTA when the profile
    is not configured

This slice should cover:

- a non-Material feedback surface for the iOS path instead of `SnackBar`
- first-launch empty-state CTA cleanup on iPhone
- removal of the remaining highest-visibility Material shell leakage that is
  outside transcript-card ownership

This slice should not attempt a full transcript redesign.

### Slice 6: Default iOS enablement and parity hardening

This slice should cover:

- default platform selection for the iOS renderer path
- ownership-oriented tests proving the iOS path still routes behavior through
  the adapter and shared contracts
- parity tests for settings save flow, composer send flow, and top-level
  actions under the iOS renderer path
- confirmation that transcript remains Flutter-owned while the surrounding shell
  is Cupertino-first

This slice completes Phase 7.

## Phase 7 Execution Spec

### Scope

Phase 7 must introduce:

- one screen-shell renderer selection seam above the current fixed Material host
- one explicit iOS/Cupertino renderer path for:
  - app chrome
  - settings presentation
  - composer
- one renderer-neutral settings state host that both Material and Cupertino
  settings renderers can consume
- one iOS feedback path for top-level transient messaging
- one platform-policy path that can select the mixed iOS profile while leaving
  transcript on the Flutter renderer

### Explicit Non-Goals

Phase 7 must not:

- move the transcript feed out of Flutter
- redesign transcript placement or request ownership
- replace Flutter with UIKit or SwiftUI
- duplicate settings or composer state logic per renderer
- rewrite `ChatSessionController` behavior as part of the iOS shell work
- force a global `CupertinoApp` rewrite if the adapter can host the iOS path
  honestly inside the current app bootstrap

### Required Ownership Boundary

After Phase 7:

- `ChatRootAdapter` must own selection of the active shell and surface renderer
  path
- the iOS shell must not just be Cupertino-looking children inside a fixed
  Material screen host
- settings state, validation, and submit semantics must not live only inside a
  Material sheet widget
- transcript may remain Flutter-owned
- transcript must remain consumed through the shared transcript contract path

### Required Semantics To Preserve

Unless broader behavior is explicitly requested, Phase 7 should preserve:

- current chat behavior and session lifecycle
- current screen action semantics
- current settings validation and save semantics
- current composer send and stop behavior
- current failed-send draft retention behavior
- current changed-file diff opening behavior
- current transcript follow and pending-request behavior

The next active Phase 7 slice is:

- default iOS enablement and parity hardening

Reason:

- Slices 4 and 5 completed the explicit Cupertino shell, settings, composer,
  feedback, and first-launch cleanup work for the iOS foundation path
- the next step is to turn that path on by default for iPhone while proving the
  adapter still owns routing and the transcript lane remains Flutter-owned
- this is the last Phase 7 slice before native glass styling can become the
  next focused track

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
