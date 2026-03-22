# iOS Background Restore Handoff

## Scope

This handoff covers the active work on branch:

- `fix/ios-background-restore`

The target issue is the one described in
[`docs/052_ios_background_ssh_resilience_plan.md`](../docs/052_ios_background_ssh_resilience_plan.md):

- iPhone may suspend the app shortly after backgrounding
- iPhone may later kill the suspended process for memory/resource management
- Pocket Relay must preserve the active lane and draft
- Pocket Relay must reconnect and restore from upstream history instead of
  pretending the in-memory SSH session survived

This work intentionally does not add app-local transcript history caching.

## What Was Implemented

### 1. Workspace recovery store

Added a real app-owned recovery store in:

- [`connection_workspace_recovery_store.dart`](../lib/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart)

It persists the minimum recovery state for the active selected lane:

- `connectionId`
- `selectedThreadId`
- `draftText`
- `backgroundedAt`

Available implementations:

- `SecureConnectionWorkspaceRecoveryStore`
- `MemoryConnectionWorkspaceRecoveryStore`
- `NoopConnectionWorkspaceRecoveryStore`

### 2. Workspace controller lifecycle ownership

Extended:

- [`connection_workspace_controller.dart`](../lib/src/features/workspace/application/connection_workspace_controller.dart)
- [`connection_workspace_controller_lifecycle.dart`](../lib/src/features/workspace/application/connection_workspace_controller_lifecycle.dart)
- [`connection_workspace_controller_lane.dart`](../lib/src/features/workspace/application/connection_workspace_controller_lane.dart)

New behavior:

- the controller persists recovery state when selected lane state changes
- on `inactive`, it snapshots the active selected lane without forcing a later
  reconnect by itself
- on actual background states (`hidden`, `paused`) it snapshots the active
  selected lane and marks the session as needing foreground recovery
- on `resumed`, if the app had actually backgrounded, it marks all live lanes as
  reconnect-required
- on `resumed`, it actively reconnects the selected live lane
- reconnect now preserves:
  - selected thread target
  - composer draft
- initialization now restores the previously selected lane if recovery state
  exists and the saved connection still exists
- initialization restores the saved draft immediately
- initialization restores the saved thread transcript from upstream history
  when a saved `selectedThreadId` exists

### 3. App lifecycle host

Added:

- [`workspace_app_lifecycle_host.dart`](../lib/src/features/workspace/presentation/widgets/workspace_app_lifecycle_host.dart)

Wired it into bootstrap in:

- [`pocket_relay_bootstrap.dart`](../lib/src/app/pocket_relay_bootstrap.dart)

This keeps lifecycle observation above lane/session controllers, which matches
the ownership requirement in the plan.

### 4. Dependency wiring

Updated:

- [`pocket_relay_dependencies.dart`](../lib/src/app/pocket_relay_dependencies.dart)
- [`pocket_relay_app.dart`](../lib/src/app/pocket_relay_app.dart)

The default app dependency path now uses:

- `SecureConnectionWorkspaceRecoveryStore`

For app/test entry points:

- `PocketRelayApp` now accepts an optional injected recovery store
- widget tests inject `MemoryConnectionWorkspaceRecoveryStore` so they do not
  depend on a platform `SharedPreferencesAsync` implementation

### 5. Lane draft restoration seam

Updated:

- [`connection_lane_binding.dart`](../lib/src/features/chat/lane/presentation/connection_lane_binding.dart)

Added `restoreComposerDraft(String text)` so recreated bindings can restore the
draft without moving draft ownership into Widgetbook/UI glue.

## Tests Added

Updated:

- [`connection_workspace_controller_test.dart`](../test/connection_workspace_controller_test.dart)
- [`workspace_app_lifecycle_host_test.dart`](../test/workspace_app_lifecycle_host_test.dart)

New coverage proves:

- initialization restores the persisted selected lane, draft, and transcript
  target
- reconnect preserves the composer draft on the recreated lane
- background then resume reconnects the selected lane, preserves its draft, and
  marks other live lanes stale
- the lifecycle host snapshots selected lane recovery state on pause
- the lifecycle host forwards pause/resume through the widget tree and preserves
  the selected lane draft across reconnect
- the full app boot path still wraps the workspace in the lifecycle host above
  the wake-lock host

## Verification Already Run

Passed:

- `dart analyze` on the changed files
- `test/connection_workspace_controller_test.dart`
- `test/connection_workspace_recovery_store_test.dart`
- `test/workspace_app_lifecycle_host_test.dart`
- `test/connection_workspace_mobile_shell_test.dart`
- `test/connection_workspace_desktop_shell_test.dart`
- `test/connection_workspace_surface_widgets_test.dart`
- `test/widget_test.dart`
- `test/workspace_turn_wake_lock_host_test.dart`
- `test/chat_screen_app_server_test.dart`

## Important Current Behavior

The current implementation restores the selected active lane after
background/termination. It does not fully cold-restore every previously live
lane.

That was a deliberate scope decision because the document says:

- preserve the active lane
- preserve the active draft
- restore the active screen honestly

This avoids inventing broader multi-lane resurrection semantics without an
explicit product requirement.

## Likely Next Work

### 1. Decide whether non-selected live lanes should also restore after cold start

Right now:

- all live lanes are marked reconnect-required after resume
- only the selected lane is actively reconnected immediately
- non-selected live lanes remain visible as stale until the user opens or
  reconnects them

This is reasonable, but it is still a product decision. If the requirement is
"restore all open lanes after process death", that needs explicit app-owned
persistence for more than one lane.

### 2. Add lifecycle/widget integration tests

The controller path is covered. There is still room for a focused widget test
around:

- `WorkspaceAppLifecycleHost`
- bootstrap wiring
- background/resume behavior through the actual widget tree

### 3. Consider diagnostics/observability

`docs/052_ios_background_ssh_resilience_plan.md` also calls for telemetry such
as:

- background timestamp
- resume timestamp
- whether recovery state existed
- whether reconnect succeeded
- whether transcript restore succeeded

This handoff branch does not implement that yet.

### 4. Consider whether reconnect-required UX copy should distinguish background recovery from saved-settings reconnect

Current behavior reuses the existing reconnect-required machinery. Structurally
that is good because it avoids a second reconnect stack, but the copy and badge
language may still read like "saved settings changed" rather than "app resumed
after possible suspension/termination."

If changed, keep the scope narrow and do not redesign the surrounding surface.

## Constraints To Preserve

- Do not add a local transcript history cache as fallback truth.
- Do not widen this into a general workspace redesign.
- Keep lifecycle ownership above lane/session controllers.
- Keep transcript restoration sourced from upstream thread history.
- Preserve the existing non-card surface language if touching UI.

## Files Changed On This Branch

- [`pocket_relay_bootstrap.dart`](../lib/src/app/pocket_relay_bootstrap.dart)
- [`pocket_relay_app.dart`](../lib/src/app/pocket_relay_app.dart)
- [`pocket_relay_dependencies.dart`](../lib/src/app/pocket_relay_dependencies.dart)
- [`connection_lane_binding.dart`](../lib/src/features/chat/lane/presentation/connection_lane_binding.dart)
- [`connection_workspace_controller.dart`](../lib/src/features/workspace/application/connection_workspace_controller.dart)
- [`connection_workspace_controller_lane.dart`](../lib/src/features/workspace/application/connection_workspace_controller_lane.dart)
- [`connection_workspace_controller_lifecycle.dart`](../lib/src/features/workspace/application/connection_workspace_controller_lifecycle.dart)
- [`connection_workspace_recovery_store.dart`](../lib/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart)
- [`workspace_app_lifecycle_host.dart`](../lib/src/features/workspace/presentation/widgets/workspace_app_lifecycle_host.dart)
- [`connection_workspace_controller_test.dart`](../test/connection_workspace_controller_test.dart)
- [`widget_test.dart`](../test/widget_test.dart)
- [`chat_screen_app_server_test.dart`](../test/chat_screen_app_server_test.dart)
- [`workspace_app_lifecycle_host_test.dart`](../test/workspace_app_lifecycle_host_test.dart)

## Recommended Restart Context

If another agent picks this up, start here:

1. [`docs/052_ios_background_ssh_resilience_plan.md`](../docs/052_ios_background_ssh_resilience_plan.md)
2. [`docs/053_ios_background_restore_handoff.md`](../docs/053_ios_background_restore_handoff.md)
3. [`connection_workspace_controller_lifecycle.dart`](../lib/src/features/workspace/application/connection_workspace_controller_lifecycle.dart)
4. [`connection_workspace_recovery_store.dart`](../lib/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart)
