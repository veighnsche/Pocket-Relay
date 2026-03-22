import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/device/foreground_service_host.dart';

void main() {
  testWidgets('tracks keep-alive state and releases the foreground service', (
    tester,
  ) async {
    final controller = _FakeForegroundServiceController();

    await tester.pumpWidget(
      MaterialApp(
        home: ForegroundServiceHost(
          foregroundServiceController: controller,
          supportsForegroundService: true,
          child: const SizedBox(),
        ),
      ),
    );

    expect(controller.enabledStates, <bool>[true]);

    await tester.pumpWidget(
      MaterialApp(
        home: ForegroundServiceHost(
          foregroundServiceController: controller,
          supportsForegroundService: true,
          keepForegroundServiceRunning: false,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();

    expect(controller.enabledStates, <bool>[true, false]);
  });

  testWidgets('stays inert when foreground service support is unavailable', (
    tester,
  ) async {
    final controller = _FakeForegroundServiceController();

    await tester.pumpWidget(
      MaterialApp(
        home: ForegroundServiceHost(
          foregroundServiceController: controller,
          supportsForegroundService: false,
          child: const SizedBox(),
        ),
      ),
    );

    expect(controller.enabledStates, isEmpty);
  });
}

class _FakeForegroundServiceController implements ForegroundServiceController {
  final List<bool> enabledStates = <bool>[];

  @override
  Future<void> setEnabled(bool enabled) async {
    enabledStates.add(enabled);
  }
}
