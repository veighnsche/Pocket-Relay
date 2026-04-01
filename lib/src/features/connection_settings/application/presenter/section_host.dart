part of '../connection_settings_presenter.dart';

ConnectionSettingsSectionContract _buildHostSection(
  _ConnectionSettingsPresentationState state,
) {
  final draft = state.draft;
  final adapterLabel = agentAdapterLabel(draft.agentAdapter);
  return ConnectionSettingsSectionContract(
    title: 'Agent adapter',
    fields: <ConnectionSettingsTextFieldContract>[
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.workspaceDir,
        label: 'Workspace directory',
        value: draft.workspaceDir,
        hintText: '/path/to/workspace',
        errorText: state.workspaceDirError,
      ),
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
