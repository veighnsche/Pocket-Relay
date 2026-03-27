part of '../connection_settings_presenter.dart';

ConnectionSettingsSectionContract _buildProfileSection(
  ConnectionSettingsDraft draft,
) {
  return ConnectionSettingsSectionContract(
    title: 'Workspace',
    fields: <ConnectionSettingsTextFieldContract>[
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.label,
        label: 'Workspace name',
        value: draft.label,
      ),
    ],
  );
}

ConnectionSettingsConnectionModeSectionContract? _buildConnectionModeSection(
  ConnectionSettingsDraft draft, {
  required bool supportsLocalConnectionMode,
}) {
  if (!supportsLocalConnectionMode) {
    return null;
  }

  return ConnectionSettingsConnectionModeSectionContract(
    title: 'Workspace location',
    selectedMode: draft.connectionMode,
    options: const <ConnectionSettingsConnectionModeOptionContract>[
      ConnectionSettingsConnectionModeOptionContract(
        mode: ConnectionMode.remote,
        label: 'Remote',
        description: 'Run this workspace on a remote system over SSH.',
      ),
      ConnectionSettingsConnectionModeOptionContract(
        mode: ConnectionMode.local,
        label: 'Local',
        description:
            'Run this workspace on this device and keep the files here.',
      ),
    ],
  );
}

ConnectionSettingsSectionContract? _buildRemoteConnectionSection(
  _ConnectionSettingsPresentationState state, {
  required ConnectionRemoteRuntimeState? remoteRuntime,
}) {
  if (!state.isRemote) {
    return null;
  }

  final draft = state.draft;
  return ConnectionSettingsSectionContract(
    title: 'System',
    status: _buildRemoteTargetStatus(remoteRuntime),
    fields: <ConnectionSettingsTextFieldContract>[
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.host,
        label: 'Host',
        value: draft.host,
        hintText: 'devbox.local',
        helperText:
            'The hostname or IP address of the system that hosts this workspace.',
        errorText: state.hostError,
      ),
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.port,
        label: 'SSH port',
        value: draft.port,
        keyboardType: ConnectionSettingsKeyboardType.number,
        errorText: state.portError,
      ),
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.username,
        label: 'SSH username',
        value: draft.username,
        errorText: state.usernameError,
      ),
    ],
  );
}

ConnectionSettingsSectionStatusContract? _buildRemoteTargetStatus(
  ConnectionRemoteRuntimeState? remoteRuntime,
) {
  if (remoteRuntime == null) {
    return null;
  }

  final (label, detail) = switch (remoteRuntime.hostCapability.status) {
    ConnectionRemoteHostCapabilityStatus.unknown => (
      'System status unknown',
      remoteRuntime.hostCapability.detail ??
          'Pocket Relay has not checked this remote system yet.',
    ),
    ConnectionRemoteHostCapabilityStatus.checking => (
      'Checking system',
      'Pocket Relay is checking whether this remote system can support continuity.',
    ),
    ConnectionRemoteHostCapabilityStatus.probeFailed => (
      'System check failed',
      remoteRuntime.hostCapability.detail ??
          'Pocket Relay could not verify the remote system.',
    ),
    ConnectionRemoteHostCapabilityStatus.unsupported => (
      'System unsupported',
      remoteRuntime.hostCapability.detail ??
          'This remote system does not satisfy the continuity prerequisites.',
    ),
    ConnectionRemoteHostCapabilityStatus.supported => switch (remoteRuntime
        .server
        .status) {
      ConnectionRemoteServerStatus.unknown => (
        'System ready',
        'Pocket Relay verified the remote system.',
      ),
      ConnectionRemoteServerStatus.checking => (
        'Checking managed server',
        remoteRuntime.server.detail ??
            'Pocket Relay is checking the managed remote session.',
      ),
      ConnectionRemoteServerStatus.notRunning => (
        'Managed server stopped',
        remoteRuntime.server.detail ??
            'No managed remote session is running for this target.',
      ),
      ConnectionRemoteServerStatus.unhealthy => (
        'Managed server unhealthy',
        remoteRuntime.server.detail ??
            'The managed remote session exists but is not healthy enough to use.',
      ),
      ConnectionRemoteServerStatus.running => (
        'Managed server running',
        remoteRuntime.server.detail ?? 'The managed remote session is running.',
      ),
    },
  };

  return ConnectionSettingsSectionStatusContract(label: label, detail: detail);
}
