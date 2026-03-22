part of 'connection_settings_presenter.dart';

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
    title: 'Route',
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
  _ConnectionSettingsPresentationState state,
) {
  if (!state.isRemote) {
    return null;
  }

  final draft = state.draft;
  return ConnectionSettingsSectionContract(
    title: 'Remote target',
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
        label: 'Host fingerprint (optional)',
        value: draft.hostFingerprint,
        hintText: 'aa:bb:cc:dd:...',
      ),
    ],
  );
}

ConnectionSettingsAuthenticationSectionContract? _buildAuthenticationSection(
  _ConnectionSettingsPresentationState state,
) {
  if (!state.isRemote) {
    return null;
  }

  final draft = state.draft;
  return ConnectionSettingsAuthenticationSectionContract(
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
          errorText: state.passwordError,
        ),
      ],
      AuthMode.privateKey => <ConnectionSettingsTextFieldContract>[
        ConnectionSettingsTextFieldContract(
          id: ConnectionSettingsFieldId.privateKeyPem,
          label: 'Private key PEM',
          value: draft.privateKeyPem,
          errorText: state.privateKeyError,
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
  );
}

ConnectionSettingsSectionContract _buildCodexSection(
  _ConnectionSettingsPresentationState state,
) {
  final draft = state.draft;
  return ConnectionSettingsSectionContract(
    title: state.isRemote ? 'Remote Codex' : 'Local Codex',
    fields: <ConnectionSettingsTextFieldContract>[
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.workspaceDir,
        label: 'Workspace directory',
        value: draft.workspaceDir,
        hintText: '/path/to/workspace',
        errorText: state.workspaceDirError,
      ),
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.codexPath,
        label: 'Codex launch command',
        value: draft.codexPath,
        hintText: 'codex or just codex-mcp',
        helperText: state.isRemote
            ? 'Command run on the remote machine inside the workspace before app-server args are appended.'
            : 'Command run on this desktop inside the workspace before app-server args are appended.',
        errorText: state.codexPathError,
      ),
    ],
  );
}

ConnectionSettingsModelSectionContract _buildModelSection(
  _ConnectionSettingsPresentationState state,
) {
  final draft = state.draft;
  final availableModelCatalog = state.availableModelCatalog;
  final refreshActionLabel = state.isRefreshingModelCatalog
      ? 'Refreshing models...'
      : 'Refresh models';
  final isRefreshActionEnabled =
      state.supportsModelCatalogRefresh &&
      draft.workspaceDir.trim().isNotEmpty &&
      !state.isRefreshingModelCatalog;
  final refreshActionHelperText = _refreshActionHelperText(state);
  final selectedModelId = _selectedModelIdForDraft(draft);
  if (availableModelCatalog == null) {
    return _buildUnavailableModelSection(
      state: state,
      selectedModelId: selectedModelId,
      selectedReasoningEffort: draft.reasoningEffort,
    );
  }

  final selectedCatalogModel = codexCatalogModelForModel(
    availableModelCatalog,
    selectedModelId,
  );
  final selectedVisibleCatalogModel = codexVisibleCatalogModelForModel(
    availableModelCatalog,
    selectedModelId,
  );
  final hasUnknownModel =
      selectedModelId != null && selectedVisibleCatalogModel == null;
  final effectiveCatalogModel = codexEffectiveCatalogModelForModel(
    availableModelCatalog,
    selectedModelId,
  );
  final selectedReasoningEffort = codexNormalizedReasoningEffortForModel(
    selectedModelId,
    draft.reasoningEffort,
    availableModelCatalog: availableModelCatalog,
  );
  final modelOptions = <ConnectionSettingsModelOptionContract>[
    const ConnectionSettingsModelOptionContract(
      modelId: null,
      label: 'Default',
      description: 'Use the default model from the backend catalog.',
    ),
    if (hasUnknownModel)
      ConnectionSettingsModelOptionContract(
        modelId: selectedModelId,
        label: selectedCatalogModel == null
            ? selectedModelId!
            : _catalogModelLabel(selectedCatalogModel),
        description: 'Saved model outside the available picker list.',
      ),
    ...availableModelCatalog.visibleModels.map(
      (model) => ConnectionSettingsModelOptionContract(
        modelId: model.model,
        label: _catalogModelLabel(model),
        description: model.description,
      ),
    ),
  ];
  final modelHelperText = hasUnknownModel
      ? 'Saved model outside the available picker list.'
      : selectedCatalogModel == null
      ? 'Available models come from the backend catalog. Leave blank to use the backend default model.'
      : selectedCatalogModel.description;
  final reasoningEffortOptions =
      <ConnectionSettingsReasoningEffortOptionContract>[
        const ConnectionSettingsReasoningEffortOptionContract(
          effort: null,
          label: 'Default',
          description: 'Use the selected model default effort.',
        ),
        ...?effectiveCatalogModel?.supportedReasoningEfforts.map(
          (option) => ConnectionSettingsReasoningEffortOptionContract(
            effort: option.reasoningEffort,
            label: _reasoningEffortLabel(option.reasoningEffort),
            description: option.description.trim().isEmpty
                ? _reasoningEffortDescription(option.reasoningEffort)
                : option.description,
          ),
        ),
      ];
  final reasoningEffortHelperText = selectedCatalogModel != null
      ? 'Available efforts follow ${_catalogModelLabel(selectedCatalogModel)}.'
      : effectiveCatalogModel == null
      ? 'Available efforts follow the backend default model.'
      : 'Available efforts follow ${_catalogModelLabel(effectiveCatalogModel)}.';
  return ConnectionSettingsModelSectionContract(
    title: 'Model defaults',
    selectedModelId: selectedModelId,
    modelOptions: modelOptions,
    modelHelperText: modelHelperText,
    isModelEnabled: true,
    selectedReasoningEffort: selectedReasoningEffort,
    reasoningEffortOptions: reasoningEffortOptions,
    reasoningEffortHelperText: reasoningEffortHelperText,
    isReasoningEffortEnabled: true,
    refreshActionLabel: refreshActionLabel,
    refreshActionHelperText: refreshActionHelperText,
    isRefreshActionEnabled: isRefreshActionEnabled,
    isRefreshActionInProgress: state.isRefreshingModelCatalog,
  );
}

String? _selectedModelIdForDraft(ConnectionSettingsDraft draft) {
  final normalized = draft.model.trim();
  return normalized.isEmpty ? null : normalized;
}

String _reasoningEffortLabel(CodexReasoningEffort effort) {
  return switch (effort) {
    CodexReasoningEffort.none => 'None',
    CodexReasoningEffort.minimal => 'Minimal',
    CodexReasoningEffort.low => 'Low',
    CodexReasoningEffort.medium => 'Medium',
    CodexReasoningEffort.high => 'High',
    CodexReasoningEffort.xhigh => 'XHigh',
  };
}

String _reasoningEffortDescription(CodexReasoningEffort effort) {
  return switch (effort) {
    CodexReasoningEffort.none => 'Disable extra reasoning where supported.',
    CodexReasoningEffort.minimal => 'Use the lightest reasoning pass.',
    CodexReasoningEffort.low => 'Favor speed over deeper planning.',
    CodexReasoningEffort.medium => 'Balanced default for general work.',
    CodexReasoningEffort.high => 'Spend more reasoning on harder tasks.',
    CodexReasoningEffort.xhigh => 'Maximum reasoning depth when supported.',
  };
}

ConnectionSettingsSubmitPayload _buildSubmitPayload({
  required ConnectionProfile initialProfile,
  required ConnectionSecrets initialSecrets,
  required _ConnectionSettingsPresentationState state,
}) {
  final draft = state.draft;
  final presenter = const ConnectionSettingsPresenter();
  return ConnectionSettingsSubmitPayload(
    profile: initialProfile.copyWith(
      label: presenter._normalizedLabel(draft.label),
      connectionMode: draft.connectionMode,
      host: draft.host.trim(),
      port: state.port ?? initialProfile.port,
      username: draft.username.trim(),
      workspaceDir: draft.workspaceDir.trim(),
      codexPath: draft.codexPath.trim(),
      model: _selectedModelIdForDraft(draft) ?? '',
      reasoningEffort: codexNormalizedReasoningEffortForModel(
        _selectedModelIdForDraft(draft),
        draft.reasoningEffort,
        availableModelCatalog: state.availableModelCatalog,
      ),
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
  );
}

String _catalogModelLabel(ConnectionAvailableModel model) {
  final displayName = model.displayName.trim();
  return displayName.isEmpty ? model.model : displayName;
}

ConnectionSettingsModelSectionContract _buildUnavailableModelSection({
  required _ConnectionSettingsPresentationState state,
  required String? selectedModelId,
  required CodexReasoningEffort? selectedReasoningEffort,
}) {
  final hasSavedModel = selectedModelId != null;
  final hasSavedReasoningEffort = selectedReasoningEffort != null;

  return ConnectionSettingsModelSectionContract(
    title: 'Model defaults',
    selectedModelId: selectedModelId,
    modelOptions: hasSavedModel
        ? <ConnectionSettingsModelOptionContract>[
            ConnectionSettingsModelOptionContract(
              modelId: selectedModelId,
              label: selectedModelId,
              description:
                  'Saved model value. Use Refresh models after the first successful backend connection to update the available list.',
            ),
          ]
        : const <ConnectionSettingsModelOptionContract>[
            ConnectionSettingsModelOptionContract(
              modelId: null,
              label: 'Unavailable',
              description:
                  'Use Refresh models after the first successful backend connection to load available models from the backend.',
            ),
          ],
    modelHelperText: hasSavedModel
        ? 'Use Refresh models after the first successful backend connection to update available models. Showing the saved model value only.'
        : 'Use Refresh models after the first successful backend connection to load available models.',
    isModelEnabled: false,
    selectedReasoningEffort: selectedReasoningEffort,
    reasoningEffortOptions: hasSavedReasoningEffort
        ? <ConnectionSettingsReasoningEffortOptionContract>[
            ConnectionSettingsReasoningEffortOptionContract(
              effort: selectedReasoningEffort,
              label: _reasoningEffortLabel(selectedReasoningEffort),
              description:
                  'Saved reasoning effort. Use Refresh models after the first successful backend connection to update supported options.',
            ),
          ]
        : const <ConnectionSettingsReasoningEffortOptionContract>[
            ConnectionSettingsReasoningEffortOptionContract(
              effort: null,
              label: 'Unavailable',
              description:
                  'Use Refresh models after the first successful backend connection to load supported reasoning efforts from the backend.',
            ),
          ],
    reasoningEffortHelperText: hasSavedReasoningEffort
        ? 'Use Refresh models after the first successful backend connection to update supported reasoning efforts. Showing the saved effort only.'
        : 'Use Refresh models after the first successful backend connection to load supported reasoning efforts.',
    isReasoningEffortEnabled: false,
    refreshActionLabel: state.isRefreshingModelCatalog
        ? 'Refreshing models...'
        : 'Refresh models',
    refreshActionHelperText: _refreshActionHelperText(state),
    isRefreshActionEnabled:
        state.supportsModelCatalogRefresh &&
        state.draft.workspaceDir.trim().isNotEmpty &&
        !state.isRefreshingModelCatalog,
    isRefreshActionInProgress: state.isRefreshingModelCatalog,
  );
}

String _refreshActionHelperText(_ConnectionSettingsPresentationState state) {
  if (state.isRefreshingModelCatalog) {
    return 'Refreshing available models from the backend.';
  }

  if (state.draft.workspaceDir.trim().isEmpty) {
    return 'Set a workspace directory to enable model refresh.';
  }

  if (!state.supportsModelCatalogRefresh) {
    return 'Model refresh is available when this settings sheet is opened from a live backend connection.';
  }

  return 'Refresh available models and reasoning efforts from the backend.';
}
