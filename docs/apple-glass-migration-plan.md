# Apple Glass Migration Plan

## Purpose

This document defines the migration path for introducing Apple-native glass
surfaces into Pocket Relay without coupling product behavior to Flutter-only UI
ownership.

The immediate goal is not to ship glass components. The immediate goal is to
make the highest-level app surfaces renderer-compatible so that a future root
architectural adapter can cleanly support both:

- Flutter-rendered surfaces
- Apple-native rendered surfaces on iOS/macOS

If this prep work is skipped, native glass work will become a one-off patch
that duplicates behavior, embeds policy in two places, and creates ownership
confusion that will be expensive to unwind.

## Current State

The app is structurally healthy in the application layer, but the top-level UI
layer is still owned directly by Flutter.

## Execution Tracking

This section is the current execution ledger for the migration. It exists so
future work is visible in the repo before code changes land.

### Documentation Rule

Before starting any new migration slice, update this document first with:

- the exact slice name
- the scope of the slice
- explicit non-goals
- exit criteria
- verification plan
- what older unfinished work, if any, is still intentionally left open

Do not start coding a new slice until that slice is recorded here.

When a slice is completed, update this section again with:

- completed status
- what was actually shipped
- what remains open after the slice

Do not rely on chat history as the source of truth for migration status.

### Current Status

- Phase 1, top-level chat screen ownership move: completed on this branch
- Phase 2, connection settings form contract extraction: completed on this
  branch
- Phase 3, pending user-input form contract extraction: next planned slice
- Root architectural adapter work: not started
- Apple-native glass components: not started

### Phase 1 Completed Scope

The following work is considered complete:

- one top-level chat screen contract derived from raw top-level application
  state
- one transcript surface contract derived from `CodexSessionState`
- top-level screen action definitions owned by the presentation layer
- composer state owned by the presentation layer
- turn indicator visibility owned by the presentation layer
- connection settings launch payload and launch effect owned by the
  presentation layer
- top-level snackbar effects mapped through a screen effect boundary
- `ChatScreen` reduced to controller host, effect executor, and Flutter
  renderer for the screen contract

### Phase 1 Explicit Non-Completion

The following work is not part of Phase 1 and remains open:

- connection settings form field contract and validation contract
- user-input request form field contract and submission contract
- transcript card renderer internals
- changed-file diff sheet ownership below the screen level
- root architectural adapter
- Apple-native glass surfaces

### Phase 2 Completed Scope

The following work is considered complete:

- one renderer-neutral connection settings draft model built from
  `ConnectionProfile` and `ConnectionSecrets`
- one connection settings form state model that controls validation visibility
- one connection settings contract that owns:
  - settings sections
  - text field descriptors
  - auth mode selection
  - visible auth fields
  - run-mode toggles
  - field validation errors
  - dirty-state and submit-state
  - submit payload
- one connection settings presenter that derives the full contract from:
  - initial `ConnectionProfile`
  - initial `ConnectionSecrets`
  - current settings form state
- `ConnectionSheet` reduced to Flutter renderer and input plumbing over the
  shared draft/state/contract path
- widget-local form validators removed as the source of truth
- widget-local `ConnectionProfile` and `ConnectionSecrets` assembly removed from
  the sheet

### Phase 2 Explicit Non-Completion

The following work is not part of Phase 2 and remains open:

- user-input request form extraction
- changed-file diff sheet ownership below the screen level
- transcript card renderer internals
- root architectural adapter
- Apple-native settings rendering
- Apple-native glass surfaces

### Phase 2 Verification Completed

Phase 2 verification now includes:

- presenter tests for validation, auth visibility, dirty-state, and save payload
- widget tests that prove the sheet consumes presenter-derived validation
  without the old `Form` validator path
- targeted analysis and regression tests for the settings surface and chat host

### Next Planned Slice

The next planned slice is:

- Phase 3, pending user-input form contract extraction

That slice should cover:

- request form draft state
- field descriptors
- option selection state
- validation and submit-state derivation
- submit payload contract for request answers

That slice should not cover:

- Apple-native rendering
- transcript card visual redesign
- root adapter work
- settings surface redesign

If the next implementation attempt changes that plan, this section must be
updated before coding starts.

### What is already in good shape

- `ChatSessionController` is application logic plus side effects, not widget
  logic.
- `TranscriptReducer` and transcript policy code already centralize most runtime
  event handling.
- `CodexSessionState` already projects runtime state into transcript-oriented
  structures.

This means the core data flow can support multiple renderers.

### What is not ready for a second renderer

- `ChatScreen` directly owns top-level screen composition and product display
  policy.
- Transcript layout policy is split across multiple widget inputs.
- Input-heavy surfaces still keep form state in Flutter widgets.
- Modal and sheet presentation are triggered directly from Flutter renderers.
- Transcript item dispatch is Flutter-specific.
- Scroll-follow behavior is implemented as widget-local mechanics instead of a
  shared transcript behavior contract.

## Main Architectural Problem

Pocket Relay currently has one tree owner: Flutter.

That is visible in several places:

- `MaterialApp` mounts the Flutter screen directly.
- `ChatScreen` decides header content, actions, loading treatment, transcript
  placement, pending request placement, timer placement, composer placement, and
  settings sheet ownership.
- Transcript widgets decide where pending items live and how transcript
  following works.
- Cards open modals directly.
- Form widgets assemble answers and settings payloads locally.

That structure is acceptable for a single renderer. It is the wrong shape for a
future root adapter.

The migration requirement is therefore:

> Move product UI policy out of Flutter widget composition and into shared
> presentation contracts before introducing native glass ownership.

This is a structural requirement. It is not satisfied by a thin presenter that
simply forwards the same scattered getters while `ChatScreen` remains the real
owner of product decisions.

## Migration Principles

### 0. Do this the hard and correct way

This migration must not be implemented as a cosmetic abstraction pass.

The acceptable version of this work is:

- move real top-level UI ownership out of Flutter widget composition
- introduce presentation contracts that own actual product decisions
- make Flutter become one renderer of those contracts

The unacceptable version of this work is:

- wrapping existing Flutter state fan-out in thin model classes
- creating vague "shared" abstractions that still depend on Flutter-owned
  behavior
- building a one-size-fits-all adapter that hides unresolved ownership
- presenting a compatibility layer as if it were a real architectural boundary
- stopping at a halfway point where a new presentation layer exists on paper but
  critical ownership still remains split across Flutter widgets and controller
  getters

If a step does not change ownership in a meaningful way, it does not count as
progress for this migration.

If a slice introduces a new seam, that seam must become the real owner for the
behavior in scope before the slice is considered complete. Do not leave partial
ownership moves behind as "follow-up" debt if that debt will make later
migration harder.

### 1. Do not build glass first

No Apple-native glass components should be introduced until the top-level
presentation contracts exist.

### 2. Create renderer-neutral presentation models

Flutter and Apple-native renderers must consume the same screen-level and
section-level contracts.

### 3. Keep product behavior out of renderer implementations

Renderers should render. They should not decide product policy such as pending
item placement, header rules, composer state, or sheet lifecycle.

### 4. Move interactive state out of renderer-owned widgets where needed

Forms and request flows that need parity across renderers must be modeled
explicitly rather than relying on local Flutter controllers as the canonical
state owner.

### 5. Add adapter seams at coherent ownership boundaries

The initial adapter seam should be at a root or major-region boundary, not at
random leaf widgets.

## Audit Findings

### A. Top-level screen policy is trapped inside Flutter

`lib/src/features/chat/presentation/chat_screen.dart`

`ChatScreen` currently owns:

- app bar title and subtitle rules
- top-level actions
- loading state presentation
- transcript placement
- pending request placement
- timer placement
- composer placement
- settings bottom sheet lifecycle

This is the highest-priority blocker. A future native root cannot consume a
shared `ChatScreenModel` because no such model exists yet.

### B. Transcript ownership is split instead of modeled

`lib/src/features/chat/models/codex_session_state.dart`
`lib/src/features/chat/presentation/widgets/transcript/transcript_list.dart`

The transcript surface is not described as one contract. Instead the app
exposes:

- transcript blocks
- primary pending approval block
- primary pending user input block

The Flutter transcript widget then applies product rules such as:

- pending requests render outside the main scroll area
- pending area height is capped
- follow behavior is triggered by widget-local events

Those are presentation policies, not Flutter implementation details. They must
move into a renderer-neutral transcript model.

### C. Interactive request UI owns form state locally

`lib/src/features/chat/presentation/widgets/transcript/cards/user_input_request_card.dart`

The user input request card currently owns:

- dynamic controller creation
- answer synchronization
- option selection behavior
- payload assembly on submit

That means a native renderer would need its own parallel implementation of the
same behavior, with no shared contract beyond the raw block.

### D. Settings ownership is still fully Flutter-specific

`lib/src/features/settings/presentation/connection_sheet.dart`

The settings sheet owns:

- all field controllers
- validation
- auth mode switching
- run-mode toggle state
- dirty-state detection
- save payload construction

If a native sheet is introduced later, this entire behavior layer would be
duplicated unless it is extracted into a shared settings form model first.

### E. Overlay lifecycle is initiated inside renderers

`ChatScreen` opens the settings sheet directly.
`ChangedFilesCard` opens the diff sheet directly.

That makes Flutter the owner of overlay lifecycle. A future root adapter will
need overlays and sheet presentation to become explicit intents/effects rather
than renderer-internal decisions.

### F. Transcript item shaping is still renderer-specific

`lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart`

The block-to-widget mapping happens directly in Flutter, including local shaping
such as converting a single work-log entry into a synthetic work-log group.

That transformation should happen before rendering so both renderers see the
same item model.

### G. Test coverage is biased toward Flutter output, not ownership contracts

Current tests verify that Flutter renders expected output and interactions. That
coverage is useful, but it does not yet verify:

- screen-level presentation contracts
- transcript section ownership
- overlay intents
- renderer-neutral form descriptors

Those tests are required before a renderer split.

## Target Architecture

### Layer 1: Domain and application

Keep the current reducer, policies, session state, app-server integration, and
controller-based application flow.

This layer remains the source of truth for business behavior and remote-session
state.

### Layer 2: Presentation model layer

Add a presentation layer that maps application state into renderer-neutral view
models.

Suggested models:

- `ChatScreenModel`
- `ChatHeaderModel`
- `ChatTranscriptModel`
- `ChatTranscriptSectionModel`
- `ChatComposerModel`
- `ConnectionSettingsModel`
- `UserInputRequestModel`
- `OverlayIntent`

This layer becomes the contract consumed by both Flutter and native renderers.

### Layer 3: Renderer implementations

Provide separate renderers that consume the same presentation models:

- Flutter renderer
- Apple-native renderer

At first, Flutter can remain the only implementation. The point is to create
the seam before native glass work begins.

### Layer 4: Root architectural adapter

Only after the presentation models exist should the app introduce a root
adapter capable of selecting or embedding renderer ownership for major regions.

Examples of future adapter shapes:

- Flutter root with native regions
- Native root with Flutter regions
- Per-platform root selection behind a shared application state source

The choice can be made later. The prep work is the same.

## Recommended Refactor Sequence

### Phase 1: Extract top-level chat presentation

Create a presenter or mapping layer that turns controller state into a
`ChatScreenModel`.

This phase must be implemented as a real ownership move, not as a packaging
exercise.

Phase 1 is only correct if:

- `ChatScreen` stops deriving top-level product rules inline
- the presentation layer becomes the source of truth for header state, loading
  state, timer visibility, composer state, and top-level action definitions
- transcript inputs are grouped into a screen-owned surface contract rather than
  passed around as scattered controller getters

Phase 1 is not correct if:

- `ChatScreen` still contains the real decision-making and the presenter just
  mirrors it
- models are Flutter-shaped convenience bags rather than renderer-oriented
  contracts
- the extraction is optimized for a small diff instead of a clean ownership
  boundary
- a new screen model exists, but transcript composition or top-level overlay
  ownership still bypasses that model through direct controller getters or
  widget-owned lifecycle rules

Phase 1 must not stop at a state where:

- header and composer derivation moved, but transcript ownership did not
- a settings model exists, but `ChatScreen` still owns sheet lifecycle as an
  implicit widget behavior
- top-level actions are named in models, but their availability or structure is
  still defined by Flutter-only composition

The hard rule is:

> For every top-level concern included in Phase 1, there must be one owner when
> the slice lands. Not two. Not "temporarily both."

The Phase 1 implementation must start from raw top-level application state and
end with one screen-level presentation contract. It must not start from
Flutter-shaped getters and then repackage them.

That means the preferred Phase 1 inputs are:

- `ConnectionProfile`
- `ConnectionSecrets`
- `CodexSessionState`
- top-level screen effect sources

That means the unacceptable Phase 1 inputs are:

- pre-shaped transcript widget inputs that already encode Flutter ownership
- separate controller getters for transcript blocks and pending widget regions
  if those getters remain the real source of top-level screen composition

### Phase 1 Execution Order

The execution order for Phase 1 is fixed:

1. Define the full top-level screen contract.
2. Define the top-level transcript surface contract as part of that screen
   contract.
3. Define the top-level overlay/effect contract for connection settings.
4. Move top-level derivation into the presentation layer.
5. Reduce `ChatScreen` to controller host, effect executor, and renderer.
6. Add tests that prove `ChatScreen` is no longer the owner.

Do not start by adding model classes unless the transcript surface and settings
effect are included in the same ownership move.

### Phase 1 Required Contract

The Phase 1 screen contract must own all of the following:

- header title
- header subtitle
- top-level actions
- loading/content state
- transcript surface composition
- pending request placement at the screen level
- turn timer visibility
- composer state
- connection settings launch intent/effect

If any item in that list is still owned by `ChatScreen` or bypasses the screen
contract through direct controller getters, Phase 1 is incomplete.

### Phase 1 Exit Criteria

Phase 1 is complete only when all of the following are true:

- `ChatScreen` does not derive header, loading, timer, composer, transcript
  placement, or top-level action state inline
- `ChatScreen` does not read top-level transcript composition from scattered
  Flutter-facing controller getters
- `ChatScreen` does not own implicit settings-sheet lifecycle rules beyond
  executing a modeled effect/intent
- Flutter renders one top-level screen contract instead of assembling the screen
  from controller fan-out
- tests prove the presentation layer owns the behavior and the widget no longer
  does

If a proposed implementation cannot reach those exit criteria in one pass, do
not land a partial seam. Re-scope the work before coding.

### Phase 1 Concrete Contract

Phase 1 must define one concrete top-level contract for the chat screen.

Suggested contract shape:

```dart
class ChatScreenContract {
  final bool isLoading;
  final ChatHeaderContract header;
  final ChatTranscriptSurfaceContract transcriptSurface;
  final ChatComposerContract composer;
  final ChatTurnIndicatorContract? turnIndicator;
  final ChatConnectionSettingsLaunchContract connectionSettings;
  final List<ChatScreenActionContract> actions;
}

class ChatHeaderContract {
  final String title;
  final String subtitle;
}

class ChatTranscriptSurfaceContract {
  final bool isConfigured;
  final ChatEmptyStateContract? emptyState;
  final List<ChatTranscriptItemContract> mainItems;
  final List<ChatTranscriptItemContract> pinnedItems;
}

class ChatComposerContract {
  final bool isEnabled;
  final bool isBusy;
  final String placeholder;
  final ChatComposerPrimaryAction primaryAction;
}

class ChatTurnIndicatorContract {
  final CodexSessionTurnTimer timer;
}

class ChatConnectionSettingsLaunchContract {
  final ConnectionProfile initialProfile;
  final ConnectionSecrets initialSecrets;
}

sealed class ChatScreenEffect {
  const ChatScreenEffect();
}

class ShowSnackBarEffect extends ChatScreenEffect {
  final String message;
}

class OpenConnectionSettingsEffect extends ChatScreenEffect {
  final ChatConnectionSettingsLaunchContract payload;
}
```

The exact class names may change. The ownership boundary may not.

### Phase 1 Presenter Inputs

The presenter must derive the screen contract from raw top-level state, not
from pre-shaped widget inputs.

Required inputs:

- `bool isLoading`
- `ConnectionProfile profile`
- `ConnectionSecrets secrets`
- `CodexSessionState sessionState`

Allowed supporting collaborators:

- a transcript surface projector that accepts `CodexSessionState` and returns a
  top-level transcript surface contract
- an effect mapper that converts top-level UI effects into `ChatScreenEffect`

Not allowed as presenter inputs:

- `transcriptBlocks`
- `pendingApprovalBlock`
- `pendingUserInputBlock`
- any other Flutter-facing getter that bypasses raw top-level state ownership

### Phase 1 Presenter Ownership

The presentation layer must be the only owner for all of the following
decisions:

- when the screen is considered loading
- what the header subtitle says
- what top-level actions exist
- whether the transcript shows an empty state or content
- which transcript items belong in the main region
- which transcript items belong in the pinned or pending region
- whether the turn timer is shown
- whether the composer is enabled
- what payload is used when launching connection settings
- what top-level UI effects exist

If any of those decisions are still made directly in `ChatScreen`, Phase 1 is
not finished.

### Phase 1 Host Responsibilities

After Phase 1, `ChatScreen` is allowed to do only these jobs:

- own the `ChatSessionController`
- subscribe to top-level screen effects
- execute effects such as opening settings or showing a snackbar
- render Flutter widgets from the screen contract
- dispatch user actions back into the application layer

`ChatScreen` is not allowed to:

- derive header text
- derive transcript placement
- derive composer enablement
- decide timer visibility
- assemble settings launch payloads
- invent top-level action structure

### Phase 1 Explicit Non-Goals

Phase 1 does not need to solve every downstream migration concern.

It may leave these deeper concerns in place temporarily:

- the internal rendering of transcript cards
- the internal rendering of the connection settings form
- the internal rendering of user input request forms

But even while those remain, Phase 1 must still own the screen-level placement
and launch boundaries for those surfaces.

That model should include:

- title and subtitle
- top-level actions
- loading state
- transcript model
- pending request region model
- timer model
- composer model
- overlay intents supported by the screen

After this phase, `ChatScreen` should mostly render a screen model instead of
making product decisions inline.

### Phase 2: Unify transcript ownership

Replace the current split transcript inputs with an explicit transcript contract.

The transcript model should describe:

- main transcript items in order
- pinned or pending items
- empty-state variant
- follow policy flags
- user actions emitted from transcript items

The rule that pending requests stay outside the main transcript must live in the
model contract, not inside Flutter widget structure.

### Phase 3: Extract composer model

The composer should receive a renderer-neutral state object such as:

- current text
- placeholder
- enabled/disabled state
- busy state
- primary action kind
- text constraints

If native composer ownership comes later, this prevents behavior from being
rediscovered in the renderer.

### Phase 4: Extract settings form model

Convert connection settings from a Flutter-owned form implementation into a
shared form contract.

That model should describe:

- sections
- fields
- field values
- field validation messages
- visibility rules
- toggle and segmented-choice options
- dirty state
- submit availability

Flutter can still render it first. The important change is that the contract is
no longer implicit in widget code.

### Phase 5: Extract user input request form model

Convert pending user input requests into a shared request form model with:

- title
- body
- field descriptors
- existing answers
- option choices
- secret-field behavior
- submit state

Avoid keeping submission payload assembly as local widget behavior.

### Phase 6: Move overlays to intents/effects

Replace direct modal ownership with explicit overlay intents, for example:

- open connection settings
- open changed file diff
- dismiss overlay

The Flutter implementation can still execute those intents, but the ownership
boundary becomes explicit and portable.

### Phase 7: Introduce renderer-specific implementations

Once the presentation contracts are stable:

- keep Flutter rendering everything initially
- add a native implementation for one major region
- verify parity against the same presentation model

### Phase 8: Begin Apple glass work

Only after the earlier phases should Apple-native glass surfaces be introduced.

Recommended first native candidates:

- composer
- screen chrome or header
- settings sheet

Do not begin with transcript cards. The transcript is the most dynamic surface
and the worst place to start platform ownership splitting.

## What Not To Do

- Do not implement a fake "shared UI layer" that merely re-labels the existing
  Flutter ownership model.
- Do not accept "we'll clean that up in the next slice" for ownership gaps that
  become harder to unwind once the new seam is in place.
- Do not add `UiKitView` or `AppKitView` wrappers around existing leaf widgets
  before top-level presentation contracts exist.
- Do not build native glass for individual transcript cards first.
- Do not let Flutter remain the hidden owner of overlay lifecycle while native
  views appear to own the same surfaces.
- Do not duplicate settings validation logic in Swift while Flutter remains the
  source of truth.
- Do not let renderer implementations invent their own layout policies for
  pending requests, transcript grouping, or composer behavior.

## First Implementation Slice

The first concrete change must be a full top-level ownership move for the
screen contract in scope. It must not be a preliminary wrapper step.

The first acceptable deliverables are:

- one screen-level presentation contract that includes transcript composition
  and settings-launch effect ownership
- one presenter/mapping layer that derives that contract from raw top-level app
  state
- one `ChatScreen` renderer host that consumes that contract and executes
  effects
- tests proving:
  - pending request placement is modeled explicitly at the screen level
  - settings launch is a modeled top-level effect
  - header state is derived by the presentation layer
  - composer state is derived by the presentation layer
  - timer visibility is derived by the presentation layer
  - `ChatScreen` no longer owns those decisions inline

The first implementation slice is not allowed to land if it only extracts
header/composer/timer derivation while leaving transcript composition and
settings ownership behind.

## Verification Strategy

### Unit and presenter tests

Add tests that assert:

- screen models derived from controller state are stable
- transcript section placement is explicit
- overlay intents are emitted correctly
- settings and user-input form descriptors are correct

### Widget tests

Keep Flutter widget tests, but retarget them to verify that Flutter renders the
shared presentation models correctly rather than directly owning the behavior.

### Migration parity checks

Before introducing native renderers, verify that the Flutter renderer is fully
driven by the extracted models. That prevents the adapter boundary from being a
half-measure.

## Definition of Done for the Prep Step

The prep step is done when:

- top-level chat UI policy is represented in shared presentation models
- transcript ownership and pending-region placement are explicit contracts
- settings and user-input flows have shared form descriptors
- overlay presentation is modeled as intents/effects
- Flutter acts as one renderer over those contracts
- tests verify ownership and placement behavior, not only text output

The prep step is not done if the code merely looks more abstract while Flutter
still owns the real product decisions.

The prep step is also not done if any new presentation seam leaves unresolved
split ownership that will have to be unwound before native rendering can
truthfully adopt it.

At that point, the codebase is ready for a root architectural adapter.

At that point only, Apple-native glass work should begin.
