import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';

class ConnectionSettingsPresenter {
  const ConnectionSettingsPresenter();

  ConnectionSettingsContract present({
    required ConnectionProfile initialProfile,
    required ConnectionSecrets initialSecrets,
    required ConnectionSettingsFormState formState,
    bool supportsLocalConnectionMode = false,
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
    final modelHelperText = draft.model.trim().isEmpty
        ? 'Leave blank to use the Codex or workspace default.'
        : 'Sent to Codex when the session starts and when each turn starts.';

    final hasHostError = isRemote && draft.host.trim().isEmpty;
    final port = int.tryParse(draft.port.trim());
    final hasPortError = isRemote && (port == null || port < 1 || port > 65535);
    final hasUsernameError = isRemote && draft.username.trim().isEmpty;
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
        hasWorkspaceDirError ||
        hasCodexPathError ||
        hasPasswordError ||
        hasPrivateKeyError;
    final canSubmit = !hasChanges || !hasValidationErrors;

    return ConnectionSettingsContract(
      title: 'Connection',
      description: _descriptionFor(
        connectionMode: draft.connectionMode,
        supportsLocalConnectionMode: supportsLocalConnectionMode,
      ),
      profileSection: ConnectionSettingsSectionContract(
        title: 'Profile',
        fields: <ConnectionSettingsTextFieldContract>[
          ConnectionSettingsTextFieldContract(
            id: ConnectionSettingsFieldId.label,
            label: 'Profile label',
            value: draft.label,
          ),
        ],
      ),
      connectionModeSection: supportsLocalConnectionMode
          ? ConnectionSettingsConnectionModeSectionContract(
              title: 'Route',
              selectedMode: draft.connectionMode,
              options: const <ConnectionSettingsConnectionModeOptionContract>[
                ConnectionSettingsConnectionModeOptionContract(
                  mode: ConnectionMode.remote,
                  label: 'Remote',
                  description:
                      'Connect to a developer box over SSH and run Codex there.',
                ),
                ConnectionSettingsConnectionModeOptionContract(
                  mode: ConnectionMode.local,
                  label: 'Local',
                  description:
                      'Run Codex app-server on this desktop and keep the workspace here.',
                ),
              ],
            )
          : null,
      remoteConnectionSection: isRemote
          ? ConnectionSettingsSectionContract(
              title: 'Remote target',
              fields: <ConnectionSettingsTextFieldContract>[
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
                ConnectionSettingsTextFieldContract(
                  id: ConnectionSettingsFieldId.hostFingerprint,
                  label: 'Host fingerprint (optional)',
                  value: draft.hostFingerprint,
                  hintText: 'aa:bb:cc:dd:...',
                ),
              ],
            )
          : null,
      authenticationSection: isRemote
          ? ConnectionSettingsAuthenticationSectionContract(
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
            )
          : null,
      codexSection: ConnectionSettingsSectionContract(
        title: isRemote ? 'Remote Codex' : 'Local Codex',
        fields: <ConnectionSettingsTextFieldContract>[
          ConnectionSettingsTextFieldContract(
            id: ConnectionSettingsFieldId.workspaceDir,
            label: 'Workspace directory',
            value: draft.workspaceDir,
            hintText: '/path/to/workspace',
            errorText: workspaceDirError,
          ),
          ConnectionSettingsTextFieldContract(
            id: ConnectionSettingsFieldId.codexPath,
            label: 'Codex launch command',
            value: draft.codexPath,
            hintText: 'codex or just codex-mcp',
            helperText: isRemote
                ? 'Command run on the remote machine inside the workspace before app-server args are appended.'
                : 'Command run on this desktop inside the workspace before app-server args are appended.',
            errorText: codexPathError,
          ),
        ],
      ),
      modelSection: ConnectionSettingsModelSectionContract(
        title: 'Model defaults',
        fields: <ConnectionSettingsTextFieldContract>[
          ConnectionSettingsTextFieldContract(
            id: ConnectionSettingsFieldId.model,
            label: 'Model override (optional)',
            value: draft.model,
            hintText: 'gpt-5.4 or gpt-5.4-mini',
            helperText: modelHelperText,
          ),
        ],
        selectedReasoningEffort: draft.reasoningEffort,
        reasoningEffortOptions:
            const <ConnectionSettingsReasoningEffortOptionContract>[
              ConnectionSettingsReasoningEffortOptionContract(
                effort: null,
                label: 'Default',
                description: 'Use the model or workspace default effort.',
              ),
              ConnectionSettingsReasoningEffortOptionContract(
                effort: CodexReasoningEffort.none,
                label: 'None',
                description: 'Disable extra reasoning where supported.',
              ),
              ConnectionSettingsReasoningEffortOptionContract(
                effort: CodexReasoningEffort.minimal,
                label: 'Minimal',
                description: 'Use the lightest reasoning pass.',
              ),
              ConnectionSettingsReasoningEffortOptionContract(
                effort: CodexReasoningEffort.low,
                label: 'Low',
                description: 'Favor speed over deeper planning.',
              ),
              ConnectionSettingsReasoningEffortOptionContract(
                effort: CodexReasoningEffort.medium,
                label: 'Medium',
                description: 'Balanced default for general work.',
              ),
              ConnectionSettingsReasoningEffortOptionContract(
                effort: CodexReasoningEffort.high,
                label: 'High',
                description: 'Spend more reasoning on harder tasks.',
              ),
              ConnectionSettingsReasoningEffortOptionContract(
                effort: CodexReasoningEffort.xhigh,
                label: 'XHigh',
                description: 'Maximum reasoning depth when supported.',
              ),
            ],
      ),
      runModeSection: ConnectionSettingsRunModeSectionContract(
        title: 'Run mode',
        toggles: <ConnectionSettingsToggleContract>[
          ConnectionSettingsToggleContract(
            id: ConnectionSettingsToggleId.dangerouslyBypassSandbox,
            title: 'Dangerous full access',
            subtitle:
                'Turns off the safer auto sandbox and gives Codex direct unsandboxed execution for this connection.',
            value: draft.dangerouslyBypassSandbox,
          ),
          ConnectionSettingsToggleContract(
            id: ConnectionSettingsToggleId.ephemeralSession,
            title: 'Ephemeral turns',
            subtitle: 'Do not keep Codex session history between prompts.',
            value: draft.ephemeralSession,
          ),
        ],
      ),
      saveAction: ConnectionSettingsSaveActionContract(
        label: 'Save',
        hasChanges: hasChanges,
        requiresValidation: hasChanges,
        canSubmit: canSubmit,
        submitPayload: !canSubmit
            ? null
            : ConnectionSettingsSubmitPayload(
                profile: initialProfile.copyWith(
                  label: _normalizedLabel(draft.label),
                  connectionMode: draft.connectionMode,
                  host: draft.host.trim(),
                  port: port ?? initialProfile.port,
                  username: draft.username.trim(),
                  workspaceDir: draft.workspaceDir.trim(),
                  codexPath: draft.codexPath.trim(),
                  model: draft.model.trim(),
                  reasoningEffort: draft.reasoningEffort,
                  authMode: draft.authMode,
                  hostFingerprint: draft.hostFingerprint.trim(),
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

  String _descriptionFor({
    required ConnectionMode connectionMode,
    required bool supportsLocalConnectionMode,
  }) {
    if (!supportsLocalConnectionMode) {
      return 'Connect to a remote developer box over SSH and keep the Codex session readable on a smaller screen.';
    }

    return switch (connectionMode) {
      ConnectionMode.remote =>
        'Choose whether this desktop should reach Codex on a remote box or run it locally. Remote mode uses SSH and keeps the workspace on your developer box.',
      ConnectionMode.local =>
        'Choose whether this desktop should reach Codex on a remote box or run it locally. Local mode starts Codex app-server on this machine inside the selected workspace.',
    };
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
