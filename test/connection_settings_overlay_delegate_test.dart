import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';

void main() {
  testWidgets(
    'desktop settings overlay opens a dialog-style surface instead of a bottom sheet',
    (tester) async {
      final delegate = const ModalConnectionSettingsOverlayDelegate();
      ConnectionSettingsSubmitPayload? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildPocketTheme(Brightness.light),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      result = await delegate.openConnectionSettings(
                        context: context,
                        initialProfile: ConnectionProfile.defaults(),
                        initialSecrets: const ConnectionSecrets(),
                        platformBehavior: const PocketPlatformBehavior(
                          experience: PocketPlatformExperience.desktop,
                          supportsLocalConnectionMode: true,
                          supportsWakeLock: false,
                          supportsFiniteBackgroundGrace: false,
                          supportsActiveTurnForegroundService: false,
                          usesDesktopKeyboardSubmit: true,
                          supportsCollapsibleDesktopSidebar: false,
                        ),
                      );
                    },
                    child: const Text('Open settings'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('desktop_connection_settings_surface'),
        ),
        findsOneWidget,
      );
      expect(find.byType(BottomSheet), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_cancel_top')),
      );
      await tester.pumpAndSettle();

      expect(result, isNull);
    },
  );

  testWidgets('desktop settings overlay shifts above bottom view insets', (
    tester,
  ) async {
    final delegate = const ModalConnectionSettingsOverlayDelegate();
    const screenSize = Size(1440, 1000);
    const keyboardInset = 220.0;
    tester.view.physicalSize = screenSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: screenSize,
          viewInsets: EdgeInsets.only(bottom: keyboardInset),
        ),
        child: MaterialApp(
          theme: buildPocketTheme(Brightness.light),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      delegate.openConnectionSettings(
                        context: context,
                        initialProfile: ConnectionProfile.defaults(),
                        initialSecrets: const ConnectionSecrets(),
                        platformBehavior: const PocketPlatformBehavior(
                          experience: PocketPlatformExperience.desktop,
                          supportsLocalConnectionMode: true,
                          supportsWakeLock: false,
                          supportsFiniteBackgroundGrace: false,
                          supportsActiveTurnForegroundService: false,
                          usesDesktopKeyboardSubmit: true,
                          supportsCollapsibleDesktopSidebar: false,
                        ),
                      );
                    },
                    child: const Text('Open settings'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    final surfaceFinder = find.byKey(
      const ValueKey<String>('desktop_connection_settings_surface'),
    );
    final surfaceBottom = tester.getBottomRight(surfaceFinder).dy;
    expect(surfaceBottom, lessThanOrEqualTo(screenSize.height - keyboardInset));
  });
}
