part of '../connection_settings_presenter.dart';

ConnectionSettingsSystemPickerContract? _buildSystemPicker(
  _ConnectionSettingsPresentationState state,
) {
  if (!state.isRemote) {
    return null;
  }

  return ConnectionSettingsSystemPickerContract(
    title: 'System',
    helperText: state.availableSystemTemplates.isEmpty
        ? 'No systems are available yet. Create one from the Systems page, then come back and attach it to this workspace.'
        : 'Choose the system this workspace should run on. Manage machine access and trust from the Systems page.',
    selectedSystemId: state.selectedSystemTemplateId,
    options: state.availableSystemTemplates
        .map<ConnectionSettingsSystemOptionContract>(_systemOptionContract)
        .toList(growable: false),
  );
}

ConnectionSettingsSystemTrustContract? _buildSystemTrust(
  _ConnectionSettingsPresentationState state,
) {
  if (!state.isRemote) {
    return null;
  }

  final fingerprint = state.draft.hostFingerprint.trim();
  final matchedTemplate = state.selectedSystemTemplateId == null
      ? null
      : state.availableSystemTemplates
            .where((template) => template.id == state.selectedSystemTemplateId)
            .firstOrNull;
  if (state.isTestingSystem) {
    return const ConnectionSettingsSystemTrustContract(
      title: 'System trust',
      state: ConnectionSettingsSystemTrustStateKind.checking,
      statusLabel: 'Testing system',
      detail:
          'Pocket Relay is checking the SSH sign-in details and reading the host fingerprint.',
      actionLabel: 'Testing…',
      isActionEnabled: false,
      isActionInProgress: true,
    );
  }

  if (state.systemTestFailure case final failure?
      when failure.trim().isNotEmpty) {
    return ConnectionSettingsSystemTrustContract(
      title: 'System trust',
      state: ConnectionSettingsSystemTrustStateKind.failed,
      statusLabel: 'System test failed',
      detail: failure,
      actionLabel: 'Test system',
      isActionEnabled: state.canTestSystem,
      isActionInProgress: false,
      fingerprint: fingerprint.isEmpty ? null : fingerprint,
    );
  }

  if (fingerprint.isNotEmpty) {
    final isSavedSystem = matchedTemplate != null;
    return ConnectionSettingsSystemTrustContract(
      title: 'System trust',
      state: ConnectionSettingsSystemTrustStateKind.ready,
      statusLabel: isSavedSystem
          ? 'SSH fingerprint saved'
          : 'SSH fingerprint ready',
      detail: isSavedSystem
          ? 'This system already has a saved SSH fingerprint and can be reused across workspaces.'
          : 'This SSH fingerprint came from the latest system test and will be saved with this workspace.',
      actionLabel: 'Retest system',
      isActionEnabled: state.canTestSystem,
      isActionInProgress: false,
      fingerprint: fingerprint,
    );
  }

  return ConnectionSettingsSystemTrustContract(
    title: 'System trust',
    state: ConnectionSettingsSystemTrustStateKind.needsTest,
    statusLabel: 'SSH fingerprint needed',
    detail: state.supportsSystemTesting
        ? 'Test this system to fetch its SSH fingerprint before saving the workspace.'
        : 'System testing is not available from this surface, so this workspace cannot save a fingerprint yet.',
    actionLabel: 'Test system',
    isActionEnabled: state.canTestSystem,
    isActionInProgress: false,
  );
}

ConnectionSettingsSystemOptionContract _systemOptionContract(
  ConnectionSettingsSystemTemplate template,
) {
  final profile = template.profile;
  final username = profile.username.trim();
  final host = profile.host.trim();
  final hostLabel = profile.port == 22 ? host : '$host:${profile.port}';
  final signInLabel = switch (profile.authMode) {
    AuthMode.password => 'Password sign-in',
    AuthMode.privateKey => 'Private key sign-in',
  };
  final trustLabel = profile.hostFingerprint.trim().isEmpty
      ? 'Fingerprint needs test'
      : 'Trusted fingerprint saved';
  return ConnectionSettingsSystemOptionContract(
    id: template.id,
    label: '$hostLabel as $username',
    description: '$signInLabel · $trustLabel',
  );
}
