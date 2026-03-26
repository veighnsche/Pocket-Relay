# Workspace Connection UX Overhaul Plan

## Why This Doc Exists

`feat/true-live-turn-continuity` reached a point where the underlying
continuity/runtime work was substantially implemented, but the end-user
workspace UX was still structurally inconsistent.

The result is a branch where multiple things are individually "implemented"
while the overall product model is still confusing:

- the saved-connections inventory and live lanes both try to act like the
  control plane
- lane state, remote host state, and transport state are split across multiple
  surfaces
- settings still expose ownership that now belongs to the lane
- the product was still using misleading "Pocket Relay server" language for a
  managed remote Codex app-server
- host identity/fingerprint behavior is runtime-required but not yet modeled as
  a first-class UX flow

This document is the active execution backlog for fixing that structural UX
problem.

It supersedes the "no remaining work" claim in
[`073_true_live_turn_continuity_remaining_work_plan.md`](./073_true_live_turn_continuity_remaining_work_plan.md)
for workspace UX ownership. The continuity architecture may be largely present,
but the user-facing workspace structure is not finished.

## Status On `feat/workspace-connection-ux-overhaul`

The recommended structural cleanup from this document is now implemented on
[`feat/workspace-connection-ux-overhaul`](../).

Completed on that branch:

- Pass 1: terminology correction across runtime/error surfaces
- Pass 2: settings no longer own remote lifecycle controls
- Pass 3: host identity and fingerprint UX now reflects shared `host:port`
  ownership
- Pass 4: inventory/navigation is unified across desktop and mobile
- Pass 5: lane connection chrome is the single operational control surface
- Pass 6: `Open lane` now has explicit bootstrap semantics in the lane strip
- Pass 7: lane-level recovery/failure routing is unified around the lane bar
- Pass 8: conversation history is now a lane-owned action instead of a menu-owned
  detached tool
- Pass 9: obsolete menu-model artifacts were deleted

Remaining follow-up is mostly broader release verification, not another
workspace ownership redesign.

## Problem Statement

Pocket Relay currently has too many overlapping connection surfaces:

- the saved-connections roster
- the desktop sidebar
- the mobile saved-connections page
- the live lane strip
- the live lane reconnect footer
- the connection settings sheet
- transcript-level SSH/runtime failure surfaces

These surfaces do not yet form one coherent product story.

The target model is:

- saved connections = inventory and entry point
- live lane = current connection truth and operational controls
- settings = connection definition editor, not lifecycle control plane
- transcript/runtime surfaces = direct protocol/runtime evidence

## Hard Constraints

- Do not break active-turn continuity during ordinary app switching.
- Do not move runtime truth into Widgetbook, tests, or preview-only glue.
- Do not reintroduce automatic hidden server lifecycle behavior.
- Do not present backend states that are not traceable to real runtime truth.
- Do not re-spread card/panel UI regressions while restructuring surfaces.
- Do not preserve duplicated ownership just to keep diffs smaller.

## Completed Passes

### Pass 0: Lane Status Strip Ownership

This pass is already implemented on the branch.

Completed outcomes:

- live lanes now own a persistent connection-status strip
- the strip can show:
  - connected
  - disconnected
  - connecting
  - host unknown
  - host checking
  - host check failed
  - server stopped
  - server unhealthy
  - reconnect needed
  - configuration incomplete
- the live lane now owns:
  - `Check host`
  - `Start server`
  - `Restart server`
  - `Connect`
- the saved-connections roster no longer renders remote server control buttons
- the generic chat renderer only exposes a status-region slot; it does not own
  workspace logic

Primary files:

- [`lib/src/features/workspace/presentation/workspace_live_lane_surface.dart`](../lib/src/features/workspace/presentation/workspace_live_lane_surface.dart)
- [`lib/src/features/workspace/presentation/workspace_saved_connections_content.dart`](../lib/src/features/workspace/presentation/workspace_saved_connections_content.dart)
- [`lib/src/features/workspace/presentation/workspace_saved_connections_content_items.dart`](../lib/src/features/workspace/presentation/workspace_saved_connections_content_items.dart)
- [`lib/src/features/chat/lane/presentation/chat_root_adapter.dart`](../lib/src/features/chat/lane/presentation/chat_root_adapter.dart)

## Execution Passes

### Pass 1: Terminology Correction

Goal:

- replace misleading "Pocket Relay server" language with truthful product
  wording for the managed remote Codex app-server lifecycle

Why:

- the current language implies a bespoke backend install on each host
- that directly damages user understanding of what the product is doing

Required outcomes:

- user-facing copy distinguishes:
  - host capability
  - managed remote app-server state
  - lane transport attachment
- error meanings stay stable while wording becomes truthful

Likely files:

- [`lib/src/features/workspace/application/connection_workspace_copy.dart`](../lib/src/features/workspace/application/connection_workspace_copy.dart)
- [`lib/src/features/workspace/application/connection_lifecycle_errors.dart`](../lib/src/features/workspace/application/connection_lifecycle_errors.dart)
- [`lib/src/core/errors/pocket_error.dart`](../lib/src/core/errors/pocket_error.dart)
- [`lib/src/features/workspace/application/connection_workspace_controller_remote_owner.dart`](../lib/src/features/workspace/application/connection_workspace_controller_remote_owner.dart)

Done when:

- no user-visible copy suggests a bespoke Pocket Relay backend must be installed

### Pass 2: Remove Dead Remote-Server Ownership From Settings

Goal:

- make connection settings a pure connection-definition editor

Why:

- the live lane now owns runtime lifecycle controls
- keeping remote server controls in settings preserves split ownership

Required outcomes:

- delete the `remoteServerSection` contract
- delete start/stop/restart callbacks from settings host/overlay plumbing
- delete the settings-side remote server presenter/surface
- update tests that still lock the old settings control-plane model

Likely files:

- [`lib/src/features/connection_settings/domain/connection_settings_contract.dart`](../lib/src/features/connection_settings/domain/connection_settings_contract.dart)
- [`lib/src/features/connection_settings/application/connection_settings_presenter.dart`](../lib/src/features/connection_settings/application/connection_settings_presenter.dart)
- [`lib/src/features/connection_settings/presentation/connection_settings_host.dart`](../lib/src/features/connection_settings/presentation/connection_settings_host.dart)
- [`lib/src/features/connection_settings/presentation/connection_settings_sheet_surface.dart`](../lib/src/features/connection_settings/presentation/connection_settings_sheet_surface.dart)
- [`lib/src/features/connection_settings/application/presenter/section_remote_server.dart`](../lib/src/features/connection_settings/application/presenter/section_remote_server.dart)

Done when:

- settings can no longer act as a second lifecycle control plane

### Pass 3: Host Identity And Fingerprint UX

Goal:

- make host identity a first-class concept instead of a raw per-profile text
  field that happens to be runtime-required

Why:

- multiple saved connections can target the same `host:port`
- runtime requires pinned fingerprints
- the current UX still treats fingerprint entry as low-level manual plumbing

Required outcomes:

- same-host connections clearly share one host identity
- the product explains when a host fingerprint is inherited/shared
- empty-fingerprint states are no longer ambiguous
- transcript host-key prompts flow back into that host identity model cleanly

Likely files:

- [`lib/src/features/connection_settings/application/presenter/section_profile.dart`](../lib/src/features/connection_settings/application/presenter/section_profile.dart)
- [`lib/src/core/storage/codex_connection_repository_secure.dart`](../lib/src/core/storage/codex_connection_repository_secure.dart)
- [`lib/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh/ssh_unpinned_host_key_surface.dart`](../lib/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh/ssh_unpinned_host_key_surface.dart)
- [`lib/src/features/chat/lane/application/chat_session_controller_prompt_flow.dart`](../lib/src/features/chat/lane/application/chat_session_controller_prompt_flow.dart)

Done when:

- the user no longer has to mentally manage fingerprint duplication per
  workspace entry

### Pass 4: Sidebar And Inventory Information Architecture

Goal:

- unify saved inventory and open-lane navigation into one coherent workspace
  map across desktop and mobile

Why:

- desktop still splits reality into `Open lanes` plus a separate saved section
- mobile still treats saved connections as a separate page rather than part of
  one coherent connection map

Required outcomes:

- consistent mental model across desktop and mobile
- active/open state, selected state, and reconnect-needed state are visible
  from the same inventory model
- no redundant inventory dumps in the sidebar

Likely files:

- [`lib/src/features/workspace/presentation/workspace_desktop_shell_sidebar_expanded.dart`](../lib/src/features/workspace/presentation/workspace_desktop_shell_sidebar_expanded.dart)
- [`lib/src/features/workspace/presentation/workspace_desktop_shell_sidebar_collapsed.dart`](../lib/src/features/workspace/presentation/workspace_desktop_shell_sidebar_collapsed.dart)
- [`lib/src/features/workspace/presentation/workspace_mobile_shell.dart`](../lib/src/features/workspace/presentation/workspace_mobile_shell.dart)
- [`lib/src/features/workspace/presentation/workspace_saved_connections_content.dart`](../lib/src/features/workspace/presentation/workspace_saved_connections_content.dart)

Done when:

- the user can answer "what connections exist, which are open, and which need
  attention?" from one coherent navigation model

### Pass 5: Lane Chrome Unification

Goal:

- collapse the lane strip, reconnect footer, menu affordances, and transient
  notices into one coherent connection-control story

Why:

- lane state is still split across multiple chrome regions
- reconnect and lifecycle actions still feel bolted on rather than designed

Required outcomes:

- one primary lane-level connection bar model
- menu actions are secondary, not parallel ownership
- reconnect actions, connect actions, and server actions do not compete

Likely files:

- [`lib/src/features/workspace/presentation/workspace_live_lane_surface.dart`](../lib/src/features/workspace/presentation/workspace_live_lane_surface.dart)
- [`lib/src/features/workspace/presentation/workspace_live_lane_surface_menu.dart`](../lib/src/features/workspace/presentation/workspace_live_lane_surface_menu.dart)
- [`lib/src/features/chat/lane/presentation/chat_root_adapter.dart`](../lib/src/features/chat/lane/presentation/chat_root_adapter.dart)

Done when:

- every operational action for the current lane has one obvious home

### Pass 6: Open-Lane Bootstrap Semantics

Goal:

- define exactly what `Open lane` means for a remote saved connection

Why:

- the product currently allows a lane to exist before the transport is attached
- that can be correct, but only if the UI contract is explicit and consistent

Required outcomes:

- the open-lane contract is literal in controller behavior and copy
- disconnected fresh lanes are intentional, not accidental leftovers
- bootstrap errors route cleanly into the lane-owned connection model

Likely files:

- [`lib/src/features/workspace/application/controller/bootstrap.dart`](../lib/src/features/workspace/application/controller/bootstrap.dart)
- [`lib/src/features/workspace/application/connection_workspace_controller_lane.dart`](../lib/src/features/workspace/application/connection_workspace_controller_lane.dart)
- [`lib/src/features/workspace/presentation/workspace_saved_connections_content.dart`](../lib/src/features/workspace/presentation/workspace_saved_connections_content.dart)

Done when:

- `Open lane` has one explicit product meaning and the UI reflects that meaning

### Pass 7: Recovery And Failure Surface Unification

Goal:

- unify host failures, auth failures, host-key failures, owner failures, and
  reconnect failures into one consistent recovery model

Why:

- the app currently spreads failure truth across snackbars, transcript blocks,
  notices, and settings
- some of that spread is correct, but the routing is not yet coherent

Required outcomes:

- direct protocol/runtime evidence still appears in transcript surfaces
- workspace-level recovery state stays in workspace-owned UI
- snackbars stop serving as the primary explanation for structural connection
  problems

Likely files:

- [`lib/src/features/workspace/application/connection_lifecycle_errors.dart`](../lib/src/features/workspace/application/connection_lifecycle_errors.dart)
- [`lib/src/features/workspace/presentation/workspace_live_lane_surface.dart`](../lib/src/features/workspace/presentation/workspace_live_lane_surface.dart)
- [`lib/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh`](../lib/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh)

Done when:

- each failure class has one clear primary home and one clear recovery path

### Pass 8: Conversation History Integration

Goal:

- integrate conversation history into the lane connection model instead of
  leaving it as a detached menu destination

Why:

- history availability depends on connection truth
- the current menu entry does not sufficiently express that dependency

Required outcomes:

- history entrypoints respect lane connection state
- disabled/error states are explicit
- resume behavior fits the lane connection/recovery model

Likely files:

- [`lib/src/features/workspace/presentation/workspace_live_lane_surface_menu.dart`](../lib/src/features/workspace/presentation/workspace_live_lane_surface_menu.dart)
- [`lib/src/features/workspace/presentation/workspace_conversation_history_sheet.dart`](../lib/src/features/workspace/presentation/workspace_conversation_history_sheet.dart)

Done when:

- history/resume feels like part of the lane system, not a separate tool

### Pass 9: Dead Structure Cleanup

Goal:

- delete the obsolete seams, contracts, and tests left behind by the old model

Why:

- cleanup deferred too long becomes another false ownership layer

Required outcomes:

- remove unused menu helpers and contracts that no longer represent the product
- remove low-signal tests that only preserve deleted architecture
- keep only tests that prove real ownership and runtime behavior

Done when:

- the codebase no longer contains a shadow version of the deleted UX model

### Pass 10: Final Verification And Real E2E Coverage

Goal:

- prove the final UX model against the real production path

Required outcomes:

- real app-level tests cover:
  - open lane
  - check host
  - start server
  - connect lane
  - reconnect lane
  - fingerprint save path
  - history resume path
- targeted widget tests prove ownership boundaries
- redundant reward-hack tests are removed or rewritten

Done when:

- the final verification matches the actual product structure rather than the
  intermediate implementation scaffolding

## Historical Recommended Execution Order

The highest-value order was:

1. Pass 2: remove dead remote-server ownership from settings
2. Pass 4: fix sidebar and inventory IA
3. Pass 5: unify lane chrome
4. Pass 7: unify recovery and failure surfaces
5. Pass 3: complete host identity/fingerprint UX
6. Pass 6: lock down open-lane bootstrap semantics
7. Pass 8: integrate conversation history
8. Pass 9: delete dead structure
9. Pass 10: final verification and E2E

Pass 1 terminology correction should happen continuously during the above work,
but it must be complete before release.

## Definition Of Done

This overhaul is finished only when all of the following are true:

- saved connections are clearly inventory, not a second control plane
- live lanes visibly tell the truth about host state, server state, and lane
  connection state
- connection settings edit the definition only
- host identity/fingerprint behavior is explicit and shared across same-host
  connections
- failure and recovery flows have one coherent routing model
- conversation history fits into the same connection story
- dead contracts from the old model are deleted
- verification covers the real production path

## References

- [`069_true_live_turn_continuity_contract.md`](./069_true_live_turn_continuity_contract.md)
- [`070_true_live_turn_continuity_migration_map.md`](./070_true_live_turn_continuity_migration_map.md)
- [`071_tmux_required_execution_plan.md`](./071_tmux_required_execution_plan.md)
- [`072_true_live_turn_continuity_slice_plan.md`](./072_true_live_turn_continuity_slice_plan.md)
- [`073_true_live_turn_continuity_remaining_work_plan.md`](./073_true_live_turn_continuity_remaining_work_plan.md)
