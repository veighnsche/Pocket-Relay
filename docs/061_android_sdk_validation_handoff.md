# Android SDK Validation Handoff

## Purpose

This handoff is for an agent running on a computer that has:

- Android SDK installed
- `flutter` working for Android
- `adb` available
- at least one Android device or emulator available

The goal is to validate the new Android active-turn foreground-service path that
was added to improve live-lane survival while Pocket Relay is backgrounded.

This is the Android-specific follow-up to the background-execution work in:

- [`059_background_execution_publishability_findings.md`](./059_background_execution_publishability_findings.md)
- [`060_background_execution_publishability_phased_plan.md`](./060_background_execution_publishability_phased_plan.md)

## Current Implementation To Validate

Relevant files:

- [`android/app/src/main/AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml)
- [`android/app/src/main/kotlin/me/vinch/pocketrelay/MainActivity.kt`](../android/app/src/main/kotlin/me/vinch/pocketrelay/MainActivity.kt)
- [`android/app/src/main/kotlin/me/vinch/pocketrelay/ActiveTurnForegroundService.kt`](../android/app/src/main/kotlin/me/vinch/pocketrelay/ActiveTurnForegroundService.kt)
- [`android/app/src/main/res/values/strings.xml`](../android/app/src/main/res/values/strings.xml)
- [`lib/src/core/device/foreground_service_host.dart`](../lib/src/core/device/foreground_service_host.dart)
- [`lib/src/features/workspace/presentation/widgets/workspace_turn_activity_builder.dart`](../lib/src/features/workspace/presentation/widgets/workspace_turn_activity_builder.dart)
- [`lib/src/features/workspace/presentation/widgets/workspace_turn_foreground_service_host.dart`](../lib/src/features/workspace/presentation/widgets/workspace_turn_foreground_service_host.dart)
- [`lib/src/app/pocket_relay_bootstrap.dart`](../lib/src/app/pocket_relay_bootstrap.dart)

Key facts:

- Android now declares `FOREGROUND_SERVICE` and
  `FOREGROUND_SERVICE_DATA_SYNC`.
- Android also declares `POST_NOTIFICATIONS` and requests it at runtime on
  Android 13+ before enabling the foreground service.
- The app declares a native service:
  `me.vinch.pocketrelay.ActiveTurnForegroundService`.
- Flutter calls the method channel
  `me.vinch.pocketrelay/background_execution`.
- Android handles `setActiveTurnForegroundServiceEnabled`,
  `notificationsPermissionGranted`, and `requestNotificationPermission`.
- The service is only supposed to run while at least one live lane has a
  ticking turn.
- The service posts an ongoing low-importance notification.
- Android now exposes a real `app` flavor for the production app entrypoint
  `lib/main.dart`.
- Widgetbook remains a separate Android flavor at `lib/widgetbook/main.dart`.

Current commits that introduced this path:

- `4900d40` `WIP: add iOS background grace for live turns`
- `1cfe508` `WIP: add Android active-turn foreground service`

## What Must Be Proved

The Android machine should validate all of the following:

- the app builds for Android
- the Android manifest and Kotlin service compile cleanly
- a live active turn starts the foreground service
- the ongoing notification appears while the turn is active
- the notification disappears when the turn ends
- ordinary app switching during an active turn does not sever the live lane
- backgrounding without an active turn does not leave the service running
- turning the app foreground/background repeatedly does not create duplicate or
  stuck notifications

## Local Verification Commands

From the repo root:

```bash
flutter doctor -v
flutter devices
flutter test test/foreground_service_host_test.dart
flutter test test/workspace_turn_foreground_service_host_test.dart
flutter test test/workspace_turn_wake_lock_host_test.dart
flutter test test/workspace_turn_background_grace_host_test.dart
flutter test test/workspace_app_lifecycle_host_test.dart
flutter test test/pocket_platform_behavior_test.dart
flutter test test/pocket_platform_policy_test.dart
flutter build apk --debug --flavor app -t lib/main.dart
```

If the machine uses an attached device or emulator:

```bash
flutter run -d <device-id> --flavor app -t lib/main.dart
```

## Manual Android Test Matrix

Use a real remote connection that can run a visibly long Codex turn.

### Scenario 1: No Active Turn

Steps:

1. Launch Pocket Relay on Android.
2. Do not start a turn.
3. Background the app.

Expected:

- no foreground-service notification appears
- no Android service remains running for Pocket Relay

### Scenario 2: Active Turn Starts Service

Steps:

1. Launch Pocket Relay.
2. Open a live lane.
3. Start a prompt that runs long enough to observe.

Expected:

- Android 13+ may first show a notification permission prompt
- if permission is requested and allowed, the ongoing notification appears after
  permission grant
- an ongoing notification appears quickly
- notification text matches the strings in
  [`android/app/src/main/res/values/strings.xml`](../android/app/src/main/res/values/strings.xml)
- only one foreground-service notification exists

### Scenario 3: Background During Active Turn

Steps:

1. Start a long-running turn.
2. Press Home or switch to another app while the turn is still running.
3. Wait briefly.
4. Return to Pocket Relay before the turn completes.

Expected:

- the notification remains visible while backgrounded
- the active lane is still the same lane when returning
- the turn is still present and has not been force-reset by Pocket Relay
- the app does not silently drop into reconnect-required unless transport loss
  is real

### Scenario 4: Turn Completion Stops Service

Steps:

1. Keep the app foregrounded or backgrounded until the active turn completes.
2. Observe notification state after completion.

Expected:

- the notification disappears promptly after the turn is no longer active
- the service is no longer running

### Scenario 5: Repeated Turns

Steps:

1. Start a turn and let the service appear.
2. Wait for completion and confirm the service stops.
3. Start a second turn.

Expected:

- the notification comes back for the new turn
- no duplicate notifications accumulate
- no stuck notification remains after the second turn ends

### Scenario 6: Non-Selected Live Lane

This matters because the shared turn-activity builder watches all live lanes,
not only the selected lane.

Steps:

1. Create two live lanes.
2. Leave lane A selected.
3. Start a long-running turn on lane B.

Expected:

- the foreground service still starts
- Android protection is tied to any live ticking turn, not only the selected
  lane

### Scenario 7: Background With No Remaining Ticking Turn

Steps:

1. Start a turn.
2. Wait until the turn completes.
3. Background the app after completion.

Expected:

- no foreground-service notification remains
- Pocket Relay does not keep Android protection alive after the active-turn
  condition is gone

## Useful ADB Checks

List notifications:

```bash
adb shell cmd notification post-history
adb shell dumpsys notification | rg pocketrelay -n
adb shell cmd appops get me.vinch.pocketrelay POST_NOTIFICATION
```

Inspect services:

```bash
adb shell dumpsys activity services me.vinch.pocketrelay
```

Inspect app process state:

```bash
adb shell dumpsys activity processes | rg pocketrelay -n
```

Filter log output:

```bash
adb logcat | rg "Pocket Relay|pocketrelay|ActiveTurnForegroundService|ForegroundService"
```

If `rg` is unavailable on the machine, use `grep`.

## Pass Criteria

Android validation passes only if all of the following are true:

- `flutter build apk --debug --flavor app -t lib/main.dart` succeeds
- app launches on device or emulator
- the service starts only when a live turn is truly active
- the service stops when no live ticking turn remains
- app switching during a live turn does not self-kill the active lane
- no duplicate or orphaned notification remains after turn completion

Widgetbook may still be validated separately with:

```bash
flutter build apk --debug --flavor widgetbook -t lib/widgetbook/main.dart
```

## Failures To Record Precisely

If anything fails, record the exact failure type:

- build failure
- manifest/service registration failure
- method channel call not reaching Android
- service starts too early
- service does not start during active turn
- service does not stop after turn completion
- duplicate notification
- lane disconnects on ordinary app switch despite active turn
- reconnect-required shown without confirmed transport loss

Include:

- Android version
- device or emulator model
- exact reproduction steps
- logcat excerpt
- whether the failure happened foregrounded or backgrounded

## Important Product Constraint

Do not treat Android foreground service success as proof that iPhone is solved.
This Android validation is only for the Android Phase 3 resilience path.

The stricter product bar of preserving a live turn "under any circumstances"
still is not satisfied on iPhone with client-only lifecycle work. That remains a
separate architectural issue outside Android SDK validation.
