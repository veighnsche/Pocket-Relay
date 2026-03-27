import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
import 'package:pocket_relay/src/core/widgets/modal_sheet_scaffold.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_system_template.dart';

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

      expect(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.password)),
        findsOneWidget,
      );
      expect(find.text('Private key'), findsOneWidget);
      expect(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.privateKeyPem)),
        findsNothing,
      );

      await tester.ensureVisible(find.text('Private key'));
      await tester.tap(find.text('Private key'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.password)),
        findsNothing,
      );
      expect(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.privateKeyPem)),
        findsOneWidget,
      );
      expect(find.text('Key passphrase (optional)'), findsOneWidget);
    },
  );

  testWidgets(
    'material settings renderer uses a system trust action instead of an editable fingerprint field',
    (tester) async {
      ConnectionSettingsSubmitPayload? payload;

      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (nextPayload) {
            payload = nextPayload;
          },
          initialProfile: configuredConnectionProfile().copyWith(
            hostFingerprint: '',
          ),
        ),
      );

      expect(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.hostFingerprint)),
        findsNothing,
      );
      expect(find.text('SSH fingerprint needed'), findsOneWidget);
      expect(
        find.text(
          'Test this system to fetch its SSH fingerprint before saving the workspace.',
        ),
        findsOneWidget,
      );

      await tester.enterText(
        materialTextField('Workspace name'),
        'Fresh Workspace',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
      );
      await tester.pumpAndSettle();
      expect(payload, isNull);

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('connection_settings_test_system')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_test_system')),
      );
      await tester.pumpAndSettle();

      expect(find.text('aa:bb:cc:dd'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('connection_settings_system_fingerprint'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
      );
      await tester.pumpAndSettle();

      expect(payload, isNotNull);
      expect(payload!.profile.hostFingerprint, 'aa:bb:cc:dd');
    },
  );

  testWidgets('material settings renderer can reuse a saved system template', (
    tester,
  ) async {
    final template = ConnectionSettingsSystemTemplate(
      id: 'system_primary',
      profile: ConnectionProfile.defaults().copyWith(
        label: 'Primary Workspace',
        host: 'buildbox.local',
        port: 2200,
        username: 'alice',
        workspaceDir: '/workspace/primary',
        codexPath: 'codex',
        authMode: AuthMode.password,
        hostFingerprint: '11:22:33:44',
      ),
      secrets: const ConnectionSecrets(password: 'other-secret'),
    );

    await tester.pumpWidget(
      buildMaterialSettingsApp(
        onSubmit: (_) {},
        initialProfile: ConnectionProfile.defaults().copyWith(
          workspaceDir: '/workspace/current',
          codexPath: 'codex',
        ),
        availableSystemTemplates: <ConnectionSettingsSystemTemplate>[template],
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('connection_settings_system_picker')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('connection_settings_system_picker')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('buildbox.local:2200 as alice').last);
    await tester.pumpAndSettle();

    final hostField = tester.widget<TextField>(
      find.byKey(settingsFieldKey(ConnectionSettingsFieldId.host)),
    );
    final portField = tester.widget<TextField>(
      find.byKey(settingsFieldKey(ConnectionSettingsFieldId.port)),
    );
    final usernameField = tester.widget<TextField>(
      find.byKey(settingsFieldKey(ConnectionSettingsFieldId.username)),
    );
    final passwordField = tester.widget<TextField>(
      find.byKey(settingsFieldKey(ConnectionSettingsFieldId.password)),
    );

    expect(hostField.controller!.text, 'buildbox.local');
    expect(portField.controller!.text, '2200');
    expect(usernameField.controller!.text, 'alice');
    expect(passwordField.controller!.text, 'other-secret');
    expect(find.text('SSH fingerprint saved'), findsOneWidget);
    expect(find.text('11:22:33:44'), findsOneWidget);
  });

  testWidgets(
    'material settings renderer disables smart typing for system and auth fields',
    (tester) async {
      await tester.pumpWidget(buildMaterialSettingsApp(onSubmit: (_) {}));

      final hostField = tester.widget<TextField>(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.host)),
      );
      final usernameField = tester.widget<TextField>(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.username)),
      );
      final passwordField = tester.widget<TextField>(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.password)),
      );
      final labelField = tester.widget<TextField>(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.label)),
      );

      expect(hostField.textCapitalization, TextCapitalization.none);
      expect(hostField.autocorrect, isFalse);
      expect(hostField.enableSuggestions, isFalse);
      expect(hostField.smartDashesType, SmartDashesType.disabled);
      expect(hostField.smartQuotesType, SmartQuotesType.disabled);

      expect(usernameField.textCapitalization, TextCapitalization.none);
      expect(usernameField.autocorrect, isFalse);
      expect(usernameField.enableSuggestions, isFalse);

      expect(passwordField.textCapitalization, TextCapitalization.none);
      expect(passwordField.autocorrect, isFalse);
      expect(passwordField.enableSuggestions, isFalse);

      expect(labelField.textCapitalization, TextCapitalization.words);
      expect(labelField.autocorrect, isTrue);
      expect(labelField.enableSuggestions, isTrue);

      await tester.ensureVisible(find.text('Private key'));
      await tester.tap(find.text('Private key'));
      await tester.pumpAndSettle();

      final privateKeyField = tester.widget<TextField>(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.privateKeyPem)),
      );
      expect(privateKeyField.textCapitalization, TextCapitalization.none);
      expect(privateKeyField.autocorrect, isFalse);
      expect(privateKeyField.enableSuggestions, isFalse);
      expect(privateKeyField.smartDashesType, SmartDashesType.disabled);
      expect(privateKeyField.smartQuotesType, SmartQuotesType.disabled);
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
        find.descendant(
          of: connectionModePicker,
          matching: find.text('Remote'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: connectionModePicker, matching: find.text('Local')),
        findsOneWidget,
      );
      expect(find.text('Host'), findsOneWidget);
      expect(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.password)),
        findsOneWidget,
      );

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
      expect(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.password)),
        findsNothing,
      );
      expect(find.text('Workspace directory'), findsOneWidget);
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
