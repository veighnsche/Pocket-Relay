import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
import 'package:pocket_relay/src/core/widgets/modal_sheet_scaffold.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_system_template.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_sheet_surface.dart';

import 'host_test_support.dart';

void main() {
  testWidgets(
    'material settings renderer shows validation from the shared host without a Form widget',
    (tester) async {
      ConnectionSettingsSubmitPayload? payload;
      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (nextPayload) {
            payload = nextPayload;
          },
          surfaceMode: ConnectionSettingsSurfaceMode.system,
        ),
      );

      expect(find.byType(Form), findsNothing);
      expect(find.text('Bad port'), findsNothing);

      await tester.enterText(materialTextField('Port'), '70000');
      await tester.enterText(materialTextField('Port'), '2222');
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
      );
      await tester.pumpAndSettle();

      expect(payload, isNull);
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
    'mobile settings header avoids fixed explanatory prose and route badges',
    (tester) async {
      await tester.pumpWidget(buildMaterialSettingsApp(onSubmit: (_) {}));

      expect(
        find.text(
          'Choose the system that hosts this workspace, then point Pocket Relay at the directory and Codex command it should use there.',
        ),
        findsNothing,
      );
      expect(find.text('Remote'), findsNothing);
      expect(find.text('Local'), findsNothing);
      expect(find.text('devbox.local · /workspace'), findsOneWidget);
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
      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          surfaceMode: ConnectionSettingsSurfaceMode.system,
        ),
      );

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
          surfaceMode: ConnectionSettingsSurfaceMode.system,
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

      await tester.enterText(materialTextField('Port'), '2222');
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

  testWidgets('port formatting changes do not clear a trusted fingerprint', (
    tester,
  ) async {
    ConnectionSettingsSubmitPayload? payload;

    await tester.pumpWidget(
      buildMaterialSettingsApp(
        onSubmit: (nextPayload) {
          payload = nextPayload;
        },
        initialProfile: configuredConnectionProfile().copyWith(port: 22),
        surfaceMode: ConnectionSettingsSurfaceMode.system,
      ),
    );

    await tester.enterText(materialTextField('Port'), '022');
    await tester.tap(
      find.byKey(const ValueKey<String>('connection_settings_save_top')),
    );
    await tester.pumpAndSettle();

    expect(payload, isNotNull);
    expect(payload!.profile.port, 22);
    expect(payload!.profile.hostFingerprint, 'aa:bb:cc:dd');
  });

  testWidgets(
    'system settings can submit when hidden workspace fields start empty',
    (tester) async {
      ConnectionSettingsSubmitPayload? payload;

      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (nextPayload) {
            payload = nextPayload;
          },
          initialProfile: configuredConnectionProfile().copyWith(
            workspaceDir: '',
            codexPath: '',
          ),
          surfaceMode: ConnectionSettingsSurfaceMode.system,
        ),
      );

      await tester.enterText(materialTextField('Username'), 'vincent');
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
      );
      await tester.pumpAndSettle();

      expect(payload, isNotNull);
      expect(payload!.profile.username, 'vincent');
      expect(payload!.profile.workspaceDir, isEmpty);
      expect(payload!.profile.codexPath, isEmpty);
    },
  );

  testWidgets('workspace settings can reuse a saved system template', (
    tester,
  ) async {
    ConnectionSettingsSubmitPayload? payload;
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
        onSubmit: (nextPayload) {
          payload = nextPayload;
        },
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

    expect(
      find.byKey(settingsFieldKey(ConnectionSettingsFieldId.host)),
      findsNothing,
    );
    expect(
      find.byKey(settingsFieldKey(ConnectionSettingsFieldId.password)),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('connection_settings_save_top')),
    );
    await tester.pumpAndSettle();

    expect(payload, isNotNull);
    expect(payload!.profile.host, 'buildbox.local');
    expect(payload!.profile.port, 2200);
    expect(payload!.profile.username, 'alice');
    expect(payload!.profile.workspaceDir, '/workspace/current');
    expect(payload!.profile.codexPath, 'codex');
    expect(payload!.profile.hostFingerprint, '11:22:33:44');
    expect(payload!.secrets.password, 'other-secret');
  });

  testWidgets(
    'workspace settings can clear a selected system back to no system selected',
    (tester) async {
      ConnectionSettingsSubmitPayload? payload;
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
          onSubmit: (nextPayload) {
            payload = nextPayload;
          },
          initialProfile: ConnectionProfile.defaults().copyWith(
            workspaceDir: '/workspace/current',
            codexPath: 'codex',
          ),
          availableSystemTemplates: <ConnectionSettingsSystemTemplate>[
            template,
          ],
        ),
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('connection_settings_system_picker')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_system_picker')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining('buildbox.local:2200 as alice').last,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_system_picker')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('No system selected').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
      );
      await tester.pumpAndSettle();

      expect(payload, isNull);
    },
  );

  testWidgets(
    'material settings renderer disables smart typing for system and auth fields',
    (tester) async {
      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          surfaceMode: ConnectionSettingsSurfaceMode.system,
        ),
      );

      final hostField = tester.widget<TextField>(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.host)),
      );
      final usernameField = tester.widget<TextField>(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.username)),
      );
      final passwordField = tester.widget<TextField>(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.password)),
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
    'desktop workspace settings expose a local and remote route chooser and hide system selection for local mode',
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
      expect(
        find.byKey(const ValueKey<String>('connection_settings_system_picker')),
        findsOneWidget,
      );
      expect(find.text('Agent adapter'), findsOneWidget);

      await tester.ensureVisible(connectionModePicker);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: connectionModePicker,
          matching: find.byIcon(Icons.laptop_mac_outlined),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('connection_settings_system_picker')),
        findsNothing,
      );
      expect(find.text('Agent adapter'), findsOneWidget);
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
