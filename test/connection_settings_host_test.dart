import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_host.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_sheet.dart';

void main() {
  testWidgets(
    'material settings renderer shows validation from the shared host without a Form widget',
    (tester) async {
      await tester.pumpWidget(_buildMaterialSettingsApp(onSubmit: (_) {}));

      expect(find.byType(Form), findsNothing);
      expect(find.text('Bad port'), findsNothing);

      await tester.enterText(_materialTextField('Port'), '70000');
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bad port'), findsOneWidget);
    },
  );

  testWidgets(
    'material settings renderer keeps cancel and save pinned at the top',
    (tester) async {
      tester.view.physicalSize = const Size(430, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildMaterialSettingsApp(onSubmit: (_) {}));

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
    'material settings renderer switches authentication fields through the shared host',
    (tester) async {
      await tester.pumpWidget(_buildMaterialSettingsApp(onSubmit: (_) {}));

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
    'desktop settings expose a local and remote route chooser and hide SSH fields for local mode',
    (tester) async {
      await tester.pumpWidget(
        _buildMaterialSettingsApp(
          onSubmit: (_) {},
          platformBehavior: _desktopBehavior,
        ),
      );

      expect(find.text('Remote'), findsOneWidget);
      expect(find.text('Local'), findsOneWidget);
      expect(find.text('Host'), findsOneWidget);
      expect(find.text('SSH password'), findsOneWidget);

      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();

      expect(find.text('Host'), findsNothing);
      expect(find.text('SSH password'), findsNothing);
      expect(find.text('Local Codex'), findsOneWidget);
    },
  );

  testWidgets(
    'shared host submits the expected payload semantics through the material renderer',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      ConnectionSettingsSubmitPayload? materialPayload;

      await tester.pumpWidget(
        _buildMaterialSettingsApp(
          onSubmit: (payload) {
            materialPayload = payload;
          },
        ),
      );

      await tester.enterText(_materialTextField('Profile label'), '  ');
      await tester.enterText(_materialTextField('Host'), '  ios.example.com  ');
      await tester.enterText(_materialTextField('Port'), '2222');
      await tester.enterText(
        _materialTextField('Model override (optional)'),
        '  gpt-5.4-mini  ',
      );
      await tester.ensureVisible(
        find.byKey(
          const ValueKey<String>('connection_settings_reasoning_effort'),
        ),
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('connection_settings_reasoning_effort'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('High').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
      );
      await tester.pumpAndSettle();

      expect(materialPayload, isNotNull);
      expect(materialPayload!.profile.label, 'Developer Box');
      expect(materialPayload!.profile.host, 'ios.example.com');
      expect(materialPayload!.profile.port, 2222);
      expect(materialPayload!.profile.model, 'gpt-5.4-mini');
      expect(
        materialPayload!.profile.reasoningEffort,
        CodexReasoningEffort.high,
      );
    },
  );
}

Widget _buildMaterialSettingsApp({
  Brightness brightness = Brightness.light,
  required ValueChanged<ConnectionSettingsSubmitPayload> onSubmit,
  PocketPlatformBehavior platformBehavior = _mobileBehavior,
}) {
  return MaterialApp(
    theme: buildPocketTheme(brightness),
    darkTheme: buildPocketTheme(Brightness.dark),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(
      body: _buildHost(
        onSubmit: onSubmit,
        platformBehavior: platformBehavior,
        builder: (context, viewModel, actions) {
          return ConnectionSheet(viewModel: viewModel, actions: actions);
        },
      ),
    ),
  );
}

Widget _buildHost({
  required ValueChanged<ConnectionSettingsSubmitPayload> onSubmit,
  required ConnectionSettingsHostBuilder builder,
  PocketPlatformBehavior platformBehavior = _mobileBehavior,
}) {
  return ConnectionSettingsHost(
    initialProfile: _configuredProfile(),
    initialSecrets: const ConnectionSecrets(password: 'secret'),
    platformBehavior: platformBehavior,
    onCancel: () {},
    onSubmit: onSubmit,
    builder: builder,
  );
}

Finder _materialTextField(String label) {
  return find.byKey(_fieldKey(_fieldIdForLabel(label)));
}

ValueKey<String> _fieldKey(ConnectionSettingsFieldId fieldId) {
  return ValueKey<String>('connection_settings_${fieldId.name}');
}

ConnectionSettingsFieldId _fieldIdForLabel(String label) {
  return switch (label) {
    'Profile label' => ConnectionSettingsFieldId.label,
    'Host' => ConnectionSettingsFieldId.host,
    'Port' => ConnectionSettingsFieldId.port,
    'Username' => ConnectionSettingsFieldId.username,
    'Workspace directory' => ConnectionSettingsFieldId.workspaceDir,
    'Codex launch command' => ConnectionSettingsFieldId.codexPath,
    'Model override (optional)' => ConnectionSettingsFieldId.model,
    'Host fingerprint (optional)' => ConnectionSettingsFieldId.hostFingerprint,
    'SSH password' => ConnectionSettingsFieldId.password,
    'Private key PEM' => ConnectionSettingsFieldId.privateKeyPem,
    'Key passphrase (optional)' =>
      ConnectionSettingsFieldId.privateKeyPassphrase,
    _ => throw ArgumentError.value(label, 'label', 'Unknown settings field'),
  };
}

ConnectionProfile _configuredProfile() {
  return ConnectionProfile.defaults().copyWith(
    label: 'Dev Box',
    host: 'devbox.local',
    username: 'vince',
    workspaceDir: '/workspace',
    codexPath: 'codex',
  );
}

const _mobileBehavior = PocketPlatformBehavior(
  experience: PocketPlatformExperience.mobile,
  supportsLocalConnectionMode: false,
  supportsWakeLock: true,
  usesDesktopKeyboardSubmit: false,
  supportsCollapsibleDesktopSidebar: false,
);

const _desktopBehavior = PocketPlatformBehavior(
  experience: PocketPlatformExperience.desktop,
  supportsLocalConnectionMode: true,
  supportsWakeLock: false,
  usesDesktopKeyboardSubmit: true,
  supportsCollapsibleDesktopSidebar: false,
);
