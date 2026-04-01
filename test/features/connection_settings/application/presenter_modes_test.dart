import 'package:pocket_relay/src/agent_adapters/agent_adapter_capabilities.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_presenter.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';

import 'presenter_test_support.dart';

void main() {
  const presenter = ConnectionSettingsPresenter();

  test('desktop local mode hides SSH sections and saves a local profile', () {
    final initialProfile = configuredConnectionProfile();
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
      availableModelCatalog: referenceModelCatalogForAgentAdapter(
        AgentAdapterKind.codex,
        connectionId: 'presenter-local-test',
      ),
      supportsLocalConnectionMode: true,
    );
    final payload = contract.saveAction.submitPayload;

    expect(contract.connectionModeSection, isNotNull);
    expect(contract.remoteConnectionSection, isNull);
    expect(contract.authenticationSection, isNull);
    expect(contract.systemTrust, isNull);
    expect(
      settingsField(
        contract.profileSection,
        ConnectionSettingsFieldId.workspaceDir,
      ).label,
      'Workspace directory',
    );
    expect(contract.agentAdapterSection.options, hasLength(1));
    expect(
      contract.agentAdapterSection.selectedAdapter,
      AgentAdapterKind.codex,
    );
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

  test('drops remote runtime state for local settings contracts', () {
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
    expect(contract.remoteConnectionSection, isNull);
  });

  test('run mode toggles follow the selected adapter capability contract', () {
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
      agentAdapterCapabilities: const AgentAdapterCapabilities(),
    );

    expect(contract.connectionModeSection, isNull);
    expect(contract.agentAdapterSection.status, isNotNull);
    expect(contract.saveAction.canSubmit, isFalse);
    expect(contract.runModeSection.toggles, isEmpty);
  });

  test('submit drops hidden run-mode flags for unsupported adapters', () {
    final initialProfile = configuredConnectionProfile();
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
                dangerouslyBypassSandbox: true,
                ephemeralSession: true,
              ),
        );

    final contract = presenter.present(
      initialProfile: initialProfile,
      initialSecrets: initialSecrets,
      formState: formState,
      agentAdapterCapabilities: const AgentAdapterCapabilities(
        supportsRemoteConnections: true,
      ),
    );

    expect(contract.saveAction.submitPayload, isNotNull);
    expect(
      contract.saveAction.submitPayload!.profile.dangerouslyBypassSandbox,
      isFalse,
    );
    expect(contract.saveAction.submitPayload!.profile.ephemeralSession, isFalse);
  });

  test('submit drops reasoning effort when the adapter does not support it', () {
    final initialProfile = configuredConnectionProfile();
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
              ).copyWith(reasoningEffort: CodexReasoningEffort.high),
        );

    final contract = presenter.present(
      initialProfile: initialProfile,
      initialSecrets: initialSecrets,
      formState: formState,
      agentAdapterCapabilities: const AgentAdapterCapabilities(
        supportsRemoteConnections: true,
      ),
    );

    expect(contract.saveAction.submitPayload, isNotNull);
    expect(contract.saveAction.submitPayload!.profile.reasoningEffort, isNull);
  });

  test(
    'unsupported adapter routing falls back to the adapter description helper text',
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
        agentAdapterCapabilities: const AgentAdapterCapabilities(),
      );

      expect(
        contract.agentAdapterSection.helperText,
        agentAdapterDescription(AgentAdapterKind.codex),
      );
      expect(contract.agentAdapterSection.status, isNotNull);
    },
  );
}
