# Phase 4 UI Primitive Audit and Upgrade Path

## Goal

Phase 4 should add the concurrent-connection workspace shell without
introducing a new UI stack, a new dependency, or hidden coupling between
workspace navigation and lane-local chat behavior.

The correct implementation should:

- reuse the lane runtime and lane renderers that already exist
- add shell-level navigation above them
- keep `Dormant connections` as a workspace action
- avoid pushing workspace actions into `ChatSessionController`
- avoid turning the child-agent timeline selector into connection navigation

## What We Already Have

### 1. Lane runtime ownership already exists

These pieces are already on the correct side of the ownership boundary:

- `lib/src/features/chat/presentation/connection_lane_binding.dart`
- `lib/src/features/chat/presentation/chat_root_adapter.dart`
- `lib/src/features/workspace/presentation/connection_workspace_controller.dart`

That means Phase 4 does not need to re-architect chat state again.

It already has:

- one lane binding per live connection
- lane-local `ChatSessionController`
- lane-local composer draft host
- lane-local transcript follow host
- workspace-owned lane instantiation and disposal

This is the main reason stock `PageView` is now viable.

### 2. App chrome primitives already exist

The app already ships reusable chrome pieces:

- `lib/src/features/chat/presentation/widgets/chat_app_chrome.dart`
- `lib/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart`
- `lib/src/features/chat/presentation/widgets/cupertino_chat_app_chrome.dart`

Relevant reusable pieces:

- `ChatAppChromeTitle`
- `ChatOverflowMenuButton`
- `FlutterChatAppChrome`
- `CupertinoChatAppChrome`

This means Phase 4 should extend the existing app-chrome seam instead of
replacing the top bar.

### 3. Screen shell primitives already exist

The current lane shell is already encapsulated:

- `lib/src/features/chat/presentation/widgets/chat_screen_shell.dart`
- `lib/src/features/chat/presentation/chat_root_renderer_delegate.dart`

Relevant reusable pieces:

- `ChatScreenGradientBackground`
- `ChatScreenBody`
- the existing material and cupertino screen renderers

This means Phase 4 should host full `ChatRootAdapter` pages inside the
workspace shell instead of unpacking transcript and composer regions again at
the workspace level.

### 4. Platform split already exists

The app already knows whether it is in mobile or desktop mode:

- `lib/src/core/platform/pocket_platform_behavior.dart`
- `lib/src/core/platform/pocket_platform_policy.dart`

Relevant existing decisions:

- mobile vs desktop is already modeled explicitly
- local connection mode support is already tied to platform behavior
- chat rendering style is already split through `ChatRootRegionPolicy`

Phase 4 should reuse `PocketPlatformBehavior.isMobileExperience` and
`isDesktopExperience` instead of inventing a second platform switch.

### 5. Settings surface styling exists, but it is not a sidebar primitive

This file is useful as a visual reference only:

- `lib/src/features/settings/presentation/connection_settings_sheet_surface.dart`

It already gives us:

- section spacing
- rounded container treatment
- material and cupertino surface styling

It should not be reused directly as the workspace sidebar or roster surface.
It is a settings overlay, not a navigation container.

## Stock Flutter and Cupertino Primitives We Should Use

No new package is justified for Phase 4.

The best built-in primitives are:

- `PageView` and `PageController` for mobile live-lane paging
- `Row`, `ConstrainedBox`, `SafeArea`, and `ListView` for the desktop shell
- `PopupMenuButton` for the overflow menu we already ship
- `AnimatedBuilder` for workspace controller-driven rebuilds
- `Material`, `InkWell`, `DecoratedBox`, and `Container` for roster and sidebar
  rows

Primitives we should avoid for this feature:

- `Drawer`
  because desktop requires a persistent sidebar, not a collapsible nav drawer
- `NavigationRail`
  because live and dormant connections are grouped lists, not a flat set of
  destinations
- `BottomNavigationBar`
  because the connection count is dynamic and not capped to a few tabs
- custom gesture recognizers for lane paging
  because `PageView` already solves the requested horizontal swipe behavior

## Findings That Change the Upgrade Path

### 1. The real missing state is shell destination state

Current workspace state only tracks:

- saved catalog
- live connection ids
- selected live connection id

See:

- `lib/src/features/workspace/models/connection_workspace_state.dart`

That is enough for Phase 3, but not enough for Phase 4.

Phase 4 needs an explicit shell-level destination model so the workspace can
represent:

- a live lane being visible
- the dormant roster being visible

without abusing widget-local page position as the source of truth.

Recommended addition:

- keep `selectedConnectionId` for the active live lane
- add a shell viewport value such as `liveLane` vs `dormantRoster`

This keeps lane selection and roster visibility separate.

That matters because the user can open the dormant roster without losing which
live lane was selected last.

### 2. The current overflow menu contract is lane-typed

Today the overflow menu is typed as `PopupMenuButton<ChatScreenActionId>` and
the menu entries come from `ChatScreenContract`.

See:

- `lib/src/features/chat/presentation/chat_screen_contract.dart`
- `lib/src/features/chat/presentation/widgets/chat_app_chrome.dart`
- `lib/src/features/chat/presentation/chat_screen_presenter.dart`

That is too narrow for Phase 4.

`Dormant connections` is not a lane-local chat action. It is a workspace
navigation action.

The correct fix is not to add `openDormantConnections` to
`ChatScreenActionId`.

That would leak workspace navigation into the lane contract and recreate the
same ownership problem we already spent earlier phases removing.

Recommended fix:

- keep `ChatScreenContract` lane-local
- broaden the app-chrome overflow seam so the workspace shell can inject
  supplemental menu actions

The simplest durable contract is a chrome-level menu entry model with a label,
destructive flag, and callback, rather than a lane enum.

### 3. Transcript scroll state is still widget-local

`TranscriptList` owns its own `ScrollController`.

See:

- `lib/src/features/chat/presentation/widgets/transcript/transcript_list.dart`

This means Phase 4 has to account for more than lane lifecycle.

The lane runtime is safe above the widget tree now, but transcript scroll
position can still reset if offscreen lane widgets are discarded and rebuilt.

Recommended first cut:

- host each live lane page in a keep-alive page widget
- let the lane widget subtree remain alive while the connection is live

This is the simplest correct answer because:

- live lanes are already explicit runtime objects
- the feature goal is concurrent live lanes, not aggressive widget eviction
- it preserves scroll and local input state without inventing a new scroll-state
  persistence layer

If memory pressure becomes a later issue, scroll state can be lifted
deliberately. That should not be the first Phase 4 move.

### 4. `ChatRootAdapter` should stay intact

`ChatRootAdapter` already renders a complete lane.

See:

- `lib/src/features/chat/presentation/chat_root_adapter.dart`

Phase 4 should reuse it directly as lane-page content.

Do not split it apart again at the workspace layer just to mount paging or a
sidebar.

That would reintroduce coupling and duplicate platform rendering decisions that
the lane renderer delegate already owns.

## Recommended Phase 4 Architecture

### 1. Add a workspace shell widget above `ChatRootAdapter`

Add a dedicated workspace shell layer in `lib/src/features/workspace/...` that:

- listens to `ConnectionWorkspaceController`
- decides between mobile and desktop layout
- renders either lane pages or the dormant roster surface

This shell should own:

- `PageController` on mobile
- sidebar layout on desktop
- shell-level overflow actions such as `Dormant connections`

It should not own:

- lane session logic
- lane transcript projection
- connection settings save semantics

### 2. Add shell viewport state to the workspace controller

Recommended model:

- `selectedConnectionId` continues to represent the active live lane
- a new shell viewport value represents whether the UI is showing:
  - the live lane surface
  - the dormant roster surface

Recommended behavior:

- `selectConnection(connectionId)` selects the lane and switches viewport back
  to live lanes
- `showDormantRoster()` keeps the selected live lane intact but switches the
  visible workspace surface
- instantiating a dormant connection selects it and switches viewport back to
  live lanes

This keeps the shell state explicit and avoids a `PageController` becoming
hidden application state.

### 3. Extend app chrome with shell-level overflow entries

Do not extend `ChatScreenActionId`.

Instead, broaden the app chrome so it can render a merged overflow menu from:

- lane-local menu actions
- workspace-level menu actions

Recommended seam:

- keep lane toolbar actions lane-local
- replace the enum-typed overflow entries with a chrome-level menu action model
- let the workspace shell pass a `Dormant connections` menu action when needed

This keeps the lane presenter clean while still reusing:

- `ChatAppChromeTitle`
- `ChatOverflowMenuButton`
- the current material and cupertino chrome widgets

### 4. Mobile shell should use `PageView`

Recommended structure:

- one page per live lane in saved-connection order
- one trailing page for the dormant roster
- `PageView` for swipe navigation
- `PageController` synchronized with workspace state

Recommended page host structure:

- `ConnectionLanePageHost`
- `AutomaticKeepAliveClientMixin`
- stable `ValueKey(connectionId)`

Why this is the best cut:

- it uses stock Flutter primitives
- it preserves live-lane widget state while lanes remain live
- it aligns exactly with the requested swipe behavior
- it does not require custom gesture logic

### 5. Desktop shell should use a custom sidebar, not `NavigationRail`

Recommended structure:

- `Row`
- fixed-width `ConstrainedBox` sidebar
- main content `Expanded`
- `ListView` sections for `Live` and `Dormant`

The sidebar rows should be custom list rows built from stock primitives such as:

- `Material`
- `InkWell`
- `Padding`
- `Text`
- `DecoratedBox`

Why not `NavigationRail`:

- it does not handle grouped live and dormant sections well
- it assumes a flatter destination model than this feature needs
- it makes richer row subtitles and management affordances awkward

The T3 reference is still useful as a pattern reminder:

- shell-level sidebar
- grouped project or connection navigation
- stable ordering above transcript state

But Pocket Relay should build the desktop shell from Flutter primitives, not
try to mimic the T3 component API.

### 6. The dormant roster should be a first-class workspace surface

On mobile, it is the trailing page in the `PageView`.

On desktop, it should be available as a main-pane workspace surface even though
the sidebar also lists dormant connections.

That keeps the menu action behavior coherent across platforms:

- on mobile, `Dormant connections` jumps to the roster page
- on desktop, `Dormant connections` switches the main pane to the dormant
  roster surface

This is cleaner than making the menu action behave only on mobile.

### 7. Multiple projects on the same host are already supported by the model

Connection identity is already `connectionId`, not host.

The Phase 4 UI should make that visible by rendering more than just host in the
sidebar and roster.

Recommended row content:

- primary: `profile.label`
- secondary:
  - remote: `host` and `workspaceDir`
  - local: `local Codex` and `workspaceDir`

That prevents same-host projects from looking duplicated in the UI.

## Recommended Phase 4 Slice Order

### Slice 4.1: Shell state and chrome seam

- add workspace viewport state
- add `showDormantRoster()` behavior
- broaden app-chrome overflow actions so shell actions can coexist with lane
  actions
- keep the current one-lane shell as the degenerate case

This slice should not introduce `PageView` yet.

### Slice 4.2: Mobile pager shell

- add `ConnectionWorkspacePager`
- map live lanes plus trailing roster page into `PageView`
- keep lane pages alive while live
- sync page changes back into workspace state
- wire the `Dormant connections` overflow action to the roster page

Required verification:

- swiping to another lane does not dispose the previous live lane
- swiping to the roster does not lose the last selected live lane
- using the overflow action jumps directly to the roster page

### Slice 4.3: Desktop sidebar shell

- add persistent sidebar layout
- render `Live` and `Dormant` groups
- selecting a live entry switches the main pane to that lane
- selecting `Dormant connections` switches the main pane to the roster surface

Required verification:

- live and dormant sections render stable saved-connection order
- selecting one live lane does not affect other live lane bindings
- the desktop shell does not own lane disposal

### Slice 4.4: Roster interactions and hardening

- wire instantiate from roster
- wire terminate from live lane or sidebar affordances
- add roster row widgets with stable labels and subtitles
- add widget tests around page count, sidebar sections, and non-disposal of
  offscreen live lanes

This slice should still stop short of full settings-retargeting behavior.

## Phase Boundary Correction

Earlier planning treated dormant edit and delete affordances as Phase 4 minimum
actions. That is too aggressive for the clean ownership boundary.

The better boundary is:

- Phase 4 owns navigation, lane switching, roster visibility, and lane
  instantiation or termination
- Phase 5 owns saved-connection editing semantics and live reconnect behavior

That means Phase 4 should not be blocked on:

- retargeting the settings sheet for dormant connections
- deciding how live edits reconcile with already-running lanes
- wiring reconnect confirmation behavior

Phase 4 should ship the shell first.

Phase 5 should then make connection management inside that shell correct.

## Recommended Immediate Next Implementation

The next implementation slice should be:

1. add shell viewport state to `ConnectionWorkspaceState`
2. add workspace-level `showDormantRoster()` behavior
3. broaden the app-chrome overflow contract so `Dormant connections` can be
   injected by the shell without touching `ChatScreenActionId`

That is the lowest-risk entry point because it unlocks both mobile paging and
desktop sidebar work without forcing a UI rewrite first.
