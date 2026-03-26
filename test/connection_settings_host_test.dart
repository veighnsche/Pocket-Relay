import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/widgets/modal_sheet_scaffold.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';
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
    'desktop settings use centered desktop chrome without the sheet drag handle',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _buildMaterialSettingsApp(
          onSubmit: (_) {},
          platformBehavior: _desktopBehavior,
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

  testWidgets(
    'shared host submits the expected payload semantics through the material renderer',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      ConnectionSettingsSubmitPayload? materialPayload;

      await tester.pumpWidget(
        _buildMaterialSettingsApp(
          availableModelCatalog: codexReferenceModelCatalog(
            connectionId: 'host-submit-test',
          ),
          onSubmit: (payload) {
            materialPayload = payload;
          },
        ),
      );

      await tester.enterText(_materialTextField('Profile label'), '  ');
      await tester.enterText(_materialTextField('Host'), '  ios.example.com  ');
      await tester.enterText(_materialTextField('Port'), '2222');
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('connection_settings_model')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_model')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('gpt-5.4').last);
      await tester.pumpAndSettle();
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
      expect(materialPayload!.profile.model, 'gpt-5.4');
      expect(
        materialPayload!.profile.reasoningEffort,
        CodexReasoningEffort.high,
      );
    },
  );

  testWidgets(
    'reasoning effort dropdown follows the selected model picker entry',
    (tester) async {
      await tester.pumpWidget(
        _buildMaterialSettingsApp(
          onSubmit: (_) {},
          availableModelCatalog: codexReferenceModelCatalog(
            connectionId: 'host-reasoning-test',
          ),
        ),
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('connection_settings_model')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_model')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('gpt-5.1-codex-mini').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey<String>('connection_settings_reasoning_effort'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Medium').last, findsOneWidget);
      expect(find.text('High').last, findsOneWidget);
      expect(find.text('Low'), findsNothing);
      expect(find.text('XHigh'), findsNothing);
    },
  );

  testWidgets(
    'shared host uses the provided backend model catalog for model and effort options',
    (tester) async {
      ConnectionSettingsSubmitPayload? payload;

      await tester.pumpWidget(
        _buildMaterialSettingsApp(
          onSubmit: (nextPayload) {
            payload = nextPayload;
          },
          availableModelCatalog: _backendAvailableModelCatalog(),
        ),
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('connection_settings_model')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_model')),
      );
      await tester.pumpAndSettle();

      expect(find.text('GPT Live Default').last, findsOneWidget);
      expect(find.text('gpt-5.4'), findsNothing);

      await tester.tap(find.text('GPT Live Default').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey<String>('connection_settings_reasoning_effort'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Minimal').last, findsOneWidget);
      expect(find.text('XHigh').last, findsOneWidget);
      expect(find.text('Medium'), findsNothing);

      await tester.tap(find.text('Minimal').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
      );
      await tester.pumpAndSettle();

      expect(payload, isNotNull);
      expect(payload!.profile.model, 'gpt-live-default');
      expect(payload!.profile.reasoningEffort, CodexReasoningEffort.minimal);
    },
  );

  testWidgets(
    'shared host disables model and reasoning pickers when backend-only mode has no catalog',
    (tester) async {
      await tester.pumpWidget(
        _buildMaterialSettingsApp(
          onSubmit: (_) {},
          initialProfile: _configuredProfile().copyWith(
            model: 'saved-model-only',
            reasoningEffort: CodexReasoningEffort.xhigh,
          ),
        ),
      );

      expect(
        find.text(
          'Use Refresh models after the first successful backend connection to update available models. Showing the saved model value only.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Use Refresh models after the first successful backend connection to update supported reasoning efforts. Showing the saved effort only.',
        ),
        findsOneWidget,
      );

      final modelField = tester.widget<DropdownButtonFormField<String?>>(
        find.byKey(const ValueKey<String>('connection_settings_model')),
      );
      final reasoningField = tester
          .widget<DropdownButtonFormField<CodexReasoningEffort?>>(
            find.byKey(
              const ValueKey<String>('connection_settings_reasoning_effort'),
            ),
          );

      expect(modelField.onChanged, isNull);
      expect(modelField.initialValue, 'saved-model-only');
      expect(reasoningField.onChanged, isNull);
      expect(reasoningField.initialValue, CodexReasoningEffort.xhigh);

      final refreshButton = tester.widget<OutlinedButton>(
        find.byKey(
          const ValueKey<String>('connection_settings_refresh_models'),
        ),
      );
      expect(refreshButton.onPressed, isNull);
    },
  );

  testWidgets(
    'shared host preserves a saved reasoning effort when the backend catalog is empty',
    (tester) async {
      await tester.pumpWidget(
        _buildMaterialSettingsApp(
          onSubmit: (_) {},
          initialProfile: _configuredProfile().copyWith(
            model: 'saved-model-only',
            reasoningEffort: CodexReasoningEffort.xhigh,
          ),
          availableModelCatalog: ConnectionModelCatalog(
            connectionId: 'empty-catalog',
            fetchedAt: DateTime.utc(2026, 3, 22),
            models: <ConnectionAvailableModel>[],
          ),
        ),
      );

      final reasoningField = tester
          .widget<DropdownButtonFormField<CodexReasoningEffort?>>(
            find.byKey(
              const ValueKey<String>('connection_settings_reasoning_effort'),
            ),
          );
      expect(reasoningField.initialValue, CodexReasoningEffort.xhigh);
      expect(
        find.text(
          'Saved reasoning effort outside the available backend options.',
        ),
        findsOneWidget,
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

      expect(find.text('XHigh').last, findsOneWidget);
    },
  );

  testWidgets(
    'shared host enables refresh only when a workspace directory is set',
    (tester) async {
      await tester.pumpWidget(
        _buildMaterialSettingsApp(
          onSubmit: (_) {},
          onRefreshModelCatalog: (draft) async =>
              _backendAvailableModelCatalog(),
          initialProfile: _configuredProfile().copyWith(workspaceDir: ''),
        ),
      );

      final refreshButtonBefore = tester.widget<OutlinedButton>(
        find.byKey(
          const ValueKey<String>('connection_settings_refresh_models'),
        ),
      );
      expect(refreshButtonBefore.onPressed, isNull);

      await tester.enterText(
        _materialTextField('Workspace directory'),
        '/repo',
      );
      await tester.pump();

      final refreshButtonAfter = tester.widget<OutlinedButton>(
        find.byKey(
          const ValueKey<String>('connection_settings_refresh_models'),
        ),
      );
      expect(refreshButtonAfter.onPressed, isNotNull);
    },
  );

  testWidgets(
    'shared host calls out cached model catalogs explicitly in the refresh helper text',
    (tester) async {
      await tester.pumpWidget(
        _buildMaterialSettingsApp(
          onSubmit: (_) {},
          availableModelCatalog: _backendAvailableModelCatalog(),
          availableModelCatalogSource:
              ConnectionSettingsModelCatalogSource.lastKnownCache,
        ),
      );

      expect(
        find.text(
          'Showing last-known models from a previous backend refresh. They may not match this connection until it refreshes. Last refreshed 2026-03-22 00:00 UTC. Model refresh is available when this settings sheet is opened from a live backend connection.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shared host keeps the previous catalog and shows refresh failure feedback when refresh throws',
    (tester) async {
      await tester.pumpWidget(
        _buildMaterialSettingsApp(
          onSubmit: (_) {},
          availableModelCatalog: _backendAvailableModelCatalog(),
          availableModelCatalogSource:
              ConnectionSettingsModelCatalogSource.lastKnownCache,
          onRefreshModelCatalog: (draft) async {
            throw StateError('refresh failed');
          },
        ),
      );

      await tester.ensureVisible(
        find.byKey(
          const ValueKey<String>('connection_settings_refresh_models'),
        ),
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('connection_settings_refresh_models'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Refresh failed. Showing the previous model list. Showing last-known models from a previous backend refresh. They may not match this connection until it refreshes. Last refreshed 2026-03-22 00:00 UTC. Use Refresh models to try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('GPT Live Default'), findsNothing);
    },
  );

  testWidgets(
    'shared host refresh action loads backend catalog explicitly and updates the pickers',
    (tester) async {
      var refreshCalls = 0;

      await tester.pumpWidget(
        _buildMaterialSettingsApp(
          onSubmit: (_) {},
          onRefreshModelCatalog: (draft) async {
            refreshCalls += 1;
            return _backendAvailableModelCatalog();
          },
        ),
      );

      expect(find.text('GPT Live Default'), findsNothing);

      await tester.ensureVisible(
        find.byKey(
          const ValueKey<String>('connection_settings_refresh_models'),
        ),
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('connection_settings_refresh_models'),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(refreshCalls, 1);

      final modelField = tester.widget<DropdownButtonFormField<String?>>(
        find.byKey(const ValueKey<String>('connection_settings_model')),
      );
      expect(modelField.onChanged, isNotNull);

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('connection_settings_model')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_model')),
      );
      await tester.pumpAndSettle();

      expect(find.text('GPT Live Default').last, findsOneWidget);
    },
  );
}

Widget _buildMaterialSettingsApp({
  Brightness brightness = Brightness.light,
  required ValueChanged<ConnectionSettingsSubmitPayload> onSubmit,
  PocketPlatformBehavior platformBehavior = _mobileBehavior,
  ConnectionModelCatalog? availableModelCatalog,
  ConnectionSettingsModelCatalogSource? availableModelCatalogSource,
  ConnectionProfile? initialProfile,
  Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
  onRefreshModelCatalog,
}) {
  return MaterialApp(
    theme: buildPocketTheme(brightness),
    darkTheme: buildPocketTheme(Brightness.dark),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(
      body: _buildHost(
        onSubmit: onSubmit,
        platformBehavior: platformBehavior,
        availableModelCatalog: availableModelCatalog,
        availableModelCatalogSource: availableModelCatalogSource,
        initialProfile: initialProfile,
        onRefreshModelCatalog: onRefreshModelCatalog,
        builder: (context, viewModel, actions) {
          return ConnectionSheet(
            platformBehavior: platformBehavior,
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
  PocketPlatformBehavior platformBehavior = _mobileBehavior,
  ConnectionModelCatalog? availableModelCatalog,
  ConnectionSettingsModelCatalogSource? availableModelCatalogSource,
  ConnectionProfile? initialProfile,
  Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
  onRefreshModelCatalog,
}) {
  return ConnectionSettingsHost(
    initialProfile: initialProfile ?? _configuredProfile(),
    initialSecrets: const ConnectionSecrets(password: 'secret'),
    availableModelCatalog: availableModelCatalog,
    availableModelCatalogSource: availableModelCatalogSource,
    onRefreshModelCatalog: onRefreshModelCatalog,
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

ConnectionModelCatalog _backendAvailableModelCatalog() {
  return ConnectionModelCatalog(
    connectionId: 'conn_primary',
    fetchedAt: DateTime.utc(2026, 3, 22),
    models: const <ConnectionAvailableModel>[
      ConnectionAvailableModel(
        id: 'preset_gpt_live_default',
        model: 'gpt-live-default',
        displayName: 'GPT Live Default',
        description: 'Live backend default.',
        hidden: false,
        supportedReasoningEfforts:
            <ConnectionAvailableModelReasoningEffortOption>[
              ConnectionAvailableModelReasoningEffortOption(
                reasoningEffort: CodexReasoningEffort.minimal,
                description: 'Fastest backend lane mode.',
              ),
              ConnectionAvailableModelReasoningEffortOption(
                reasoningEffort: CodexReasoningEffort.xhigh,
                description: 'Deepest backend lane mode.',
              ),
            ],
        defaultReasoningEffort: CodexReasoningEffort.xhigh,
        inputModalities: <String>['text'],
        supportsPersonality: false,
        isDefault: true,
      ),
    ],
  );
}

const _mobileBehavior = PocketPlatformBehavior(
  experience: PocketPlatformExperience.mobile,
  supportsLocalConnectionMode: false,
  supportsWakeLock: true,
  supportsFiniteBackgroundGrace: false,
  supportsActiveTurnForegroundService: false,
  usesDesktopKeyboardSubmit: false,
  supportsCollapsibleDesktopSidebar: false,
);

const _desktopBehavior = PocketPlatformBehavior(
  experience: PocketPlatformExperience.desktop,
  supportsLocalConnectionMode: true,
  supportsWakeLock: false,
  supportsFiniteBackgroundGrace: false,
  supportsActiveTurnForegroundService: false,
  usesDesktopKeyboardSubmit: true,
  supportsCollapsibleDesktopSidebar: false,
);
