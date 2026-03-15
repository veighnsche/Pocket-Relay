import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_sheet.dart';

void main() {
  testWidgets(
    'renders validation from the settings contract without a Form widget',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildPocketTheme(Brightness.light),
          home: Scaffold(
            body: ConnectionSheet(
              initialProfile: _configuredProfile(),
              initialSecrets: const ConnectionSecrets(password: 'secret'),
            ),
          ),
        ),
      );

      expect(find.byType(Form), findsNothing);
      expect(find.text('Bad port'), findsNothing);

      await tester.enterText(_textField('Port'), '70000');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Bad port'), findsOneWidget);
    },
  );

  testWidgets('switches authentication fields through the presenter contract', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: Scaffold(
          body: ConnectionSheet(
            initialProfile: _configuredProfile(),
            initialSecrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
      ),
    );

    expect(find.text('SSH password'), findsOneWidget);
    expect(find.text('Private key PEM'), findsNothing);

    await tester.ensureVisible(find.text('Private key'));
    await tester.tap(find.text('Private key'));
    await tester.pumpAndSettle();

    expect(find.text('SSH password'), findsNothing);
    expect(find.text('Private key PEM'), findsOneWidget);
    expect(find.text('Key passphrase (optional)'), findsOneWidget);
  });
}

Finder _textField(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
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
