# Saved Connections Lifecycle UX Maximization Plan

## Why This Doc Exists

The current workspace connection experience is structurally correct in parts but
still confusing as a product.

The main problem is not styling. The main problem is split lifecycle ownership:

- the saved-connections page shows inventory plus `Open lane`, `Edit`, and
  `Delete`
- the live lane strip shows `Connect` and `Reconnect`
- the live lane overflow menu hides `Disconnect`
- desktop adds another inventory surface in the sidebar

That split makes the connection lifecycle feel accidental instead of designed.

This document defines the UX target and the migration order for fixing that
problem without breaking live-turn continuity.

This plan narrows and updates
[`076_workspace_connection_ux_overhaul_plan.md`](./076_workspace_connection_ux_overhaul_plan.md)
for the specific saved-connections lifecycle problem now visible on `master`.

## Scope

This document covers:

- the mobile saved-connections page
- the shared saved-connections content used by mobile and desktop
- the desktop workspace sidebar inventory
- the live-lane connection strip
- the live-lane menu actions that currently hide lifecycle controls

This document does not redesign:

- transcript rendering
- connection settings field layout
- conversation history presentation
- background continuity architecture

## Current Product Reality

### Current Saved-Connections Page

The mobile saved-connections page is only a `Scaffold` whose body is
`ConnectionWorkspaceSavedConnectionsContent` in
[`lib/src/features/workspace/presentation/workspace_mobile_shell.dart`](../lib/src/features/workspace/presentation/workspace_mobile_shell.dart).

The shared content currently renders:

- page title
- descriptive copy
- `Add connection`
- either an empty state or a flat list of saved-connection panels

See:

- [`lib/src/features/workspace/presentation/workspace_saved_connections_content.dart`](../lib/src/features/workspace/presentation/workspace_saved_connections_content.dart)
- [`lib/src/features/workspace/presentation/workspace_saved_connections_content_shell.dart`](../lib/src/features/workspace/presentation/workspace_saved_connections_content_shell.dart)
- [`lib/src/features/workspace/presentation/workspace_saved_connections_content_items.dart`](../lib/src/features/workspace/presentation/workspace_saved_connections_content_items.dart)

Each saved-connection row currently mixes:

- connection label
- connection subtitle
- inventory badges
- optional remote status summary
- `Open lane` or `Go to lane`
- `Edit`
- optional `Delete`

### Current Lane Lifecycle Surface

The live lane currently owns:

- visible `Connect` and `Reconnect`
- transport recovery notices
- remote-runtime preparation before connect

See:

- [`lib/src/features/workspace/presentation/workspace_live_lane_surface.dart`](../lib/src/features/workspace/presentation/workspace_live_lane_surface.dart)

The live lane menu currently owns:

- `Saved connections`
- `Conversation history`
- `Disconnect`
- `Close lane`

See:

- [`lib/src/features/workspace/presentation/workspace_live_lane_surface_menu.dart`](../lib/src/features/workspace/presentation/workspace_live_lane_surface_menu.dart)

### Current Desktop Split

Desktop also renders a separate inventory in the sidebar and then a dedicated
saved-connections page in the main panel.

See:

- [`lib/src/features/workspace/presentation/workspace_desktop_shell.dart`](../lib/src/features/workspace/presentation/workspace_desktop_shell.dart)
- [`lib/src/features/workspace/presentation/workspace_desktop_shell_sidebar.dart`](../lib/src/features/workspace/presentation/workspace_desktop_shell_sidebar.dart)
- [`lib/src/features/workspace/presentation/workspace_desktop_shell_sidebar_expanded.dart`](../lib/src/features/workspace/presentation/workspace_desktop_shell_sidebar_expanded.dart)

### State Already Available

The app already knows the real lifecycle facts needed for a coherent UX:

- live vs non-live connections
- current selection
- reconnect requirements
- transport recovery phase
- live-reattach phase
- remote runtime by connection

See:

- [`lib/src/features/workspace/domain/connection_workspace_state.dart`](../lib/src/features/workspace/domain/connection_workspace_state.dart)
- [`lib/src/features/workspace/application/connection_workspace_inventory.dart`](../lib/src/features/workspace/application/connection_workspace_inventory.dart)

## Why The Current UX Feels Wrong

### 1. The primary lifecycle is not visible from one place

Users need to answer a simple question:

`What is the next correct thing to do for this connection right now?`

The current product makes them infer that answer across multiple surfaces.

### 2. Disconnect is treated like a rare expert action

`Disconnect` is a normal lifecycle action for a live remote lane, but it is
currently hidden in the overflow menu. That lowers discoverability and falsely
implies that `Close lane` is the main visible exit path.

### 3. The saved-connections page is passive when it should be operational

The saved-connections page knows enough to show whether a connection is open,
current, disconnected, or needs reconnect, but it mostly presents that state as
badges and a short summary instead of a clear control surface.

### 4. Desktop duplicates navigation without unifying meaning

Desktop shows a sidebar inventory and a saved-connections page, but those
surfaces do not form one obvious product story. They partly duplicate each
other while exposing different actions.

### 5. The distinction between `Disconnect`, `Reconnect`, `Close lane`, and
`Delete` is too implicit

These are materially different actions:

- `Disconnect` preserves the lane but detaches transport
- `Reconnect` restores a live lane
- `Close lane` removes the active lane surface
- `Delete` removes the saved connection definition

The current UX leaves those distinctions under-explained.

## Hard Product Constraints

These are not optional design preferences.

- Active turn continuity must remain intact during ordinary app switching.
- The frontend must reflect real backend/runtime states only.
- Settings remain a connection-definition editor, not a second lifecycle
  control plane.
- The redesign must not introduce speculative product states.
- `Disconnect` and `Close lane` must remain distinct actions.
- Local connections must not be forced through remote host/server language.

## UX Principles

### One lifecycle grammar

The same lifecycle language and action priority should appear in the hub, the
desktop inventory, and the live lane.

Why:

- repeated but inconsistent logic is what created the current confusion
- users should not have to learn different control models per surface

### One primary action per connection row

Each row should expose a single dominant next step derived from real state.

Why:

- rows are easier to scan when the main action is obvious
- multiple equal-weight buttons force the user to interpret system state first

### Visible common actions, hidden rare actions

Frequent lifecycle actions should be visible. Low-frequency diagnostics and
special-case tools can remain secondary.

Why:

- hiding `Disconnect` harms everyday usability
- hiding `Conversation history` does not

### Literal status over decorative status

The UI should state concrete lifecycle facts instead of relying on generic
badges plus prose fragments.

Why:

- badges like `Open` and `Current` are useful but insufficient
- lifecycle reasoning needs explicit transport and reconnect context

### The hub is the map, the lane is the cockpit

The connections hub should answer which connections exist and what attention
they need. The live lane should expose the active lane controls without sending
users on a hunt through menus.

Why:

- the hub is the best place to compare many connections
- the lane is the best place to operate the currently open one

## Target Product Model

### Rename The Mental Model To `Connections`

Use `Connections` as the top-level mental model and treat `Saved connections`
as one section within it.

Why:

- the product already uses `Connections` as the workspace title
- the page is no longer only a dormant roster; it is the user’s connection map

### Hub Sections

The connections hub should render sections in this order:

1. `Current lane`
2. `Open lanes`
3. `Needs attention`
4. `Saved connections`

Why:

- current and live work comes first
- reconnect-required rows deserve elevation above dormant rows
- dormant saved connections still matter, but they are the lowest urgency

Rules:

- `Current lane` contains at most one row
- `Open lanes` contains live rows that are not current and do not need urgent
  attention
- `Needs attention` contains rows with reconnect requirements, transport loss,
  unsupported host state, host check failure, or configuration incompleteness
- `Saved connections` contains non-live rows without immediate attention

### Shared Row Anatomy

Every connection row should render four regions in this order:

1. identity
2. lifecycle facts
3. primary action
4. secondary actions

#### Identity

Show:

- label
- local or remote mode
- host and workspace summary

Why:

- identity must remain visible even when the row is dense with lifecycle state

#### Lifecycle Facts

Show literal facts, not only badges:

- lane state
- transport state
- host state
- remote server state
- settings sync state

Why:

- these are the real determinants of what action should be available

#### Primary Action

Show exactly one dominant action per row:

- dormant saved row: `Open lane`
- live connected row: `Go to lane`
- live disconnected row: `Connect`
- reconnect-required row: `Reconnect` or `Apply changes`
- current lane row: `Go to lane` is omitted because the user is already there

Why:

- the row should communicate the next correct step immediately

#### Secondary Actions

Show a compact, visible row of secondary actions:

- `Disconnect` when transport is connected
- `Edit` when settings are relevant
- `Close lane` for live rows
- `Delete` for dormant rows only

Why:

- these actions are important enough to deserve visibility
- they are still clearly less important than the primary action

### Shared Lifecycle Facts

The app should standardize on these visible facts:

- `Lane: Current`, `Lane: Open`, `Lane: Closed`
- `Transport: Connected`, `Transport: Disconnected`, `Transport: Reconnecting`
- `Host: Checking`, `Host: Supported`, `Host: Unsupported`, `Host: Check failed`
- `Server: Running`, `Server: Stopped`, `Server: Unhealthy`, `Server: Checking`
- `Settings: Changes pending`

Why:

- these map directly to the real workspace and remote-runtime state
- they reduce ambiguity between inventory badges and lane notices

### Shared Action Precedence

Action priority must be deterministic.

Order:

1. recovery or reconnect
2. connect
3. navigate to lane
4. edit
5. disconnect
6. close lane
7. delete

Why:

- recovery-sensitive actions should outrank ordinary navigation
- destructive or terminal actions should not be mistaken for the default path

## What Moves And What Does Not

### What Must Become Visible

- `Disconnect` must move out of the live-lane overflow menu and become a visible
  secondary action for live remote rows and the live lane header/strip
- `Close lane` must remain visible and separate from `Disconnect`
- reconnect-needed rows must become visually elevated in the hub

### What Stays Secondary

- `Conversation history`
- low-frequency diagnostics like explicit host checks
- explicit remote server `Stop` and `Restart` controls

Why:

- these are useful, but they are not the first answer to normal connection
  lifecycle tasks

### What Must Not Move Back Into Settings

- transport connect/disconnect
- reconnect actions
- remote server control-plane actions

Why:

- settings is not the runtime control surface
- moving lifecycle back into settings would recreate split ownership

## Proposed Ownership Model

### New Presentation Model

Create an app-owned presentation model for lifecycle rows instead of passing
around loose badges and one optional summary string.

Suggested shape:

- `ConnectionLifecyclePresentation`
- `ConnectionLifecycleFact`
- `ConnectionLifecyclePrimaryAction`
- `ConnectionLifecycleSecondaryAction`

Why:

- the current `ConnectionWorkspaceInventoryEntry` is enough for lightweight
  inventory, but not enough for a first-class lifecycle control surface
- a presentation model allows the hub and lane to share the same rendering
  grammar without corrupting domain state

### New Shared Widgets

Introduce shared workspace-owned widgets:

- `ConnectionLifecycleSection`
- `ConnectionLifecycleRow`
- `ConnectionLifecycleFacts`
- `ConnectionLifecycleActionBar`

Why:

- the redesign should reduce future churn, not create another page-specific
  custom widget stack

### Lane Surface Role

The live lane should reuse the same action grammar but remain a lane-owned
surface.

It should:

- expose `Connect`, `Reconnect`, and `Disconnect` visibly
- expose `Close lane` visibly but as a lower-emphasis action
- continue to show recovery notices inline

It should not:

- turn into a full inventory page
- duplicate the entire connections hub inside the lane

## Decision Log

### Decision 1: Promote `Disconnect` to a visible action

Decision:

- `Disconnect` moves from the overflow menu into visible secondary actions

Why:

- it is a normal lifecycle control for live remote lanes
- hiding it creates a false hierarchy where `Close lane` looks more available
  than transport detach

Tradeoff:

- the lane chrome becomes slightly denser

Why that tradeoff is correct:

- discoverability of a normal action is more valuable than preserving minimal
  chrome at the cost of user confusion

### Decision 2: Keep `Disconnect` and `Close lane` separate

Decision:

- never collapse these into one generalized exit affordance

Why:

- they have different effects on continuity and lane persistence
- collapsing them would destroy a real product distinction

### Decision 3: Keep the hub operational, not purely navigational

Decision:

- the hub should expose lifecycle actions directly instead of acting only as a
  roster

Why:

- users should not have to enter a lane just to perform common lifecycle tasks
- the hub already has enough state to support correct action selection

### Decision 4: Keep expert server controls secondary

Decision:

- do not promote `Start server`, `Stop server`, and `Restart server` to the
  same level as `Connect` and `Disconnect`

Why:

- the current lane connect flow already performs the needed server preparation
- manual server operations are expert or recovery actions, not normal user
  actions

### Decision 5: Replace flat lists with urgency-based sections

Decision:

- segment the hub by current/live/attention/dormant state

Why:

- a flat list forces the user to scan every row equally
- urgency-based grouping makes lifecycle attention obvious

### Decision 6: Use literal lifecycle facts instead of mostly badges

Decision:

- move from badge-led rows to fact-led rows

Why:

- badges compress too much meaning
- lifecycle control depends on understanding transport and remote runtime state

### Decision 7: Standardize action order everywhere

Decision:

- the same primary and secondary action order appears in mobile hub, desktop
  inventory, and live lane

Why:

- interaction predictability matters more than local widget convenience

## Migration Plan

### Phase 0: Lock The UX Contract In Tests

Goal:

- create a failing-forward safety net before major UI changes

Work:

- add widget tests that assert visible `Disconnect` for live remote lanes
- add tests that distinguish `Disconnect` from `Close lane`
- add tests that assert reconnect-needed rows sort into an attention section
- add tests that local rows do not show remote host/server facts

Why first:

- this migration changes interaction hierarchy, so regressions are likely

### Phase 1: Introduce Lifecycle Presentation Mapping

Goal:

- create a shared presentation model that derives row facts and actions from
  `ConnectionWorkspaceState`

Work:

- add a mapper from workspace state to lifecycle-row presentation
- keep domain state unchanged
- keep the current UI behavior initially, using the new mapper behind the old
  widgets where practical

Why now:

- shared mapping is the prerequisite for a coherent redesign across hub and
  lane

Primary files:

- [`lib/src/features/workspace/domain/connection_workspace_state.dart`](../lib/src/features/workspace/domain/connection_workspace_state.dart)
- [`lib/src/features/workspace/presentation/connection_lifecycle_presentation.dart`](../lib/src/features/workspace/presentation/connection_lifecycle_presentation.dart)
- [`lib/src/features/workspace/presentation/connection_lifecycle_widgets.dart`](../lib/src/features/workspace/presentation/connection_lifecycle_widgets.dart)

### Phase 2: Rebuild The Saved-Connections Surface As A Connections Hub

Goal:

- replace the flat list with sectioned lifecycle inventory

Work:

- convert the page into sectioned content
- add `Current lane`, `Open lanes`, `Needs attention`, and `Saved connections`
- keep `Add connection` in the page header
- preserve existing open/edit/delete behavior while moving to the new row model

Why before lane chrome:

- the hub is the biggest source of lifecycle ambiguity today

Primary files:

- [`lib/src/features/workspace/presentation/workspace_saved_connections_content.dart`](../lib/src/features/workspace/presentation/workspace_saved_connections_content.dart)
- [`lib/src/features/workspace/presentation/workspace_saved_connections_content_shell.dart`](../lib/src/features/workspace/presentation/workspace_saved_connections_content_shell.dart)
- [`lib/src/features/workspace/presentation/workspace_saved_connections_content_items.dart`](../lib/src/features/workspace/presentation/workspace_saved_connections_content_items.dart)

### Phase 3: Unify Desktop Sidebar With The Same Lifecycle Grammar

Goal:

- stop desktop from feeling like a separate product

Work:

- update the sidebar rows to use the same lifecycle facts and action priority
- remove duplicated meanings where the sidebar and hub disagree
- decide whether the sidebar remains compact navigation or receives a compact
  version of the same action grammar

Recommendation:

- keep the sidebar compact, but make its facts and selection semantics match
  the hub exactly

Why:

- desktop still benefits from a compact sidebar
- full action duplication in the sidebar would create noise and repeated chrome

Primary files:

- [`lib/src/features/workspace/presentation/workspace_desktop_shell_sidebar.dart`](../lib/src/features/workspace/presentation/workspace_desktop_shell_sidebar.dart)
- [`lib/src/features/workspace/presentation/workspace_desktop_shell_sidebar_expanded.dart`](../lib/src/features/workspace/presentation/workspace_desktop_shell_sidebar_expanded.dart)

### Phase 4: Promote Lane Lifecycle Controls Out Of The Menu

Goal:

- make the live lane visibly controllable

Work:

- move `Disconnect` into the visible lane strip or a lane-owned action bar
- keep `Close lane` visible and lower emphasis
- leave `Conversation history` in the menu
- keep recovery notices inline with the lane lifecycle region

Why here:

- once the hub grammar exists, the lane can align to it without guesswork

Primary files:

- [`lib/src/features/workspace/presentation/workspace_live_lane_surface.dart`](../lib/src/features/workspace/presentation/workspace_live_lane_surface.dart)
- [`lib/src/features/workspace/presentation/workspace_live_lane_surface_menu.dart`](../lib/src/features/workspace/presentation/workspace_live_lane_surface_menu.dart)

### Phase 5: Add Secondary Lifecycle Details For Remote Rows

Goal:

- expose advanced but non-primary runtime details without overwhelming the main
  row

Work:

- add an expandable or compact details region for host/server facts
- keep `Check host`, `Restart server`, and `Stop server` secondary
- ensure local rows never render remote-runtime language

Why after the main redesign:

- secondary details only make sense after the primary lifecycle hierarchy is
  clear

### Phase 6: Copy And Label Normalization

Goal:

- make lifecycle labels literal and consistent

Work:

- audit `ConnectionWorkspaceCopy`
- prefer direct labels such as `Needs attention`, `Changes pending`, and
  `Transport disconnected`
- remove leftover wording that assumes the user already understands the split
  control model

Primary files:

- [`lib/src/features/workspace/application/connection_workspace_copy.dart`](../lib/src/features/workspace/application/connection_workspace_copy.dart)
- [`lib/src/features/workspace/application/connection_lifecycle_errors.dart`](../lib/src/features/workspace/application/connection_lifecycle_errors.dart)

### Phase 7: Verification And Cleanup

Goal:

- ensure the redesign is behaviorally correct and structurally coherent

Work:

- widget tests for hub sections and row actions
- widget tests for lane action visibility
- focused mobile and desktop shell tests
- manual verification of ordinary app switching to ensure live lanes are not
  disconnected or rebuilt unnecessarily
- delete obsolete presentation helpers and stale menu-only lifecycle paths

## Verification Matrix

Minimum cases to prove:

- dormant remote saved connection
- dormant local saved connection
- current live connected remote lane
- non-current live connected remote lane
- live remote lane with saved settings pending
- live remote lane with transport reconnect required
- host unsupported
- host check failed
- server stopped
- server unhealthy
- empty workspace
- desktop sidebar compact state
- desktop sidebar expanded state
- mobile saved-connections page

## Non-Goals

- rebuilding settings around lifecycle actions
- inventing historical/local transcript ownership
- introducing speculative review chrome or new card layers
- widening the change into a full workspace visual redesign unrelated to
  lifecycle comprehension

## Recommended Start Order

If implementation begins immediately, use this order:

1. Phase 0
2. Phase 1
3. Phase 2
4. Phase 4
5. Phase 3
6. Phase 5
7. Phase 6
8. Phase 7

Reason:

- tests first
- shared lifecycle mapping second
- mobile/shared hub before lane promotion because the hub is the largest UX gap
- lane promotion before desktop polish because the hidden disconnect problem is
  more severe than desktop duplication

## Definition Of Done

This migration is done when all of the following are true:

- the user can understand a connection’s current lifecycle state from one row
- the user can find `Disconnect` without opening an overflow menu
- `Disconnect`, `Reconnect`, `Close lane`, and `Delete` are visibly distinct
- reconnect-required connections are elevated above dormant rows
- mobile and desktop share one lifecycle grammar
- the live lane remains continuity-safe during ordinary app switching
- settings is still not a lifecycle control plane
- old duplicate ownership paths have been deleted, not merely hidden
