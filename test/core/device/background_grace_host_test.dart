import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/device/background_grace_host.dart';

void main() {
  testWidgets('tracks app lifecycle and releases background grace on resume', (
    tester,
  ) async {
    final controller = _FakeBackgroundGraceController();
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: BackgroundGraceHost(
          backgroundGraceController: controller,
          supportsBackgroundGrace: true,
          child: const SizedBox(),
        ),
      ),
    );

    expect(controller.enabledStates, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(controller.enabledStates, <bool>[true]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(controller.enabledStates, <bool>[true, false]);
  });

  testWidgets('stays inert when background grace is unsupported', (
    tester,
  ) async {
    final controller = _FakeBackgroundGraceController();

    await tester.pumpWidget(
      MaterialApp(
        home: BackgroundGraceHost(
          backgroundGraceController: controller,
          supportsBackgroundGrace: false,
          child: const SizedBox(),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(controller.enabledStates, isEmpty);
  });
}

class _FakeBackgroundGraceController implements BackgroundGraceController {
  final List<bool> enabledStates = <bool>[];

  @override
  Future<void> setEnabled(bool enabled) async {
    enabledStates.add(enabled);
  }
}
