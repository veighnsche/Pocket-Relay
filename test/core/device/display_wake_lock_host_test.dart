import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';

void main() {
  testWidgets('tracks app lifecycle and releases the wake lock on dispose', (
    tester,
  ) async {
    final controller = _FakeDisplayWakeLockController();
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: DisplayWakeLockHost(
          displayWakeLockController: controller,
          supportsWakeLock: true,
          child: const SizedBox(),
        ),
      ),
    );

    expect(controller.enabledStates, <bool>[true]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(controller.enabledStates, <bool>[true, false]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(controller.enabledStates, <bool>[true, false, true]);

    await tester.pumpWidget(const SizedBox());

    expect(controller.enabledStates, <bool>[true, false, true, false]);
  });

  testWidgets('stays inert when wake lock is unsupported', (tester) async {
    final controller = _FakeDisplayWakeLockController();

    await tester.pumpWidget(
      MaterialApp(
        home: DisplayWakeLockHost(
          displayWakeLockController: controller,
          supportsWakeLock: false,
          child: const SizedBox(),
        ),
      ),
    );

    expect(controller.enabledStates, isEmpty);
  });

  testWidgets('wake-lock failures surface a typed warning', (tester) async {
    final controller = _ThrowingDisplayWakeLockController();
    PocketUserFacingError? warning;

    await tester.pumpWidget(
      MaterialApp(
        home: DisplayWakeLockHost(
          displayWakeLockController: controller,
          supportsWakeLock: true,
          onWarningChanged: (value) => warning = value,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();

    expect(controller.enabledStates, <bool>[true]);
    expect(warning?.definition, PocketErrorCatalog.deviceWakeLockEnableFailed);
    expect(warning?.bodyWithCode, contains('wake lock failed'));
  });
}

class _FakeDisplayWakeLockController implements DisplayWakeLockController {
  final List<bool> enabledStates = <bool>[];

  @override
  Future<void> setEnabled(bool enabled) async {
    enabledStates.add(enabled);
  }
}

class _ThrowingDisplayWakeLockController implements DisplayWakeLockController {
  final List<bool> enabledStates = <bool>[];

  @override
  Future<void> setEnabled(bool enabled) async {
    enabledStates.add(enabled);
    throw StateError('wake lock failed');
  }
}
