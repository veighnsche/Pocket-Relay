import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';

import 'host_test_support.dart';

void main() {
  testWidgets(
    'reasoning effort dropdown follows the selected model picker entry',
    (tester) async {
      await tester.pumpWidget(
        buildMaterialSettingsApp(
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
        buildMaterialSettingsApp(
          onSubmit: (nextPayload) {
            payload = nextPayload;
          },
          availableModelCatalog: backendAvailableModelCatalog(),
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
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          initialProfile: configuredConnectionProfile().copyWith(
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
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          initialProfile: configuredConnectionProfile().copyWith(
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
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          onRefreshModelCatalog: (draft) async =>
              backendAvailableModelCatalog(),
          initialProfile: configuredConnectionProfile().copyWith(
            workspaceDir: '',
          ),
        ),
      );

      final refreshButtonBefore = tester.widget<OutlinedButton>(
        find.byKey(
          const ValueKey<String>('connection_settings_refresh_models'),
        ),
      );
      expect(refreshButtonBefore.onPressed, isNull);

      await tester.enterText(materialTextField('Workspace directory'), '/repo');
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
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          availableModelCatalog: backendAvailableModelCatalog(),
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
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          availableModelCatalog: backendAvailableModelCatalog(),
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
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          onRefreshModelCatalog: (draft) async {
            refreshCalls += 1;
            return backendAvailableModelCatalog();
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
