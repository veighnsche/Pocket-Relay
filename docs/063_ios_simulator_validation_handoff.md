# iOS Simulator Validation Handoff

## Purpose

This handoff is for an agent running on a computer that has:

- macOS
- Xcode installed
- at least one iOS simulator available
- `flutter` working for iOS
- `xcrun simctl` available

The goal is to validate the iOS finite-background-grace path that now protects
live turns more honestly during ordinary app switching.

This is the iOS-specific counterpart to:

- [`059_background_execution_publishability_findings.md`](./059_background_execution_publishability_findings.md)
- [`060_background_execution_publishability_phased_plan.md`](./060_background_execution_publishability_phased_plan.md)
- [`061_android_sdk_validation_handoff.md`](./061_android_sdk_validation_handoff.md)

It is separate from the cold-start restore work documented in:

- [`053_ios_background_restore_handoff.md`](./053_ios_background_restore_handoff.md)

## Current Implementation To Validate

Relevant files:

- [`ios/Runner/AppDelegate.swift`](../ios/Runner/AppDelegate.swift)
- [`ios/Runner/SceneDelegate.swift`](../ios/Runner/SceneDelegate.swift)
- [`lib/src/core/device/background_grace_host.dart`](../lib/src/core/device/background_grace_host.dart)
- [`lib/src/core/platform/pocket_platform_behavior.dart`](../lib/src/core/platform/pocket_platform_behavior.dart)
- [`lib/src/features/workspace/presentation/widgets/workspace_turn_activity_builder.dart`](../lib/src/features/workspace/presentation/widgets/workspace_turn_activity_builder.dart)
- [`lib/src/features/workspace/presentation/widgets/workspace_turn_background_grace_host.dart`](../lib/src/features/workspace/presentation/widgets/workspace_turn_background_grace_host.dart)
- [`lib/src/features/workspace/presentation/widgets/workspace_turn_wake_lock_host.dart`](../lib/src/features/workspace/presentation/widgets/workspace_turn_wake_lock_host.dart)
- [`lib/src/app/pocket_relay_bootstrap.dart`](../lib/src/app/pocket_relay_bootstrap.dart)

Key facts:

- iOS uses a finite background task, not an Android-style foreground service.
- Flutter calls the method channel
  `me.vinch.pocketrelay/background_execution`.
- iOS handles `setFiniteBackgroundTaskEnabled`.
- the app is scene-based, so the native background-execution channel now
  registers from [`SceneDelegate.swift`](../ios/Runner/SceneDelegate.swift),
  not from `AppDelegate.window`
- background grace is only supposed to be requested while the app is not
  resumed and at least one live lane has an active turn
- blocked approval/input turns must still count as active for protection
- there is no iOS notification or foreground-service UI to expect here
- simulator validation can prove build/wiring/lifecycle behavior, but it cannot
  prove true iPhone suspension timing or indefinite SSH survival

Current commits that matter to this path:

- `4900d40` `WIP: add iOS background grace for live turns`
- `c7e3898` `Register iOS background channel from the scene`
- `7a52a23` `Keep blocked turns protected across workspace hosts`

## What Must Be Proved

The iOS simulator machine should validate all of the following:

- the app builds for iOS simulator
- the Swift scene-based channel wiring compiles cleanly
- ordinary app switching with no active turn does not force reconnect by itself
- a live turn survives ordinary app switching when transport actually remains
  alive
- a blocked approval/input turn is still treated as active for protection
- non-selected live lanes still count when determining whether a live turn is
  active
- no Android-only expectations leak onto iOS

Because simulator behavior can be too forgiving, the agent should be explicit
about which results are true simulator proof and which still require real-device
validation later.

## Local Verification Commands

From the repo root:

```bash
flutter doctor -v
flutter devices
xcrun simctl list devices
flutter test test/background_grace_host_test.dart
flutter test test/workspace_turn_background_grace_host_test.dart
flutter test test/workspace_turn_wake_lock_host_test.dart
flutter test test/workspace_app_lifecycle_host_test.dart
flutter test test/pocket_platform_behavior_test.dart
flutter test test/pocket_platform_policy_test.dart
flutter build ios --simulator --debug --no-codesign -t lib/main.dart
```

To run the app:

```bash
just ios-simulator
```

Or directly:

```bash
flutter run -d <simulator-id> -t lib/main.dart
```

## Recommended Native Validation

One important problem with the current Flutter host is that
[`background_grace_host.dart`](../lib/src/core/device/background_grace_host.dart)
intentionally swallows method-channel failures so the app stays usable.

That means "the app did not visibly break" is not strong enough proof that the
iOS channel is really wired correctly.

If possible, validate with Xcode as well:

1. Open `ios/Runner.xcworkspace`.
2. Run the app on an iOS simulator.
3. Set a breakpoint or logpoint in:
   - `SceneDelegate.registerBackgroundExecutionChannelIfNeeded()`
   - `BackgroundExecutionCoordinator.handleBackgroundExecutionCall(...)`
4. Confirm registration happens on launch.
5. Confirm `setFiniteBackgroundTaskEnabled(true)` is hit when backgrounding
   during an active turn.
6. Confirm `setFiniteBackgroundTaskEnabled(false)` is hit when returning to the
   foreground or after the turn no longer remains active.

If Xcode debugging is not used, record that the native method-channel path was
only validated indirectly.

## Manual iOS Simulator Test Matrix

Use a real remote connection that can run a visibly long Codex turn.

Background the simulator app with either:

- `Cmd` + `Shift` + `H`
- `xcrun simctl ui booted home`

### Scenario 1: No Active Turn

Steps:

1. Launch Pocket Relay on the simulator.
2. Do not start a turn.
3. Background the app.
4. Return to the app.

Expected:

- the selected lane is still the same lane on return
- Pocket Relay does not show reconnect-required solely because the app was
  backgrounded
- no special iOS notification or foreground-service UI appears

### Scenario 2: Active Turn Background And Return

Steps:

1. Launch Pocket Relay.
2. Open a live lane.
3. Start a prompt that runs long enough to observe.
4. Background the app while the turn is still running.
5. Return to Pocket Relay before the turn completes.

Expected:

- the same live lane is still selected on return
- the turn is still present and has not been force-reset by Pocket Relay
- the app does not silently drop into reconnect-required unless transport loss
  is real

### Scenario 3: Blocked Turn Background And Return

This matters because blocked turns pause the timer, and the branch now treats
them as still active for protection.

Steps:

1. Start a turn that will hit an approval or user-input request.
2. Wait until the blocked request UI is visible.
3. Background the app while the turn is blocked.
4. Return to Pocket Relay.

Expected:

- the blocked turn is still visible on return
- the request is still present
- Pocket Relay does not treat the blocked turn as inactive just because the
  timer stopped ticking

### Scenario 4: Non-Selected Live Lane

This matters because the shared activity builder watches all live lanes, not
only the selected lane.

Steps:

1. Create two live lanes.
2. Leave lane A selected.
3. Start a long-running turn on lane B.
4. Background the app.
5. Return to Pocket Relay.

Expected:

- lane B still behaves like the active lane that was running before background
- Pocket Relay does not narrow protection logic to only the selected lane

### Scenario 5: No Remaining Active Turn

Steps:

1. Start a turn.
2. Let it complete fully.
3. Background the app after completion.
4. Return to Pocket Relay.

Expected:

- there is no stale "active turn" behavior after completion
- the app resumes normally

## Useful Simulator Checks

Launch the app from the simulator shell:

```bash
xcrun simctl launch booted me.vinch.pocketrelay
```

Return to the app after backgrounding:

```bash
xcrun simctl launch booted me.vinch.pocketrelay
```

Stream simulator logs:

```bash
flutter logs -d <simulator-id>
```

Or use unified logging:

```bash
xcrun simctl spawn booted log stream --level debug --style compact
```

If the agent uses Xcode breakpoints instead, record that as the source of truth
for native channel validation.

## Pass Criteria

iOS simulator validation passes only if all of the following are true:

- `flutter build ios --simulator --debug --no-codesign -t lib/main.dart`
  succeeds
- the app launches on the simulator
- scene-based background channel registration is confirmed directly or with a
  clearly stated indirect limitation
- ordinary app switching does not sever a live lane by itself
- blocked turns remain protected across app switching
- non-selected live lanes are still treated as active-turn owners

## Failures To Record Precisely

If anything fails, record the exact failure type:

- Swift compile failure
- scene registration failure
- method channel call not reaching iOS
- background/return forces reconnect while transport is still healthy
- blocked turn loses continuity
- non-selected live lane drops on ordinary app switching
- simulator-only flake versus reproducible failure

Include:

- macOS version
- Xcode version
- iOS simulator model and runtime version
- exact reproduction steps
- whether Xcode breakpoints/logpoints were used
- whether the failure happened with an active turn, blocked turn, or no active
  turn

## Important Product Constraint

Do not treat simulator success as proof that iPhone live-turn continuity is
solved.

This validation only covers:

- iOS simulator build success
- scene-based method-channel wiring
- app-switch lifecycle behavior
- finite background-grace integration

It does not prove:

- true iPhone suspension timing
- true background task duration limits on a real device
- survival after real iOS process kill
- indefinite arbitrary SSH continuity on iPhone

Those remain separate real-device and architectural questions.
