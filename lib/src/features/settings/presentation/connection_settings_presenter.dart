import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_draft.dart';

class ConnectionSettingsPresenter {
  const ConnectionSettingsPresenter();

  ConnectionSettingsContract present({
    required ConnectionProfile initialProfile,
    required ConnectionSecrets initialSecrets,
    required ConnectionSettingsFormState formState,
  }) {
    final draft = formState.draft;
    final hasChanges = _hasChanges(
      initialProfile: initialProfile,
      initialSecrets: initialSecrets,
      draft: draft,
    );
    final shouldShowValidationErrors =
        formState.showValidationErrors && hasChanges;
    final hasHostError = draft.host.trim().isEmpty;
    final port = int.tryParse(draft.port.trim());
    final hasPortError = port == null || port < 1 || port > 65535;
    final hasUsernameError = draft.username.trim().isEmpty;
    final hasWorkspaceDirError = draft.workspaceDir.trim().isEmpty;
    final hasCodexPathError = draft.codexPath.trim().isEmpty;
    final hasPasswordError =
        draft.authMode == AuthMode.password && draft.password.isEmpty;
    final hasPrivateKeyError =
        draft.authMode == AuthMode.privateKey &&
        draft.privateKeyPem.trim().isEmpty;

    final hostError = _requiredError(
      value: draft.host,
      message: 'Host is required',
      show: shouldShowValidationErrors,
    );
    final portError = _portError(
      value: draft.port,
      show: shouldShowValidationErrors,
    );
    final usernameError = _requiredError(
      value: draft.username,
      message: 'Username is required',
      show: shouldShowValidationErrors,
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
      show: shouldShowValidationErrors && draft.authMode == AuthMode.privateKey,
    );
    final hasValidationErrors =
        hasHostError ||
        hasPortError ||
        hasUsernameError ||
        hasWorkspaceDirError ||
        hasCodexPathError ||
        hasPasswordError ||
        hasPrivateKeyError;
    final canSubmit = !hasChanges || !hasValidationErrors;

    return ConnectionSettingsContract(
      title: 'Remote target',
      description:
          'This app runs Codex on your developer box over SSH and renders the JSON stream as mobile-friendly cards.',
      identitySection: ConnectionSettingsFieldSectionContract(
        title: 'Identity',
        fields: <ConnectionSettingsTextFieldContract>[
          ConnectionSettingsTextFieldContract(
            id: ConnectionSettingsFieldId.label,
            label: 'Profile label',
            value: draft.label,
          ),
          ConnectionSettingsTextFieldContract(
            id: ConnectionSettingsFieldId.host,
            label: 'Host',
            value: draft.host,
            hintText: 'devbox.local',
            errorText: hostError,
          ),
          ConnectionSettingsTextFieldContract(
            id: ConnectionSettingsFieldId.port,
            label: 'Port',
            value: draft.port,
            keyboardType: ConnectionSettingsKeyboardType.number,
            errorText: portError,
          ),
          ConnectionSettingsTextFieldContract(
            id: ConnectionSettingsFieldId.username,
            label: 'Username',
            value: draft.username,
            errorText: usernameError,
          ),
        ],
      ),
      remoteCodexSection: ConnectionSettingsFieldSectionContract(
        title: 'Remote Codex',
        fields: <ConnectionSettingsTextFieldContract>[
          ConnectionSettingsTextFieldContract(
            id: ConnectionSettingsFieldId.workspaceDir,
            label: 'Workspace directory',
            value: draft.workspaceDir,
            hintText: '/home/vince/Projects',
            errorText: workspaceDirError,
          ),
          ConnectionSettingsTextFieldContract(
            id: ConnectionSettingsFieldId.codexPath,
            label: 'Codex launch command',
            value: draft.codexPath,
            hintText: 'codex or just codex-mcp',
            helperText:
                'Command run inside the workspace before app-server args are appended. Pocket Relay uses your remote login shell when available.',
            errorText: codexPathError,
          ),
          ConnectionSettingsTextFieldContract(
            id: ConnectionSettingsFieldId.hostFingerprint,
            label: 'Host fingerprint (optional)',
            value: draft.hostFingerprint,
            hintText: 'aa:bb:cc:dd:...',
          ),
        ],
      ),
      authenticationSection: ConnectionSettingsAuthenticationSectionContract(
        title: 'Authentication',
        selectedMode: draft.authMode,
        options: const <ConnectionSettingsAuthOptionContract>[
          ConnectionSettingsAuthOptionContract(
            mode: AuthMode.password,
            label: 'Password',
            icon: ConnectionSettingsAuthOptionIcon.password,
          ),
          ConnectionSettingsAuthOptionContract(
            mode: AuthMode.privateKey,
            label: 'Private key',
            icon: ConnectionSettingsAuthOptionIcon.privateKey,
          ),
        ],
        fields: switch (draft.authMode) {
          AuthMode.password => <ConnectionSettingsTextFieldContract>[
            ConnectionSettingsTextFieldContract(
              id: ConnectionSettingsFieldId.password,
              label: 'SSH password',
              value: draft.password,
              obscureText: true,
              errorText: passwordError,
            ),
          ],
          AuthMode.privateKey => <ConnectionSettingsTextFieldContract>[
            ConnectionSettingsTextFieldContract(
              id: ConnectionSettingsFieldId.privateKeyPem,
              label: 'Private key PEM',
              value: draft.privateKeyPem,
              errorText: privateKeyError,
              minLines: 6,
              maxLines: 10,
              alignLabelWithHint: true,
            ),
            ConnectionSettingsTextFieldContract(
              id: ConnectionSettingsFieldId.privateKeyPassphrase,
              label: 'Key passphrase (optional)',
              value: draft.privateKeyPassphrase,
              obscureText: true,
            ),
          ],
        },
      ),
      runModeSection: ConnectionSettingsRunModeSectionContract(
        title: 'Run mode',
        toggles: <ConnectionSettingsToggleContract>[
          ConnectionSettingsToggleContract(
            id: ConnectionSettingsToggleId.skipGitRepoCheck,
            title: 'Skip Codex repo trust check',
            subtitle:
                'Useful when you point Codex at arbitrary workspaces on the remote box.',
            value: draft.skipGitRepoCheck,
          ),
          ConnectionSettingsToggleContract(
            id: ConnectionSettingsToggleId.dangerouslyBypassSandbox,
            title: 'Dangerous full access',
            subtitle:
                'Turns off the safer full-auto sandbox and gives Codex direct unsandboxed execution on the remote box.',
            value: draft.dangerouslyBypassSandbox,
          ),
          ConnectionSettingsToggleContract(
            id: ConnectionSettingsToggleId.ephemeralSession,
            title: 'Ephemeral turns',
            subtitle:
                'Do not keep remote Codex session history between prompts.',
            value: draft.ephemeralSession,
          ),
        ],
      ),
      saveAction: ConnectionSettingsSaveActionContract(
        label: 'Save',
        hasChanges: hasChanges,
        requiresValidation: hasChanges,
        canSubmit: canSubmit,
        submitPayload: !canSubmit || port == null
            ? null
            : ConnectionSettingsSubmitPayload(
                profile: initialProfile.copyWith(
                  label: _normalizedLabel(draft.label),
                  host: draft.host.trim(),
                  port: port,
                  username: draft.username.trim(),
                  workspaceDir: draft.workspaceDir.trim(),
                  codexPath: draft.codexPath.trim(),
                  authMode: draft.authMode,
                  hostFingerprint: draft.hostFingerprint.trim(),
                  skipGitRepoCheck: draft.skipGitRepoCheck,
                  dangerouslyBypassSandbox: draft.dangerouslyBypassSandbox,
                  ephemeralSession: draft.ephemeralSession,
                ),
                secrets: initialSecrets.copyWith(
                  password: draft.password,
                  privateKeyPem: draft.privateKeyPem,
                  privateKeyPassphrase: draft.privateKeyPassphrase,
                ),
              ),
      ),
    );
  }

  bool _hasChanges({
    required ConnectionProfile initialProfile,
    required ConnectionSecrets initialSecrets,
    required ConnectionSettingsDraft draft,
  }) {
    return draft.label.trim() != initialProfile.label ||
        draft.host.trim() != initialProfile.host ||
        draft.port.trim() != initialProfile.port.toString() ||
        draft.username.trim() != initialProfile.username ||
        draft.workspaceDir.trim() != initialProfile.workspaceDir ||
        draft.codexPath.trim() != initialProfile.codexPath ||
        draft.hostFingerprint.trim() != initialProfile.hostFingerprint ||
        draft.password != initialSecrets.password ||
        draft.privateKeyPem != initialSecrets.privateKeyPem ||
        draft.privateKeyPassphrase != initialSecrets.privateKeyPassphrase ||
        draft.authMode != initialProfile.authMode ||
        draft.skipGitRepoCheck != initialProfile.skipGitRepoCheck ||
        draft.dangerouslyBypassSandbox !=
            initialProfile.dangerouslyBypassSandbox ||
        draft.ephemeralSession != initialProfile.ephemeralSession;
  }

  String _normalizedLabel(String label) {
    final trimmed = label.trim();
    return trimmed.isEmpty ? 'Developer Box' : trimmed;
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
}
