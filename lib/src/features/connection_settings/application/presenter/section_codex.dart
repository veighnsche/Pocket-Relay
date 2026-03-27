part of '../connection_settings_presenter.dart';

ConnectionSettingsSectionContract _buildCodexSection(
  _ConnectionSettingsPresentationState state,
) {
  final draft = state.draft;
  return ConnectionSettingsSectionContract(
    title: 'Workspace',
    fields: <ConnectionSettingsTextFieldContract>[
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.workspaceDir,
        label: 'Workspace directory',
        value: draft.workspaceDir,
        hintText: '/path/to/workspace',
        errorText: state.workspaceDirError,
      ),
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.codexPath,
        label: 'Codex command',
        value: draft.codexPath,
        hintText: 'codex or just codex-mcp',
        helperText: state.isRemote
            ? 'Command run on the remote system inside this workspace before app-server args are appended.'
            : 'Command run on this device inside this workspace before app-server args are appended.',
        errorText: state.codexPathError,
      ),
    ],
  );
}
