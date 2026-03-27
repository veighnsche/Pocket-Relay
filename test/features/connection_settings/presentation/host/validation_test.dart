import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
import 'package:pocket_relay/src/core/widgets/modal_sheet_scaffold.dart';

import 'host_test_support.dart';

void main() {
  testWidgets(
    'material settings renderer shows validation from the shared host without a Form widget',
    (tester) async {
      await tester.pumpWidget(buildMaterialSettingsApp(onSubmit: (_) {}));

      expect(find.byType(Form), findsNothing);
      expect(find.text('Bad port'), findsNothing);

      await tester.enterText(materialTextField('Port'), '70000');
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bad port'), findsOneWidget);
    },
  );

  testWidgets(
    'material settings renderer keeps the action bar pinned while the form scrolls',
    (tester) async {
      tester.view.physicalSize = const Size(430, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildMaterialSettingsApp(onSubmit: (_) {}));

      expect(
        find.byKey(const ValueKey<String>('connection_settings_cancel_top')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
        findsOneWidget,
      );
      expect(find.text('Danger zone'), findsNothing);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('connection_settings_cancel_top')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'material settings renderer avoids nested panel surfaces inside the drawer',
    (tester) async {
      await tester.pumpWidget(buildMaterialSettingsApp(onSubmit: (_) {}));

      expect(find.byType(PocketPanelSurface), findsNothing);
    },
  );

  testWidgets(
    'material settings renderer switches authentication fields through the shared host',
    (tester) async {
      await tester.pumpWidget(buildMaterialSettingsApp(onSubmit: (_) {}));

      expect(find.text('SSH password'), findsOneWidget);
      expect(find.text('Private key PEM'), findsNothing);

      await tester.ensureVisible(find.text('Private key'));
      await tester.tap(find.text('Private key'));
      await tester.pumpAndSettle();

      expect(find.text('SSH password'), findsNothing);
      expect(find.text('Private key PEM'), findsOneWidget);
      expect(find.text('Key passphrase (optional)'), findsOneWidget);
    },
  );

  testWidgets(
    'material settings renderer requires a host fingerprint for remote connections',
    (tester) async {
      await tester.pumpWidget(buildMaterialSettingsApp(onSubmit: (_) {}));

      expect(
        find.text(
          'Shared host identity: devbox.local:22. This pinned fingerprint is reused by every saved connection that points there.',
        ),
        findsOneWidget,
      );

      await tester.enterText(materialTextField('Host fingerprint'), '');
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Host fingerprint is required'), findsOneWidget);
    },
  );

  testWidgets(
    'desktop settings expose a local and remote route chooser and hide SSH fields for local mode',
    (tester) async {
      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          platformBehavior: desktopSettingsBehavior,
        ),
      );

      final connectionModePicker = find.byType(SegmentedButton<ConnectionMode>);
      expect(
        find.descendant(of: connectionModePicker, matching: find.text('Remote')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: connectionModePicker, matching: find.text('Local')),
        findsOneWidget,
      );
      expect(find.text('Host'), findsOneWidget);
      expect(find.text('SSH password'), findsOneWidget);

      await tester.ensureVisible(connectionModePicker);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: connectionModePicker,
          matching: find.byIcon(Icons.laptop_mac_outlined),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Host'), findsNothing);
      expect(find.text('SSH password'), findsNothing);
      expect(find.textContaining('Local Codex'), findsOneWidget);
    },
  );

  testWidgets(
    'desktop settings use centered desktop chrome without the sheet drag handle',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          platformBehavior: desktopSettingsBehavior,
        ),
      );

      expect(
        find.byKey(
          const ValueKey<String>('desktop_connection_settings_surface'),
        ),
        findsOneWidget,
      );
      expect(find.byType(ModalSheetDragHandle), findsNothing);
    },
  );
}
