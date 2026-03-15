import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_host.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_sheet.dart';
import 'package:pocket_relay/src/features/settings/presentation/cupertino_connection_sheet.dart';

void main() {
  testWidgets(
    'material settings renderer shows validation from the shared host without a Form widget',
    (tester) async {
      await tester.pumpWidget(_buildMaterialSettingsApp(onSubmit: (_) {}));

      expect(find.byType(Form), findsNothing);
      expect(find.text('Bad port'), findsNothing);

      await tester.enterText(_materialTextField('Port'), '70000');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Bad port'), findsOneWidget);
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
    'cupertino settings renderer shows validation from the shared host without a Form widget',
    (tester) async {
      await tester.pumpWidget(_buildCupertinoSettingsApp(onSubmit: (_) {}));

      expect(find.byType(Form), findsNothing);
      expect(find.text('Bad port'), findsNothing);

      await tester.enterText(_cupertinoTextField('Port'), '70000');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Bad port'), findsOneWidget);
    },
  );

  testWidgets(
    'shared host submits the same payload semantics through both settings renderers',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      ConnectionSettingsSubmitPayload? materialPayload;
      ConnectionSettingsSubmitPayload? cupertinoPayload;

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
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _buildCupertinoSettingsApp(
          onSubmit: (payload) {
            cupertinoPayload = payload;
          },
        ),
      );

      await tester.enterText(_cupertinoTextField('Profile label'), '  ');
      await tester.enterText(
        _cupertinoTextField('Host'),
        '  ios.example.com  ',
      );
      await tester.enterText(_cupertinoTextField('Port'), '2222');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(materialPayload, isNotNull);
      expect(cupertinoPayload, isNotNull);
      expect(materialPayload!.profile.label, 'Developer Box');
      expect(materialPayload!.profile.host, 'ios.example.com');
      expect(materialPayload!.profile.port, 2222);
      expect(cupertinoPayload!.profile.label, materialPayload!.profile.label);
      expect(cupertinoPayload!.profile.host, materialPayload!.profile.host);
      expect(cupertinoPayload!.profile.port, materialPayload!.profile.port);
      expect(
        cupertinoPayload!.secrets.password,
        materialPayload!.secrets.password,
      );
    },
  );
}

Widget _buildMaterialSettingsApp({
  required ValueChanged<ConnectionSettingsSubmitPayload> onSubmit,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: Scaffold(
      body: _buildHost(
        onSubmit: onSubmit,
        builder: (context, viewModel, actions) {
          return ConnectionSheet(viewModel: viewModel, actions: actions);
        },
      ),
    ),
  );
}

Widget _buildCupertinoSettingsApp({
  required ValueChanged<ConnectionSettingsSubmitPayload> onSubmit,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: Scaffold(
      body: _buildHost(
        onSubmit: onSubmit,
        builder: (context, viewModel, actions) {
          return CupertinoConnectionSheet(
            viewModel: viewModel,
            actions: actions,
          );
        },
      ),
    ),
  );
}

Widget _buildHost({
  required ValueChanged<ConnectionSettingsSubmitPayload> onSubmit,
  required ConnectionSettingsHostBuilder builder,
}) {
  return ConnectionSettingsHost(
    initialProfile: _configuredProfile(),
    initialSecrets: const ConnectionSecrets(password: 'secret'),
    onCancel: () {},
    onSubmit: onSubmit,
    builder: builder,
  );
}

Finder _materialTextField(String label) {
  return find.byKey(_fieldKey(_fieldIdForLabel(label)));
}

Finder _cupertinoTextField(String label) {
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
