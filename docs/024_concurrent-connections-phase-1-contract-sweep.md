# Concurrent Connections Phase 1 Contract Sweep

This document is the Phase 1 sweep for concurrent connections.

It does not implement the feature.

Its job is to:

- freeze the product contract before migration work starts
- identify every current singleton ownership seam affected by the feature
- identify the test blast radius
- define what must be true before Phase 2 begins

This document complements:

- `docs/023_concurrent-connections-architecture-plan.md`

## Phase 1 Goal

Phase 1 is complete when Pocket Relay has a stable product contract for
concurrent connections and the team is no longer making identity, navigation,
or ownership decisions ad hoc during implementation.

The output of Phase 1 is:

- one frozen connection identity model
- one frozen mobile navigation model
- one frozen desktop navigation model
- one frozen separation between workspace navigation and lane-local chat state
- one file-level impact map for the next implementation slices

## Frozen Product Decisions

These decisions should now be treated as fixed unless the product changes again.

### 1. Connection identity is not host identity

Saved connections must be keyed by stable opaque `connectionId`.

They must not be deduplicated by:

- host
- IP address
- username
- workspace directory

Reason:

- the same box may host multiple projects
- the user may want multiple saved entries for one machine
- those entries may differ only by workspace path, Codex command, or run mode

### 2. Live lanes and saved connections are different concepts

Pocket Relay must distinguish:

- saved connections
- live lanes instantiated from saved connections

For the first cut:

- one live lane per saved connection

### 3. Mobile navigation is lane-first

On mobile:

- horizontal swipe switches live lanes
- swiping past the last live lane reveals a dormant connection roster page
- the roster page lists dormant saved connections only

### 4. Dormant connections are directly reachable from the menu

The overflow menu must include:

- `Dormant connections`

Selecting it jumps directly to the dormant roster page.

This is a workspace navigation action, not a lane-local chat action.

### 5. Desktop navigation is sidebar-first

On desktop:

- use a persistent left sidebar
- show a `Live` section
- show a `Dormant` section
- selecting an entry changes workspace selection

If the visible product term should be `Projects`, that is a naming choice only.

The underlying architecture must still be connection-id based.

### 6. Child-agent timelines stay inside a lane

The current multi-timeline work remains lane-local.

Hierarchy:

1. workspace
2. connection lane
3. selected timeline inside that lane

The existing timeline selector must not become the connection navigator.

### 7. Offscreen live lanes stay alive

A live lane remains instantiated even when offscreen.

That means:

- `PageView` recycling must not define connection lifetime
- lane teardown must happen only through workspace lifecycle actions

### 8. Settings edit saved connections, not the whole app

The current app-global settings semantics must not survive this migration.

Rules:

- dormant connection edits save immediately
- live connection edits are explicit reconnect actions
- saving one connection must not disconnect unrelated live lanes

## Current Code Sweep

This section records the current singleton assumptions that conflict with the
Phase 1 contract.

### App bootstrap

Files:

- `lib/src/app.dart`
- `test/widget_test.dart`

Current reality:

- `PocketRelayApp` owns one `CodexProfileStore`
- it owns one `CodexConversationHandoffStore`
- it owns one `CodexAppServerClient`
- it loads one `SavedProfile`
- it loads one `SavedConversationHandoff`
- it renders one `ChatRootAdapter`

Implication:

- the app root is currently the singleton connection owner
- Phase 2 must replace this with a workspace owner

### Persistence

Files:

- `lib/src/core/storage/codex_profile_store.dart`
- `lib/src/core/storage/codex_conversation_handoff_store.dart`
- `test/codex_profile_store_test.dart`

Current reality:

- one profile key
- one password key
- one private key key
- one handoff key

Implication:

- persistence is hard-coded to “current connection”
- Phase 2 must introduce keyed catalog storage and keyed handoff storage

### Chat root binding

Files:

- `lib/src/features/chat/presentation/chat_root_adapter.dart`
- `test/chat_root_adapter_test.dart`

Current reality:

- `ChatRootAdapter` owns one `ChatSessionController`
- it owns one composer draft host
- it owns one transcript follow host
- it owns one screen-effect subscription
- widget lifecycle currently controls controller lifecycle

Implication:

- this file is the current lane binding disguised as the whole app
- its ownership must be split into:
  - workspace owner above
  - lane-local binding below

### Session orchestration

Files:

- `lib/src/features/chat/application/chat_session_controller.dart`
- `test/chat_session_controller_test.dart`

Current reality:

- one profile
- one secrets object
- one session state
- one `_resumeThreadId`
- one `appServerClient`
- applying connection settings disconnects the current client immediately

Implication:

- the controller is useful as a lane-local controller
- it must stop being treated as the app-global controller

### Screen contract and actions

Files:

- `lib/src/features/chat/presentation/chat_screen_contract.dart`
- `lib/src/features/chat/presentation/chat_screen_presenter.dart`
- `lib/src/features/chat/presentation/chat_screen_effect_mapper.dart`
- `lib/src/features/chat/presentation/widgets/chat_app_chrome.dart`
- `lib/src/features/chat/presentation/widgets/cupertino_chat_app_chrome.dart`
- `lib/src/features/chat/presentation/chat_root_adapter.dart`
- `test/chat_screen_presentation_test.dart`
- `test/chat_screen_renderer_test.dart`
- `test/cupertino_chat_app_chrome_test.dart`

Current reality:

- the screen contract is lane-local
- actions are:
  - `openSettings`
  - `newThread`
  - `clearTranscript`
- effect mapping routes only `openSettings`
- `newThread` and `clearTranscript` are handled directly in `ChatRootAdapter`

Implication:

- the contract currently has no workspace-navigation concept
- Phase 2 or 3 must add a workspace action such as
  `openDormantConnections`
- that action must not route through `ChatSessionController`

### Transcript and lane rendering

Files:

- `lib/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart`
- `lib/src/features/chat/presentation/widgets/cupertino_chat_screen_renderer.dart`
- `lib/src/features/chat/presentation/widgets/transcript/transcript_list.dart`
- `test/chat_screen_renderer_test.dart`

Current reality:

- one screen shell
- one transcript region
- one composer region
- one horizontal selector for timelines within a lane

Implication:

- the existing horizontal selector is already spoken for
- connection navigation must live above this layer
- desktop needs a workspace shell rather than a transcript patch

### Settings

Files:

- `lib/src/features/settings/presentation/connection_settings_host.dart`
- `lib/src/features/settings/presentation/connection_settings_presenter.dart`
- `lib/src/features/chat/presentation/chat_root_overlay_delegate.dart`
- `test/widget_test.dart`
- `test/chat_root_adapter_test.dart`

Current reality:

- the settings surface edits one connection payload
- `ChatRootAdapter` applies the result directly to the singleton controller

Implication:

- the UI form itself is reusable
- the ownership of submission must move from app-global mutation to
  saved-connection editing

## Existing Multi-Timeline Work That Must Stay Separate

Files:

- `lib/src/features/chat/models/codex_session_state.dart`
- `lib/src/features/chat/presentation/chat_screen_presenter.dart`
- `lib/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart`
- `docs/014_child-agent-timeline-architecture-plan.md`
- `docs/015_child-agent-timeline-implementation-sequence.md`

Current reality:

- Pocket Relay already models multiple timelines within one connection
- the UI already projects lane-local timeline summaries

Implication:

- this work is not the concurrent-connections solution
- it must remain nested inside each connection lane

## Reference Sweep

The local T3 reference is useful for navigation structure, not for transport
ownership.

Relevant files:

- `.reference/t3code/apps/web/src/routes/_chat.tsx`
- `.reference/t3code/apps/web/src/components/Sidebar.tsx`
- `.reference/t3code/apps/web/src/store.ts`
- `.reference/t3code/apps/web/src/types.ts`

Observed patterns:

- the chat route shell mounts a persistent sidebar
- the sidebar owns project-level navigation
- projects have stable ids distinct from nested threads
- project ordering is preserved independently from thread state

The correct lesson for Pocket Relay:

- connection navigation belongs to the workspace shell
- per-connection transcript and timeline state belongs below that shell

The incorrect lesson would be:

- copy T3’s project domain directly

Pocket Relay still needs connection-id based ownership because transport
instances are first-class here.

## Test Blast Radius

The following test groups are expected to change when implementation begins.

### Root bootstrap tests

Files:

- `test/widget_test.dart`
- `test/chat_screen_app_server_test.dart`

Why:

- they currently build one `PocketRelayApp` and expect one `ChatRootAdapter`
- they assume one profile store and one handoff store
- `test/chat_screen_app_server_test.dart` is currently the largest singleton
  profile injection surface and will move with the storage migration

### Lane binding tests

Files:

- `test/chat_root_adapter_test.dart`
- `test/chat_session_controller_test.dart`

Why:

- current tests assume one adapter owns the whole app session lifecycle
- these will need to split into:
  - workspace-level tests
  - lane-binding tests

### Screen and chrome tests

Files:

- `test/chat_screen_renderer_test.dart`
- `test/cupertino_chat_app_chrome_test.dart`
- `test/chat_screen_presentation_test.dart`

Why:

- the action set will change
- there will be workspace navigation in addition to lane navigation
- desktop and mobile shells will diverge more clearly

### Storage tests

Files:

- `test/codex_profile_store_test.dart`
- `test/chat_screen_app_server_test.dart`

Why:

- singleton storage will be replaced or heavily wrapped by catalog storage
- many existing test harnesses currently inject one `MemoryCodexProfileStore`
  as the app-global connection source

## Usage Footprint Notes

The singleton model is not only present in production wiring. It is also deeply
embedded in test setup patterns.

Observed hotspots:

- `test/chat_screen_app_server_test.dart` repeatedly injects one
  `MemoryCodexProfileStore` as the session source
- `test/widget_test.dart` repeatedly asserts that one `ChatRootAdapter`
  represents the booted app
- `test/chat_root_adapter_test.dart` currently treats adapter lifecycle as app
  lifecycle

Implication:

- Phase 2 should expect broad harness migration even before the multi-lane UI
  exists
- the storage migration is the right first slice because it breaks the largest
  number of hidden singleton assumptions at the correct seam

## Phase 1 Deliverables

Before Phase 2 starts, the repo should have agreement on the following exact
deliverables:

1. stable `connectionId` is the identity model
2. one live lane per saved connection in the first cut
3. mobile roster page is the rightmost page
4. overflow menu includes `Dormant connections`
5. desktop uses a persistent sidebar with live and dormant sections
6. `ChatSessionController` stays lane-local
7. `ChatRootAdapter` stops being the app-wide singleton owner in later phases
8. keyed catalog storage and keyed handoff storage are the next coding slice

## Exit Criteria

Phase 1 is done when:

- the product contract above is accepted
- no unresolved identity ambiguity remains
- no unresolved mobile vs desktop navigation ambiguity remains
- the next implementation phase is unblocked

## Recommended Phase 2 Start

The next coding phase should begin with persistence and migration, not with
widgets.

Recommended first implementation files:

- new connection catalog store under `lib/src/core/storage/`
- keyed handoff store under `lib/src/core/storage/`
- migration tests from singleton storage to keyed catalog storage

Do not start by patching `ChatRootAdapter` to fake multiple lanes against the
singleton stores.
