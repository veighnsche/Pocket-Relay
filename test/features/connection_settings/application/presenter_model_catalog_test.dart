import 'package:pocket_relay/src/agent_adapters/agent_adapter_capabilities.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_errors.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_presenter.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';

import 'presenter_test_support.dart';

void main() {
  const presenter = ConnectionSettingsPresenter();

  test('filters reasoning effort options to the selected reference model', () {
    final initialProfile = configuredConnectionProfile();
    const initialSecrets = ConnectionSecrets(password: 'secret');
    final formState =
        ConnectionSettingsFormState.initial(
          profile: initialProfile,
          secrets: initialSecrets,
        ).copyWith(
          draft: ConnectionSettingsDraft.fromConnection(
            profile: initialProfile,
            secrets: initialSecrets,
          ).copyWith(model: 'gpt-5.1-codex-mini'),
        );

    final contract = presenter.present(
      initialProfile: initialProfile,
      initialSecrets: initialSecrets,
      formState: formState,
      availableModelCatalog: referenceModelCatalogForAgentAdapter(
        AgentAdapterKind.codex,
        connectionId: 'presenter-reasoning-test',
      ),
    );

    expect(contract.modelSection.selectedModelId, 'gpt-5.1-codex-mini');
    expect(
      contract.modelSection.reasoningEffortOptions
          .map((option) => option.label)
          .toList(growable: false),
      <String>['Default', 'Medium', 'High'],
    );
  });

  test(
    'disables model editing and preserves saved model semantics when backend-only mode has no catalog',
    () {
      final initialProfile = configuredConnectionProfile().copyWith(
        model: 'saved-model-only',
        reasoningEffort: CodexReasoningEffort.xhigh,
      );
      const initialSecrets = ConnectionSecrets(password: 'secret');
      final formState = ConnectionSettingsFormState.initial(
        profile: initialProfile,
        secrets: initialSecrets,
      );

      final contract = presenter.present(
        initialProfile: initialProfile,
        initialSecrets: initialSecrets,
        formState: formState,
      );
      final payload = contract.saveAction.submitPayload;

      expect(contract.modelSection.selectedModelId, 'saved-model-only');
      expect(contract.modelSection.isModelEnabled, isFalse);
      expect(
        contract.modelSection.selectedReasoningEffort,
        CodexReasoningEffort.xhigh,
      );
      expect(contract.modelSection.isReasoningEffortEnabled, isFalse);
      expect(
        contract.modelSection.modelOptions.map((option) => option.label),
        <String>['saved-model-only'],
      );
      expect(
        contract.modelSection.reasoningEffortOptions.map(
          (option) => option.label,
        ),
        <String>['XHigh'],
      );
      expect(payload, isNotNull);
      expect(payload!.profile.model, 'saved-model-only');
      expect(payload.profile.reasoningEffort, CodexReasoningEffort.xhigh);
    },
  );

  test(
    'preserves a saved reasoning effort when the backend catalog has no matching effort options',
    () {
      final initialProfile = configuredConnectionProfile().copyWith(
        model: 'saved-model-only',
        reasoningEffort: CodexReasoningEffort.xhigh,
      );
      const initialSecrets = ConnectionSecrets(password: 'secret');
      final formState = ConnectionSettingsFormState.initial(
        profile: initialProfile,
        secrets: initialSecrets,
      );

      final contract = presenter.present(
        initialProfile: initialProfile,
        initialSecrets: initialSecrets,
        formState: formState,
        availableModelCatalog: ConnectionModelCatalog(
          connectionId: 'empty-catalog',
          fetchedAt: DateTime.utc(2026, 3, 22),
          models: <ConnectionAvailableModel>[],
        ),
      );
      final payload = contract.saveAction.submitPayload;

      expect(
        contract.modelSection.reasoningEffortOptions.map(
          (option) => option.label,
        ),
        <String>['Default', 'XHigh'],
      );
      expect(
        contract.modelSection.reasoningEffortHelperText,
        'Saved reasoning effort outside the available backend options.',
      );
      expect(
        contract.modelSection.selectedReasoningEffort,
        CodexReasoningEffort.xhigh,
      );
      expect(payload, isNotNull);
      expect(payload!.profile.reasoningEffort, CodexReasoningEffort.xhigh);
    },
  );

  test(
    'enables refresh when backend refresh is available and the workspace directory is set',
    () {
      final initialProfile = configuredConnectionProfile();
      const initialSecrets = ConnectionSecrets(password: 'secret');
      final formState = ConnectionSettingsFormState.initial(
        profile: initialProfile,
        secrets: initialSecrets,
      );

      final contract = presenter.present(
        initialProfile: initialProfile,
        initialSecrets: initialSecrets,
        formState: formState,
        supportsModelCatalogRefresh: true,
      );

      expect(contract.modelSection.isRefreshActionEnabled, isTrue);
      expect(
        contract.modelSection.refreshActionHelperText,
        contains('Refresh'),
      );
    },
  );

  test(
    'calls out cached model catalogs explicitly in the refresh helper text',
    () {
      final initialProfile = configuredConnectionProfile();
      const initialSecrets = ConnectionSecrets(password: 'secret');
      final formState = ConnectionSettingsFormState.initial(
        profile: initialProfile,
        secrets: initialSecrets,
      );

      final contract = presenter.present(
        initialProfile: initialProfile,
        initialSecrets: initialSecrets,
        formState: formState,
        availableModelCatalog: referenceModelCatalogForAgentAdapter(
          AgentAdapterKind.codex,
          connectionId: 'presenter-cache-copy-test',
          fetchedAt: DateTime.utc(2026, 3, 22, 12, 30),
        ),
        availableModelCatalogSource:
            ConnectionSettingsModelCatalogSource.lastKnownCache,
      );

      expect(
        contract.modelSection.refreshActionHelperText,
        'Showing last-known models from a previous backend refresh. They may not match this connection until it refreshes. Last refreshed 2026-03-22 12:30 UTC. Model refresh is available when this settings sheet is opened from a live backend connection.',
      );
    },
  );

  test('calls out refresh failure while preserving cached catalog context', () {
    final initialProfile = configuredConnectionProfile();
    const initialSecrets = ConnectionSecrets(password: 'secret');
    final formState = ConnectionSettingsFormState.initial(
      profile: initialProfile,
      secrets: initialSecrets,
    );

    final contract = presenter.present(
      initialProfile: initialProfile,
      initialSecrets: initialSecrets,
      formState: formState,
      availableModelCatalog: referenceModelCatalogForAgentAdapter(
        AgentAdapterKind.codex,
        connectionId: 'presenter-cache-failure-test',
        fetchedAt: DateTime.utc(2026, 3, 22, 15, 45),
      ),
      availableModelCatalogSource:
          ConnectionSettingsModelCatalogSource.lastKnownCache,
      modelCatalogRefreshError:
          ConnectionSettingsErrors.modelCatalogRefreshFailed(
            error: StateError('backend unavailable'),
          ),
      supportsModelCatalogRefresh: true,
    );

    expect(
      contract.modelSection.refreshActionHelperText,
      '[${PocketErrorCatalog.connectionSettingsModelCatalogRefreshFailed.code}] Could not load models from the backend. Underlying error: backend unavailable. Showing last-known models from a previous backend refresh. They may not match this connection until it refreshes. Last refreshed 2026-03-22 15:45 UTC. Use Refresh models to try again.',
    );
  });

  test('disables refresh when the workspace directory is empty', () {
    final initialProfile = configuredConnectionProfile().copyWith(
      workspaceDir: '',
    );
    const initialSecrets = ConnectionSecrets(password: 'secret');
    final formState = ConnectionSettingsFormState.initial(
      profile: initialProfile,
      secrets: initialSecrets,
    );

    final contract = presenter.present(
      initialProfile: initialProfile,
      initialSecrets: initialSecrets,
      formState: formState,
      supportsModelCatalogRefresh: true,
    );

    expect(contract.modelSection.isRefreshActionEnabled, isFalse);
    expect(
      contract.modelSection.refreshActionHelperText,
      'Set a workspace directory to enable model refresh.',
    );
  });

  test(
    'disables model metadata controls when the selected adapter does not expose them',
    () {
      final initialProfile = configuredConnectionProfile().copyWith(
        model: 'saved-model-only',
        reasoningEffort: CodexReasoningEffort.high,
      );
      const initialSecrets = ConnectionSecrets(password: 'secret');
      final formState = ConnectionSettingsFormState.initial(
        profile: initialProfile,
        secrets: initialSecrets,
      );

      final contract = presenter.present(
        initialProfile: initialProfile,
        initialSecrets: initialSecrets,
        formState: formState,
        supportsModelCatalogRefresh: true,
        agentAdapterCapabilities: const AgentAdapterCapabilities(),
      );

      expect(contract.modelSection.isModelEnabled, isFalse);
      expect(contract.modelSection.isReasoningEffortEnabled, isFalse);
      expect(contract.modelSection.isRefreshActionEnabled, isFalse);
      expect(
        contract.modelSection.modelHelperText,
        'This agent adapter does not expose model catalog metadata.',
      );
      expect(
        contract.modelSection.reasoningEffortHelperText,
        'This agent adapter does not expose reasoning controls.',
      );
      expect(
        contract.modelSection.refreshActionHelperText,
        'This agent adapter does not expose model catalog refresh.',
      );
    },
  );
}
