part of '../connection_settings_presenter.dart';

ConnectionSettingsSubmitPayload _buildSubmitPayload({
  required ConnectionProfile initialProfile,
  required ConnectionSecrets initialSecrets,
  required _ConnectionSettingsPresentationState state,
}) {
  final draft = state.draft;
  final presenter = const ConnectionSettingsPresenter();
  final capabilities = state.agentAdapterCapabilities;
  return ConnectionSettingsSubmitPayload(
    profile: initialProfile.copyWith(
      label: presenter._normalizedLabel(draft.label),
      connectionMode: draft.connectionMode,
      agentAdapter: draft.agentAdapter,
      host: draft.host.trim(),
      port: state.port ?? initialProfile.port,
      username: draft.username.trim(),
      workspaceDir: draft.workspaceDir.trim(),
      agentCommand: draft.agentCommand.trim(),
      model: _selectedModelIdForDraft(draft) ?? '',
      reasoningEffort: capabilities.supportsReasoningEffort
          ? codexNormalizedReasoningEffortForModel(
              _selectedModelIdForDraft(draft),
              draft.reasoningEffort,
              availableModelCatalog: state.availableModelCatalog,
            )
          : null,
      authMode: draft.authMode,
      hostFingerprint: draft.hostFingerprint.trim(),
      dangerouslyBypassSandbox:
          capabilities.supportsDangerouslyBypassSandbox
          ? draft.dangerouslyBypassSandbox
          : false,
      ephemeralSession: capabilities.supportsEphemeralSessions
          ? draft.ephemeralSession
          : false,
    ),
    secrets: initialSecrets.copyWith(
      password: draft.password,
      privateKeyPem: draft.privateKeyPem,
      privateKeyPassphrase: draft.privateKeyPassphrase,
    ),
  );
}
