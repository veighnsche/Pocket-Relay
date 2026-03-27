part of 'connection_settings_presenter.dart';

class _ConnectionSettingsPresentationState {
  const _ConnectionSettingsPresentationState({
    required this.draft,
    required this.availableModelCatalog,
    required this.availableModelCatalogSource,
    required this.availableSystemTemplates,
    required this.selectedSystemTemplateId,
    required this.modelCatalogRefreshError,
    required this.supportsModelCatalogRefresh,
    required this.isRefreshingModelCatalog,
    required this.isTestingSystem,
    required this.systemTestFailure,
    required this.supportsSystemTesting,
    required this.canTestSystem,
    required this.isRemote,
    required this.hasChanges,
    required this.canSubmit,
    required this.port,
    required this.hostError,
    required this.portError,
    required this.usernameError,
    required this.hostFingerprintError,
    required this.workspaceDirError,
    required this.codexPathError,
    required this.passwordError,
    required this.privateKeyError,
  });

  factory _ConnectionSettingsPresentationState.fromForm({
    required ConnectionProfile initialProfile,
    required ConnectionSecrets initialSecrets,
    required ConnectionSettingsFormState formState,
    ConnectionModelCatalog? availableModelCatalog,
    ConnectionSettingsModelCatalogSource? availableModelCatalogSource,
    List<ConnectionSettingsSystemTemplate> availableSystemTemplates =
        const <ConnectionSettingsSystemTemplate>[],
    PocketUserFacingError? modelCatalogRefreshError,
    bool supportsModelCatalogRefresh = false,
    bool isRefreshingModelCatalog = false,
    bool isTestingSystem = false,
    String? systemTestFailure,
    bool supportsSystemTesting = false,
  }) {
    final draft = formState.draft;
    final isRemote = draft.connectionMode == ConnectionMode.remote;
    final hasChanges = _hasChanges(
      initialProfile: initialProfile,
      initialSecrets: initialSecrets,
      draft: draft,
    );
    final shouldShowValidationErrors =
        formState.showValidationErrors && hasChanges;
    final port = int.tryParse(draft.port.trim());
    final hasHostError = isRemote && draft.host.trim().isEmpty;
    final hasPortError = isRemote && (port == null || port < 1 || port > 65535);
    final hasUsernameError = isRemote && draft.username.trim().isEmpty;
    final hasHostFingerprintError =
        isRemote && draft.hostFingerprint.trim().isEmpty;
    final hasWorkspaceDirError = draft.workspaceDir.trim().isEmpty;
    final hasCodexPathError = draft.codexPath.trim().isEmpty;
    final hasPasswordError =
        isRemote &&
        draft.authMode == AuthMode.password &&
        draft.password.isEmpty;
    final hasPrivateKeyError =
        isRemote &&
        draft.authMode == AuthMode.privateKey &&
        draft.privateKeyPem.trim().isEmpty;

    final hostError = _requiredError(
      value: draft.host,
      message: 'Host is required',
      show: shouldShowValidationErrors && isRemote,
    );
    final portError = _portError(
      value: draft.port,
      show: shouldShowValidationErrors && isRemote,
    );
    final usernameError = _requiredError(
      value: draft.username,
      message: 'Username is required',
      show: shouldShowValidationErrors && isRemote,
    );
    final hostFingerprintError = _requiredError(
      value: draft.hostFingerprint,
      message: 'Test this system to save its fingerprint.',
      show: shouldShowValidationErrors && isRemote,
    );
    final workspaceDirError = _requiredError(
      value: draft.workspaceDir,
      message: 'Workspace directory is required',
      show: shouldShowValidationErrors,
    );
    final codexPathError = _requiredError(
      value: draft.codexPath,
      message: 'Codex launch command is required',
      show: shouldShowValidationErrors,
    );
    final passwordError = shouldShowValidationErrors && hasPasswordError
        ? 'Password is required'
        : null;
    final privateKeyError = _requiredError(
      value: draft.privateKeyPem,
      message: 'Private key is required',
      show:
          shouldShowValidationErrors &&
          isRemote &&
          draft.authMode == AuthMode.privateKey,
    );
    final hasValidationErrors =
        hasHostError ||
        hasPortError ||
        hasUsernameError ||
        hasHostFingerprintError ||
        hasWorkspaceDirError ||
        hasCodexPathError ||
        hasPasswordError ||
        hasPrivateKeyError;
    final canTestSystem =
        supportsSystemTesting &&
        isRemote &&
        !isTestingSystem &&
        !hasHostError &&
        !hasPortError &&
        !hasUsernameError &&
        !hasPasswordError &&
        !hasPrivateKeyError;

    return _ConnectionSettingsPresentationState(
      draft: draft,
      availableModelCatalog: availableModelCatalog,
      availableModelCatalogSource: availableModelCatalogSource,
      availableSystemTemplates: availableSystemTemplates,
      selectedSystemTemplateId: matchingConnectionSettingsSystemTemplateId(
        draft: draft,
        templates: availableSystemTemplates,
      ),
      modelCatalogRefreshError: modelCatalogRefreshError,
      supportsModelCatalogRefresh: supportsModelCatalogRefresh,
      isRefreshingModelCatalog: isRefreshingModelCatalog,
      isTestingSystem: isTestingSystem,
      systemTestFailure: systemTestFailure,
      supportsSystemTesting: supportsSystemTesting,
      canTestSystem: canTestSystem,
      isRemote: isRemote,
      hasChanges: hasChanges,
      canSubmit: !hasChanges || !hasValidationErrors,
      port: port,
      hostError: hostError,
      portError: portError,
      usernameError: usernameError,
      hostFingerprintError: hostFingerprintError,
      workspaceDirError: workspaceDirError,
      codexPathError: codexPathError,
      passwordError: passwordError,
      privateKeyError: privateKeyError,
    );
  }

  final ConnectionSettingsDraft draft;
  final ConnectionModelCatalog? availableModelCatalog;
  final ConnectionSettingsModelCatalogSource? availableModelCatalogSource;
  final List<ConnectionSettingsSystemTemplate> availableSystemTemplates;
  final String? selectedSystemTemplateId;
  final PocketUserFacingError? modelCatalogRefreshError;
  final bool supportsModelCatalogRefresh;
  final bool isRefreshingModelCatalog;
  final bool isTestingSystem;
  final String? systemTestFailure;
  final bool supportsSystemTesting;
  final bool canTestSystem;
  final bool isRemote;
  final bool hasChanges;
  final bool canSubmit;
  final int? port;
  final String? hostError;
  final String? portError;
  final String? usernameError;
  final String? hostFingerprintError;
  final String? workspaceDirError;
  final String? codexPathError;
  final String? passwordError;
  final String? privateKeyError;
}

bool _hasChanges({
  required ConnectionProfile initialProfile,
  required ConnectionSecrets initialSecrets,
  required ConnectionSettingsDraft draft,
}) {
  return draft.label.trim() != initialProfile.label ||
      draft.connectionMode != initialProfile.connectionMode ||
      draft.host.trim() != initialProfile.host ||
      draft.port.trim() != initialProfile.port.toString() ||
      draft.username.trim() != initialProfile.username ||
      draft.workspaceDir.trim() != initialProfile.workspaceDir ||
      draft.codexPath.trim() != initialProfile.codexPath ||
      draft.model.trim() != initialProfile.model ||
      draft.reasoningEffort != initialProfile.reasoningEffort ||
      draft.hostFingerprint.trim() != initialProfile.hostFingerprint ||
      draft.password != initialSecrets.password ||
      draft.privateKeyPem != initialSecrets.privateKeyPem ||
      draft.privateKeyPassphrase != initialSecrets.privateKeyPassphrase ||
      draft.authMode != initialProfile.authMode ||
      draft.dangerouslyBypassSandbox !=
          initialProfile.dangerouslyBypassSandbox ||
      draft.ephemeralSession != initialProfile.ephemeralSession;
}

String? _requiredError({
  required String value,
  required String message,
  required bool show,
}) {
  if (!show || value.trim().isNotEmpty) {
    return null;
  }

  return message;
}

String? _portError({required String value, required bool show}) {
  if (!show) {
    return null;
  }

  final port = int.tryParse(value.trim());
  if (port == null || port < 1 || port > 65535) {
    return 'Bad port';
  }

  return null;
}
