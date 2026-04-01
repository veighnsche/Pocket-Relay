import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_system_template.dart';

List<ConnectionSettingsSystemTemplate> deriveConnectionSettingsSystemTemplates(
  Iterable<SavedConnection> connections,
) {
  final templatesByKey =
      <_ReusableRemoteSystemKey, ConnectionSettingsSystemTemplate>{};
  final orderedKeys = <_ReusableRemoteSystemKey>[];

  for (final connection in connections) {
    final key = _ReusableRemoteSystemKey.fromConnection(
      profile: connection.profile,
      secrets: connection.secrets,
    );
    if (key == null) {
      continue;
    }

    final template = ConnectionSettingsSystemTemplate(
      id: connection.id,
      profile: connection.profile,
      secrets: connection.secrets,
    );
    final existing = templatesByKey[key];
    if (existing == null) {
      orderedKeys.add(key);
      templatesByKey[key] = template;
      continue;
    }

    final existingFingerprint = existing.profile.hostFingerprint.trim();
    final nextFingerprint = template.profile.hostFingerprint.trim();
    if (existingFingerprint.isEmpty && nextFingerprint.isNotEmpty) {
      templatesByKey[key] = template;
    }
  }

  return <ConnectionSettingsSystemTemplate>[
    for (final key in orderedKeys) templatesByKey[key]!,
  ];
}

List<ConnectionSettingsSystemTemplate>
deriveConnectionSettingsSystemTemplatesFromSystems(
  Iterable<SavedSystem> systems,
) {
  return <ConnectionSettingsSystemTemplate>[
    for (final system in systems)
      ConnectionSettingsSystemTemplate(
        id: system.id,
        profile: connectionProfileFromWorkspace(
          workspace: WorkspaceProfile(
            label: 'Workspace',
            connectionMode: ConnectionMode.remote,
            systemId: null,
            workspaceDir: '',
            codexPath: 'codex',
            dangerouslyBypassSandbox: false,
            ephemeralSession: false,
          ),
          system: system,
        ),
        secrets: system.secrets,
      ),
  ];
}

String? matchingConnectionSettingsSystemTemplateId({
  required ConnectionSettingsDraft draft,
  required List<ConnectionSettingsSystemTemplate> templates,
}) {
  final draftKey = _ReusableRemoteSystemKey.fromDraft(draft);
  if (draftKey == null) {
    return null;
  }

  for (final template in templates) {
    final templateKey = _ReusableRemoteSystemKey.fromConnection(
      profile: template.profile,
      secrets: template.secrets,
    );
    if (templateKey == draftKey) {
      return template.id;
    }
  }

  return null;
}

ConnectionSettingsDraft applyConnectionSettingsSystemTemplate({
  required ConnectionSettingsDraft draft,
  required ConnectionSettingsSystemTemplate template,
}) {
  return draft.copyWith(
    connectionMode: ConnectionMode.remote,
    host: template.profile.host,
    port: template.profile.port.toString(),
    username: template.profile.username,
    hostFingerprint: template.profile.hostFingerprint,
    authMode: template.profile.authMode,
    password: template.secrets.password,
    privateKeyPem: template.secrets.privateKeyPem,
    privateKeyPassphrase: template.secrets.privateKeyPassphrase,
  );
}

class _ReusableRemoteSystemKey {
  const _ReusableRemoteSystemKey({
    required this.host,
    required this.port,
    required this.username,
    required this.authMode,
    required this.secretMaterial,
    required this.secretAuxiliary,
  });

  final String host;
  final int port;
  final String username;
  final AuthMode authMode;
  final String secretMaterial;
  final String secretAuxiliary;

  static _ReusableRemoteSystemKey? fromConnection({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) {
    if (!profile.isRemote) {
      return null;
    }
    final normalizedHost = profile.host.trim().toLowerCase();
    final normalizedUsername = profile.username.trim();
    if (normalizedHost.isEmpty || normalizedUsername.isEmpty) {
      return null;
    }

    return switch (profile.authMode) {
      AuthMode.password when secrets.password.isNotEmpty =>
        _ReusableRemoteSystemKey(
          host: normalizedHost,
          port: profile.port,
          username: normalizedUsername,
          authMode: profile.authMode,
          secretMaterial: secrets.password,
          secretAuxiliary: '',
        ),
      AuthMode.privateKey when secrets.privateKeyPem.trim().isNotEmpty =>
        _ReusableRemoteSystemKey(
          host: normalizedHost,
          port: profile.port,
          username: normalizedUsername,
          authMode: profile.authMode,
          secretMaterial: secrets.privateKeyPem,
          secretAuxiliary: secrets.privateKeyPassphrase,
        ),
      _ => null,
    };
  }

  static _ReusableRemoteSystemKey? fromDraft(ConnectionSettingsDraft draft) {
    if (draft.connectionMode != ConnectionMode.remote) {
      return null;
    }
    final normalizedHost = draft.host.trim().toLowerCase();
    final normalizedUsername = draft.username.trim();
    if (normalizedHost.isEmpty || normalizedUsername.isEmpty) {
      return null;
    }

    return switch (draft.authMode) {
      AuthMode.password when draft.password.isNotEmpty =>
        _ReusableRemoteSystemKey(
          host: normalizedHost,
          port: int.tryParse(draft.port.trim()) ?? 22,
          username: normalizedUsername,
          authMode: draft.authMode,
          secretMaterial: draft.password,
          secretAuxiliary: '',
        ),
      AuthMode.privateKey when draft.privateKeyPem.trim().isNotEmpty =>
        _ReusableRemoteSystemKey(
          host: normalizedHost,
          port: int.tryParse(draft.port.trim()) ?? 22,
          username: normalizedUsername,
          authMode: draft.authMode,
          secretMaterial: draft.privateKeyPem,
          secretAuxiliary: draft.privateKeyPassphrase,
        ),
      _ => null,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is _ReusableRemoteSystemKey &&
        other.host == host &&
        other.port == port &&
        other.username == username &&
        other.authMode == authMode &&
        other.secretMaterial == secretMaterial &&
        other.secretAuxiliary == secretAuxiliary;
  }

  @override
  int get hashCode => Object.hash(
    host,
    port,
    username,
    authMode,
    secretMaterial,
    secretAuxiliary,
  );
}
