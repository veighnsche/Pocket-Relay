import 'package:pocket_relay/src/core/models/connection_models.dart';

enum ConnectionSettingsFieldId {
  label,
  host,
  port,
  username,
  workspaceDir,
  codexPath,
  model,
  hostFingerprint,
  password,
  privateKeyPem,
  privateKeyPassphrase,
}

enum ConnectionSettingsKeyboardType { text, number }

enum ConnectionSettingsAuthOptionIcon { password, privateKey }

enum ConnectionSettingsModelCatalogSource { connectionCache, lastKnownCache }

class ConnectionSettingsConnectionModeOptionContract {
  const ConnectionSettingsConnectionModeOptionContract({
    required this.mode,
    required this.label,
    required this.description,
  });

  final ConnectionMode mode;
  final String label;
  final String description;
}

class ConnectionSettingsConnectionModeSectionContract {
  const ConnectionSettingsConnectionModeSectionContract({
    required this.title,
    required this.selectedMode,
    required this.options,
  });

  final String title;
  final ConnectionMode selectedMode;
  final List<ConnectionSettingsConnectionModeOptionContract> options;
}

class ConnectionSettingsSystemOptionContract {
  const ConnectionSettingsSystemOptionContract({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;
}

class ConnectionSettingsSystemPickerContract {
  const ConnectionSettingsSystemPickerContract({
    required this.title,
    required this.helperText,
    required this.selectedSystemId,
    required this.options,
  });

  final String title;
  final String helperText;
  final String? selectedSystemId;
  final List<ConnectionSettingsSystemOptionContract> options;
}

enum ConnectionSettingsSystemTrustStateKind {
  needsTest,
  checking,
  ready,
  failed,
}

class ConnectionSettingsSystemTrustContract {
  const ConnectionSettingsSystemTrustContract({
    required this.title,
    required this.state,
    required this.statusLabel,
    required this.detail,
    required this.actionLabel,
    required this.isActionEnabled,
    required this.isActionInProgress,
    this.fingerprint,
  });

  final String title;
  final ConnectionSettingsSystemTrustStateKind state;
  final String statusLabel;
  final String detail;
  final String actionLabel;
  final bool isActionEnabled;
  final bool isActionInProgress;
  final String? fingerprint;
}

enum ConnectionSettingsToggleId { dangerouslyBypassSandbox, ephemeralSession }

enum ConnectionSettingsRemoteServerActionId { start, stop, restart }

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

class ConnectionSettingsSectionContract {
  const ConnectionSettingsSectionContract({
    required this.title,
    required this.fields,
    this.status,
  });

  final String title;
  final List<ConnectionSettingsTextFieldContract> fields;
  final ConnectionSettingsSectionStatusContract? status;
}

class ConnectionSettingsSectionStatusContract {
  const ConnectionSettingsSectionStatusContract({
    required this.label,
    required this.detail,
  });

  final String label;
  final String detail;
}

class ConnectionSettingsReasoningEffortOptionContract {
  const ConnectionSettingsReasoningEffortOptionContract({
    required this.effort,
    required this.label,
    required this.description,
  });

  final CodexReasoningEffort? effort;
  final String label;
  final String description;
}

class ConnectionSettingsModelOptionContract {
  const ConnectionSettingsModelOptionContract({
    required this.modelId,
    required this.label,
    required this.description,
  });

  final String? modelId;
  final String label;
  final String description;
}

class ConnectionSettingsModelSectionContract {
  const ConnectionSettingsModelSectionContract({
    required this.title,
    required this.selectedModelId,
    required this.modelOptions,
    required this.modelHelperText,
    required this.isModelEnabled,
    required this.selectedReasoningEffort,
    required this.reasoningEffortOptions,
    required this.reasoningEffortHelperText,
    required this.isReasoningEffortEnabled,
    required this.refreshActionLabel,
    required this.refreshActionHelperText,
    required this.isRefreshActionEnabled,
    required this.isRefreshActionInProgress,
  });

  final String title;
  final String? selectedModelId;
  final List<ConnectionSettingsModelOptionContract> modelOptions;
  final String modelHelperText;
  final bool isModelEnabled;
  final CodexReasoningEffort? selectedReasoningEffort;
  final List<ConnectionSettingsReasoningEffortOptionContract>
  reasoningEffortOptions;
  final String reasoningEffortHelperText;
  final bool isReasoningEffortEnabled;
  final String refreshActionLabel;
  final String refreshActionHelperText;
  final bool isRefreshActionEnabled;
  final bool isRefreshActionInProgress;
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
    required this.profileSection,
    required this.codexSection,
    required this.modelSection,
    required this.runModeSection,
    required this.saveAction,
    this.connectionModeSection,
    this.systemPicker,
    this.remoteConnectionSection,
    this.authenticationSection,
    this.systemTrust,
    this.remoteRuntime,
  });

  final String title;
  final String description;
  final ConnectionSettingsSectionContract profileSection;
  final ConnectionSettingsSectionContract codexSection;
  final ConnectionSettingsModelSectionContract modelSection;
  final ConnectionSettingsConnectionModeSectionContract? connectionModeSection;
  final ConnectionSettingsSystemPickerContract? systemPicker;
  final ConnectionSettingsSectionContract? remoteConnectionSection;
  final ConnectionSettingsAuthenticationSectionContract? authenticationSection;
  final ConnectionSettingsSystemTrustContract? systemTrust;
  final ConnectionSettingsRunModeSectionContract runModeSection;
  final ConnectionSettingsSaveActionContract saveAction;
  final ConnectionRemoteRuntimeState? remoteRuntime;
}
