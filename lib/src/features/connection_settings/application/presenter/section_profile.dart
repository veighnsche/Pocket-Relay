part of '../connection_settings_presenter.dart';

ConnectionSettingsSectionContract _buildProfileSection(
  ConnectionSettingsDraft draft,
) {
  return ConnectionSettingsSectionContract(
    title: 'Profile',
    fields: <ConnectionSettingsTextFieldContract>[
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.label,
        label: 'Profile label',
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
    title: 'Connection mode',
    selectedMode: draft.connectionMode,
    options: const <ConnectionSettingsConnectionModeOptionContract>[
      ConnectionSettingsConnectionModeOptionContract(
        mode: ConnectionMode.remote,
        label: 'Remote',
        description: 'Connect to a developer box over SSH and run Codex there.',
      ),
      ConnectionSettingsConnectionModeOptionContract(
        mode: ConnectionMode.local,
        label: 'Local',
        description:
            'Run Codex app-server on this desktop and keep the workspace here.',
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
    title: 'Remote target',
    status: _buildRemoteTargetStatus(remoteRuntime),
    fields: <ConnectionSettingsTextFieldContract>[
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.host,
        label: 'Host',
        value: draft.host,
        hintText: 'devbox.local',
        errorText: state.hostError,
      ),
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.port,
        label: 'Port',
        value: draft.port,
        keyboardType: ConnectionSettingsKeyboardType.number,
        errorText: state.portError,
      ),
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.username,
        label: 'Username',
        value: draft.username,
        errorText: state.usernameError,
      ),
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.hostFingerprint,
        label: 'Host fingerprint',
        value: draft.hostFingerprint,
        hintText: 'aa:bb:cc:dd:...',
        helperText: _hostFingerprintHelperText(draft),
        errorText: state.hostFingerprintError,
      ),
    ],
  );
}

String _hostFingerprintHelperText(ConnectionSettingsDraft draft) {
  final hostIdentityLabel = _remoteHostIdentityLabel(draft);
  if (hostIdentityLabel == null) {
    return 'Required for remote targets. Pocket Relay shares one pinned fingerprint across every saved connection that points to the same host and port.';
  }

  if (draft.hostFingerprint.trim().isEmpty) {
    return 'Required for $hostIdentityLabel. Pocket Relay shares one pinned fingerprint across every saved connection that points there.';
  }

  return 'Shared host identity: $hostIdentityLabel. This pinned fingerprint is reused by every saved connection that points there.';
}

String? _remoteHostIdentityLabel(ConnectionSettingsDraft draft) {
  final host = draft.host.trim();
  if (host.isEmpty) {
    return null;
  }

  final port = draft.port.trim();
  if (port.isEmpty) {
    return host;
  }

  return '$host:$port';
}

ConnectionSettingsSectionStatusContract? _buildRemoteTargetStatus(
  ConnectionRemoteRuntimeState? remoteRuntime,
) {
  if (remoteRuntime == null) {
    return null;
  }

  final (label, detail) = switch (remoteRuntime.hostCapability.status) {
    ConnectionRemoteHostCapabilityStatus.unknown => (
      'Host status unknown',
      remoteRuntime.hostCapability.detail ??
          'Pocket Relay has not checked this remote target yet.',
    ),
    ConnectionRemoteHostCapabilityStatus.checking => (
      'Checking host',
      'Pocket Relay is checking whether this remote target can support continuity.',
    ),
    ConnectionRemoteHostCapabilityStatus.probeFailed => (
      'Host check failed',
      remoteRuntime.hostCapability.detail ??
          'Pocket Relay could not verify the remote target.',
    ),
    ConnectionRemoteHostCapabilityStatus.unsupported => (
      'Host unsupported',
      remoteRuntime.hostCapability.detail ??
          'This remote target does not satisfy the continuity prerequisites.',
    ),
    ConnectionRemoteHostCapabilityStatus.supported => switch (remoteRuntime
        .server
        .status) {
      ConnectionRemoteServerStatus.unknown => (
        'Host ready',
        'Pocket Relay verified the remote target.',
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
