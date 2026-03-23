import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_presenter.dart';

void main() {
  group('ConnectionSettingsPresenter', () {
    const presenter = ConnectionSettingsPresenter();

    test(
      'derives validation from form state instead of widget-local validators',
      () {
        final initialProfile = _configuredProfile();
        final initialSecrets = const ConnectionSecrets(password: 'secret');
        final formState =
            ConnectionSettingsFormState.initial(
              profile: initialProfile,
              secrets: initialSecrets,
            ).copyWith(
              draft: ConnectionSettingsDraft.fromConnection(
                profile: initialProfile,
                secrets: initialSecrets,
              ).copyWith(host: '', port: '70000', password: ''),
            );

        final hiddenErrors = presenter.present(
          initialProfile: initialProfile,
          initialSecrets: initialSecrets,
          formState: formState,
        );
        final visibleErrors = presenter.present(
          initialProfile: initialProfile,
          initialSecrets: initialSecrets,
          formState: formState.revealValidationErrors(),
        );

        expect(
          _field(
            visibleErrors.remoteConnectionSection!,
            ConnectionSettingsFieldId.host,
          ).errorText,
          'Host is required',
        );
        expect(
          _field(
            visibleErrors.remoteConnectionSection!,
            ConnectionSettingsFieldId.port,
          ).errorText,
          'Bad port',
        );
        expect(
          _field(
            visibleErrors.authenticationSection!,
            ConnectionSettingsFieldId.password,
          ).errorText,
          'Password is required',
        );
        expect(hiddenErrors.saveAction.canSubmit, isFalse);
        expect(visibleErrors.saveAction.canSubmit, isFalse);
        expect(visibleErrors.saveAction.submitPayload, isNull);
      },
    );

    test('derives auth visibility and validation from the selected mode', () {
      final initialProfile = _configuredProfile();
      const initialSecrets = ConnectionSecrets(password: 'secret');
      final formState =
          ConnectionSettingsFormState.initial(
            profile: initialProfile,
            secrets: initialSecrets,
          ).copyWith(
            draft: ConnectionSettingsDraft.fromConnection(
              profile: initialProfile,
              secrets: initialSecrets,
            ).copyWith(authMode: AuthMode.privateKey, privateKeyPem: ''),
            showValidationErrors: true,
          );

      final contract = presenter.present(
        initialProfile: initialProfile,
        initialSecrets: initialSecrets,
        formState: formState,
      );

      final authSection = contract.authenticationSection!;
      expect(authSection.selectedMode, AuthMode.privateKey);
      expect(
        authSection.fields.map((field) => field.id),
        <ConnectionSettingsFieldId>[
          ConnectionSettingsFieldId.privateKeyPem,
          ConnectionSettingsFieldId.privateKeyPassphrase,
        ],
      );
      expect(
        _field(authSection, ConnectionSettingsFieldId.privateKeyPem).errorText,
        'Private key is required',
      );
    });

    test('desktop local mode hides SSH sections and saves a local profile', () {
      final initialProfile = _configuredProfile();
      const initialSecrets = ConnectionSecrets(password: 'secret');
      final formState =
          ConnectionSettingsFormState.initial(
            profile: initialProfile,
            secrets: initialSecrets,
          ).copyWith(
            draft:
                ConnectionSettingsDraft.fromConnection(
                  profile: initialProfile,
                  secrets: initialSecrets,
                ).copyWith(
                  connectionMode: ConnectionMode.local,
                  workspaceDir: '/workspace/local',
                ),
            showValidationErrors: true,
          );

      final contract = presenter.present(
        initialProfile: initialProfile,
        initialSecrets: initialSecrets,
        formState: formState,
        availableModelCatalog: codexReferenceModelCatalog(
          connectionId: 'presenter-local-test',
        ),
        supportsLocalConnectionMode: true,
      );
      final payload = contract.saveAction.submitPayload;

      expect(contract.connectionModeSection, isNotNull);
      expect(contract.remoteConnectionSection, isNull);
      expect(contract.authenticationSection, isNull);
      expect(contract.codexSection.title, 'Local Codex');
      expect(contract.modelSection.selectedReasoningEffort, isNull);
      expect(
        contract.modelSection.modelOptions.any(
          (option) => option.modelId == 'gpt-5.4',
        ),
        isTrue,
      );
      expect(payload, isNotNull);
      expect(payload!.profile.connectionMode, ConnectionMode.local);
      expect(payload.profile.workspaceDir, '/workspace/local');
    });

    test(
      'derives dirty state and normalized save payload in the presenter',
      () {
        final initialProfile = _configuredProfile();
        const initialSecrets = ConnectionSecrets(password: 'secret');
        final formState =
            ConnectionSettingsFormState.initial(
              profile: initialProfile,
              secrets: initialSecrets,
            ).copyWith(
              draft:
                  ConnectionSettingsDraft.fromConnection(
                    profile: initialProfile,
                    secrets: initialSecrets,
                  ).copyWith(
                    label: '',
                    codexPath: 'codex-mcp',
                    dangerouslyBypassSandbox: true,
                  ),
              showValidationErrors: true,
            );

        final contract = presenter.present(
          initialProfile: initialProfile,
          initialSecrets: initialSecrets,
          formState: formState,
          availableModelCatalog: codexReferenceModelCatalog(
            connectionId: 'presenter-save-test',
          ),
        );
        final payload = contract.saveAction.submitPayload;

        expect(contract.saveAction.hasChanges, isTrue);
        expect(contract.saveAction.requiresValidation, isTrue);
        expect(contract.saveAction.canSubmit, isTrue);
        expect(payload, isNotNull);
        expect(payload!.profile.label, 'Developer Box');
        expect(payload.profile.codexPath, 'codex-mcp');
        expect(payload.profile.dangerouslyBypassSandbox, isTrue);
        expect(payload.secrets.password, 'secret');
      },
    );

    test(
      'includes model and reasoning effort in the normalized save payload',
      () {
        final initialProfile = _configuredProfile();
        const initialSecrets = ConnectionSecrets(password: 'secret');
        final formState =
            ConnectionSettingsFormState.initial(
              profile: initialProfile,
              secrets: initialSecrets,
            ).copyWith(
              draft:
                  ConnectionSettingsDraft.fromConnection(
                    profile: initialProfile,
                    secrets: initialSecrets,
                  ).copyWith(
                    model: '  gpt-5.4  ',
                    reasoningEffort: CodexReasoningEffort.high,
                  ),
              showValidationErrors: true,
            );

        final contract = presenter.present(
          initialProfile: initialProfile,
          initialSecrets: initialSecrets,
          formState: formState,
          availableModelCatalog: codexReferenceModelCatalog(
            connectionId: 'presenter-payload-test',
          ),
        );
        final payload = contract.saveAction.submitPayload;

        expect(
          contract.modelSection.selectedReasoningEffort,
          CodexReasoningEffort.high,
        );
        expect(payload, isNotNull);
        expect(payload!.profile.model, 'gpt-5.4');
        expect(payload.profile.reasoningEffort, CodexReasoningEffort.high);
      },
    );

    test('preserves remote runtime state for remote settings contracts', () {
      final initialProfile = _configuredProfile();
      const initialSecrets = ConnectionSecrets(password: 'secret');
      final formState = ConnectionSettingsFormState.initial(
        profile: initialProfile,
        secrets: initialSecrets,
      );
      const remoteRuntime = ConnectionRemoteRuntimeState(
        hostCapability: ConnectionRemoteHostCapabilityState.unsupported(
          issues: <ConnectionRemoteHostCapabilityIssue>{
            ConnectionRemoteHostCapabilityIssue.tmuxMissing,
          },
        ),
        server: ConnectionRemoteServerState.notRunning(
          detail: 'No Pocket Relay server is running.',
        ),
      );

      final contract = presenter.present(
        initialProfile: initialProfile,
        initialSecrets: initialSecrets,
        formState: formState,
        remoteRuntime: remoteRuntime,
      );

      expect(contract.remoteRuntime, remoteRuntime);
      expect(
        contract.remoteRuntime!.hostCapability.issues,
        <ConnectionRemoteHostCapabilityIssue>{
          ConnectionRemoteHostCapabilityIssue.tmuxMissing,
        },
      );
      expect(
        contract.remoteRuntime!.server.status,
        ConnectionRemoteServerStatus.notRunning,
      );
    });

    test('drops remote runtime state for local settings contracts', () {
      final initialProfile = _configuredProfile();
      const initialSecrets = ConnectionSecrets(password: 'secret');
      final formState =
          ConnectionSettingsFormState.initial(
            profile: initialProfile,
            secrets: initialSecrets,
          ).copyWith(
            draft: ConnectionSettingsDraft.fromConnection(
              profile: initialProfile,
              secrets: initialSecrets,
            ).copyWith(connectionMode: ConnectionMode.local),
          );
      const remoteRuntime = ConnectionRemoteRuntimeState(
        hostCapability: ConnectionRemoteHostCapabilityState.supported(),
        server: ConnectionRemoteServerState.running(port: 4100),
      );

      final contract = presenter.present(
        initialProfile: initialProfile,
        initialSecrets: initialSecrets,
        formState: formState,
        remoteRuntime: remoteRuntime,
        supportsLocalConnectionMode: true,
      );

      expect(contract.remoteRuntime, isNull);
    });

    test(
      'filters reasoning effort options to the selected reference model',
      () {
        final initialProfile = _configuredProfile();
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
          availableModelCatalog: codexReferenceModelCatalog(
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
      },
    );

    test(
      'disables model editing and preserves saved model semantics when backend-only mode has no catalog',
      () {
        final initialProfile = _configuredProfile().copyWith(
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
        final initialProfile = _configuredProfile().copyWith(
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
        final initialProfile = _configuredProfile();
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
        final initialProfile = _configuredProfile();
        const initialSecrets = ConnectionSecrets(password: 'secret');
        final formState = ConnectionSettingsFormState.initial(
          profile: initialProfile,
          secrets: initialSecrets,
        );

        final contract = presenter.present(
          initialProfile: initialProfile,
          initialSecrets: initialSecrets,
          formState: formState,
          availableModelCatalog: codexReferenceModelCatalog(
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
      final initialProfile = _configuredProfile();
      const initialSecrets = ConnectionSecrets(password: 'secret');
      final formState = ConnectionSettingsFormState.initial(
        profile: initialProfile,
        secrets: initialSecrets,
      );

      final contract = presenter.present(
        initialProfile: initialProfile,
        initialSecrets: initialSecrets,
        formState: formState,
        availableModelCatalog: codexReferenceModelCatalog(
          connectionId: 'presenter-cache-failure-test',
          fetchedAt: DateTime.utc(2026, 3, 22, 15, 45),
        ),
        availableModelCatalogSource:
            ConnectionSettingsModelCatalogSource.lastKnownCache,
        didModelCatalogRefreshFail: true,
        supportsModelCatalogRefresh: true,
      );

      expect(
        contract.modelSection.refreshActionHelperText,
        'Refresh failed. Showing the previous model list. Showing last-known models from a previous backend refresh. They may not match this connection until it refreshes. Last refreshed 2026-03-22 15:45 UTC. Use Refresh models to try again.',
      );
    });

    test('disables refresh when the workspace directory is empty', () {
      final initialProfile = _configuredProfile().copyWith(workspaceDir: '');
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
  });
}

ConnectionSettingsTextFieldContract _field(
  Object section,
  ConnectionSettingsFieldId fieldId,
) {
  final fields = switch (section) {
    ConnectionSettingsSectionContract(:final fields) => fields,
    ConnectionSettingsAuthenticationSectionContract(:final fields) => fields,
    _ => throw ArgumentError.value(section, 'section'),
  };

  return fields.singleWhere((field) => field.id == fieldId);
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
