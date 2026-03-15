import 'package:pocket_relay/src/core/models/connection_models.dart';

enum ConnectionSettingsFieldId {
  label,
  host,
  port,
  username,
  workspaceDir,
  codexPath,
  hostFingerprint,
  password,
  privateKeyPem,
  privateKeyPassphrase,
}

enum ConnectionSettingsKeyboardType { text, number }

enum ConnectionSettingsAuthOptionIcon { password, privateKey }

enum ConnectionSettingsToggleId {
  dangerouslyBypassSandbox,
  ephemeralSession,
}

class ConnectionSettingsTextFieldContract {
  const ConnectionSettingsTextFieldContract({
    required this.id,
    required this.label,
    required this.value,
    this.hintText,
    this.helperText,
    this.errorText,
    this.keyboardType = ConnectionSettingsKeyboardType.text,
    this.obscureText = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.alignLabelWithHint = false,
  });

  final ConnectionSettingsFieldId id;
  final String label;
  final String value;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final ConnectionSettingsKeyboardType keyboardType;
  final bool obscureText;
  final int minLines;
  final int maxLines;
  final bool alignLabelWithHint;
}

class ConnectionSettingsFieldSectionContract {
  const ConnectionSettingsFieldSectionContract({
    required this.title,
    required this.fields,
  });

  final String title;
  final List<ConnectionSettingsTextFieldContract> fields;
}

class ConnectionSettingsAuthOptionContract {
  const ConnectionSettingsAuthOptionContract({
    required this.mode,
    required this.label,
    required this.icon,
  });

  final AuthMode mode;
  final String label;
  final ConnectionSettingsAuthOptionIcon icon;
}

class ConnectionSettingsAuthenticationSectionContract {
  const ConnectionSettingsAuthenticationSectionContract({
    required this.title,
    required this.selectedMode,
    required this.options,
    required this.fields,
  });

  final String title;
  final AuthMode selectedMode;
  final List<ConnectionSettingsAuthOptionContract> options;
  final List<ConnectionSettingsTextFieldContract> fields;
}

class ConnectionSettingsToggleContract {
  const ConnectionSettingsToggleContract({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final ConnectionSettingsToggleId id;
  final String title;
  final String subtitle;
  final bool value;
}

class ConnectionSettingsRunModeSectionContract {
  const ConnectionSettingsRunModeSectionContract({
    required this.title,
    required this.toggles,
  });

  final String title;
  final List<ConnectionSettingsToggleContract> toggles;
}

class ConnectionSettingsSubmitPayload {
  const ConnectionSettingsSubmitPayload({
    required this.profile,
    required this.secrets,
  });

  final ConnectionProfile profile;
  final ConnectionSecrets secrets;
}

class ConnectionSettingsSaveActionContract {
  const ConnectionSettingsSaveActionContract({
    required this.label,
    required this.hasChanges,
    required this.requiresValidation,
    required this.canSubmit,
    this.submitPayload,
  });

  final String label;
  final bool hasChanges;
  final bool requiresValidation;
  final bool canSubmit;
  final ConnectionSettingsSubmitPayload? submitPayload;
}

class ConnectionSettingsContract {
  const ConnectionSettingsContract({
    required this.title,
    required this.description,
    required this.identitySection,
    required this.remoteCodexSection,
    required this.authenticationSection,
    required this.runModeSection,
    required this.saveAction,
  });

  final String title;
  final String description;
  final ConnectionSettingsFieldSectionContract identitySection;
  final ConnectionSettingsFieldSectionContract remoteCodexSection;
  final ConnectionSettingsAuthenticationSectionContract authenticationSection;
  final ConnectionSettingsRunModeSectionContract runModeSection;
  final ConnectionSettingsSaveActionContract saveAction;
}
