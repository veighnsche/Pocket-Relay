part of '../connection_settings_presenter.dart';

ConnectionSettingsAgentAdapterSectionContract _buildAgentAdapterSection(
  _ConnectionSettingsPresentationState state,
) {
  final draft = state.draft;
  final adapterLabel = agentAdapterLabel(draft.agentAdapter);
  final helperText = switch ((
    state.supportsRemoteConnectionMode,
    state.supportsLocalConnectionMode,
  )) {
    (true, true) => agentAdapterDescription(draft.agentAdapter),
    (true, false) =>
      '${agentAdapterDescription(draft.agentAdapter)} This adapter currently runs remote workspaces only on this device.',
    (false, true) =>
      '${agentAdapterDescription(draft.agentAdapter)} This adapter currently runs local workspaces only on this device.',
    (false, false) =>
      'This agent adapter does not support a workspace location Pocket Relay can run on this device.',
  };

  final status = state.hasSupportedConnectionMode
      ? null
      : const ConnectionSettingsSectionStatusContract(
          label: 'Unsupported on this device',
          detail:
              'This agent adapter does not support a workspace location Pocket Relay can run on this device.',
        );

  return ConnectionSettingsAgentAdapterSectionContract(
    title: 'Agent adapter',
    selectedAdapter: draft.agentAdapter,
    options: availableAgentAdapterDefinitions()
        .map<ConnectionSettingsAgentAdapterOptionContract>(
          (definition) => ConnectionSettingsAgentAdapterOptionContract(
            kind: definition.kind,
            label: definition.label,
            description: definition.description,
          ),
        )
        .toList(growable: false),
    helperText: helperText,
    status: status,
    fields: <ConnectionSettingsTextFieldContract>[
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.hostCommand,
        label: 'Agent command',
        value: draft.agentCommand,
        hintText: defaultCommandForAgentAdapter(draft.agentAdapter),
        helperText: state.isRemote
            ? 'Command used to launch $adapterLabel on the remote system inside this workspace before Pocket Relay appends runtime arguments.'
            : 'Command used to launch $adapterLabel on this device inside this workspace before Pocket Relay appends runtime arguments.',
        errorText: state.hostCommandError,
      ),
    ],
  );
}
