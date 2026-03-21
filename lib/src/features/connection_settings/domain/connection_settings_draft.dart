import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';

class ConnectionSettingsDraft {
  const ConnectionSettingsDraft({
    required this.label,
    required this.connectionMode,
    required this.host,
    required this.port,
    required this.username,
    required this.workspaceDir,
    required this.codexPath,
    required this.model,
    required this.reasoningEffort,
    required this.hostFingerprint,
    required this.password,
    required this.privateKeyPem,
    required this.privateKeyPassphrase,
    required this.authMode,
    required this.dangerouslyBypassSandbox,
    required this.ephemeralSession,
  });

  factory ConnectionSettingsDraft.fromConnection({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) {
    return ConnectionSettingsDraft(
      label: profile.label,
      connectionMode: profile.connectionMode,
      host: profile.host,
      port: profile.port.toString(),
      username: profile.username,
      workspaceDir: profile.workspaceDir,
      codexPath: profile.codexPath,
      model: profile.model,
      reasoningEffort: profile.reasoningEffort,
      hostFingerprint: profile.hostFingerprint,
      password: secrets.password,
      privateKeyPem: secrets.privateKeyPem,
      privateKeyPassphrase: secrets.privateKeyPassphrase,
      authMode: profile.authMode,
      dangerouslyBypassSandbox: profile.dangerouslyBypassSandbox,
      ephemeralSession: profile.ephemeralSession,
    );
  }

  final String label;
  final ConnectionMode connectionMode;
  final String host;
  final String port;
  final String username;
  final String workspaceDir;
  final String codexPath;
  final String model;
  final CodexReasoningEffort? reasoningEffort;
  final String hostFingerprint;
  final String password;
  final String privateKeyPem;
  final String privateKeyPassphrase;
  final AuthMode authMode;
  final bool dangerouslyBypassSandbox;
  final bool ephemeralSession;

  ConnectionSettingsDraft copyWith({
    String? label,
    ConnectionMode? connectionMode,
    String? host,
    String? port,
    String? username,
    String? workspaceDir,
    String? codexPath,
    String? model,
    Object? reasoningEffort = _draftSentinel,
    String? hostFingerprint,
    String? password,
    String? privateKeyPem,
    String? privateKeyPassphrase,
    AuthMode? authMode,
    bool? dangerouslyBypassSandbox,
    bool? ephemeralSession,
  }) {
    return ConnectionSettingsDraft(
      label: label ?? this.label,
      connectionMode: connectionMode ?? this.connectionMode,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      workspaceDir: workspaceDir ?? this.workspaceDir,
      codexPath: codexPath ?? this.codexPath,
      model: model ?? this.model,
      reasoningEffort: identical(reasoningEffort, _draftSentinel)
          ? this.reasoningEffort
          : reasoningEffort as CodexReasoningEffort?,
      hostFingerprint: hostFingerprint ?? this.hostFingerprint,
      password: password ?? this.password,
      privateKeyPem: privateKeyPem ?? this.privateKeyPem,
      privateKeyPassphrase: privateKeyPassphrase ?? this.privateKeyPassphrase,
      authMode: authMode ?? this.authMode,
      dangerouslyBypassSandbox:
          dangerouslyBypassSandbox ?? this.dangerouslyBypassSandbox,
      ephemeralSession: ephemeralSession ?? this.ephemeralSession,
    );
  }

  String valueForField(ConnectionSettingsFieldId fieldId) {
    return switch (fieldId) {
      ConnectionSettingsFieldId.label => label,
      ConnectionSettingsFieldId.host => host,
      ConnectionSettingsFieldId.port => port,
      ConnectionSettingsFieldId.username => username,
      ConnectionSettingsFieldId.workspaceDir => workspaceDir,
      ConnectionSettingsFieldId.codexPath => codexPath,
      ConnectionSettingsFieldId.model => model,
      ConnectionSettingsFieldId.hostFingerprint => hostFingerprint,
      ConnectionSettingsFieldId.password => password,
      ConnectionSettingsFieldId.privateKeyPem => privateKeyPem,
      ConnectionSettingsFieldId.privateKeyPassphrase => privateKeyPassphrase,
    };
  }

  ConnectionSettingsDraft copyWithConnectionMode(
    ConnectionMode connectionMode,
  ) {
    return copyWith(connectionMode: connectionMode);
  }

  ConnectionSettingsDraft copyWithField(
    ConnectionSettingsFieldId fieldId,
    String value,
  ) {
    return switch (fieldId) {
      ConnectionSettingsFieldId.label => copyWith(label: value),
      ConnectionSettingsFieldId.host => copyWith(host: value),
      ConnectionSettingsFieldId.port => copyWith(port: value),
      ConnectionSettingsFieldId.username => copyWith(username: value),
      ConnectionSettingsFieldId.workspaceDir => copyWith(workspaceDir: value),
      ConnectionSettingsFieldId.codexPath => copyWith(codexPath: value),
      ConnectionSettingsFieldId.model => copyWith(model: value),
      ConnectionSettingsFieldId.hostFingerprint => copyWith(
        hostFingerprint: value,
      ),
      ConnectionSettingsFieldId.password => copyWith(password: value),
      ConnectionSettingsFieldId.privateKeyPem => copyWith(privateKeyPem: value),
      ConnectionSettingsFieldId.privateKeyPassphrase => copyWith(
        privateKeyPassphrase: value,
      ),
    };
  }

  ConnectionSettingsDraft copyWithToggle(
    ConnectionSettingsToggleId toggleId,
    bool value,
  ) {
    return switch (toggleId) {
      ConnectionSettingsToggleId.dangerouslyBypassSandbox => copyWith(
        dangerouslyBypassSandbox: value,
      ),
      ConnectionSettingsToggleId.ephemeralSession => copyWith(
        ephemeralSession: value,
      ),
    };
  }
}

const Object _draftSentinel = Object();

class ConnectionSettingsFormState {
  const ConnectionSettingsFormState({
    required this.draft,
    this.showValidationErrors = false,
  });

  factory ConnectionSettingsFormState.initial({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) {
    return ConnectionSettingsFormState(
      draft: ConnectionSettingsDraft.fromConnection(
        profile: profile,
        secrets: secrets,
      ),
    );
  }

  final ConnectionSettingsDraft draft;
  final bool showValidationErrors;

  ConnectionSettingsFormState copyWith({
    ConnectionSettingsDraft? draft,
    bool? showValidationErrors,
  }) {
    return ConnectionSettingsFormState(
      draft: draft ?? this.draft,
      showValidationErrors: showValidationErrors ?? this.showValidationErrors,
    );
  }

  ConnectionSettingsFormState revealValidationErrors() {
    return copyWith(showValidationErrors: true);
  }
}
