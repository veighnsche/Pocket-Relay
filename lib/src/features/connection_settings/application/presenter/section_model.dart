part of '../connection_settings_presenter.dart';

ConnectionSettingsModelSectionContract _buildModelSection(
  _ConnectionSettingsPresentationState state,
) {
  final draft = state.draft;
  final availableModelCatalog = state.availableModelCatalog;
  if (!state.agentAdapterCapabilities.supportsModelCatalog) {
    return _buildUnsupportedModelSection(
      state: state,
      selectedModelId: _selectedModelIdForDraft(draft),
      selectedReasoningEffort: draft.reasoningEffort,
    );
  }
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

  final selectedCatalogModel = modelCatalogModelForModel(
    availableModelCatalog,
    selectedModelId,
  );
  final selectedVisibleCatalogModel = visibleModelCatalogModelForModel(
    availableModelCatalog,
    selectedModelId,
  );
  final hasUnknownModel =
      selectedModelId != null && selectedVisibleCatalogModel == null;
  final effectiveCatalogModel = effectiveModelCatalogModelForModel(
    availableModelCatalog,
    selectedModelId,
  );
  final selectedReasoningEffort = normalizedReasoningEffortForModel(
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
            ? selectedModelId
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
  final hasSelectedReasoningEffortOption = switch (selectedReasoningEffort) {
    null => true,
    final selectedEffort => reasoningEffortOptions.any(
      (option) => option.effort == selectedEffort,
    ),
  };
  if (!hasSelectedReasoningEffortOption) {
    final selectedEffort = selectedReasoningEffort!;
    reasoningEffortOptions.insert(
      1,
      ConnectionSettingsReasoningEffortOptionContract(
        effort: selectedEffort,
        label: _reasoningEffortLabel(selectedEffort),
        description:
            'Saved reasoning effort outside the available backend options.',
      ),
    );
  }
  final reasoningEffortHelperText = !hasSelectedReasoningEffortOption
      ? 'Saved reasoning effort outside the available backend options.'
      : selectedCatalogModel != null
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

ConnectionSettingsModelSectionContract _buildUnsupportedModelSection({
  required _ConnectionSettingsPresentationState state,
  required String? selectedModelId,
  required AgentAdapterReasoningEffort? selectedReasoningEffort,
}) {
  final supportsReasoningEffort =
      state.agentAdapterCapabilities.supportsReasoningEffort;
  final reasoningOptions =
      supportsReasoningEffort && selectedReasoningEffort != null
      ? <ConnectionSettingsReasoningEffortOptionContract>[
          ConnectionSettingsReasoningEffortOptionContract(
            effort: selectedReasoningEffort,
            label: _reasoningEffortLabel(selectedReasoningEffort),
            description:
                'Saved reasoning effort. This agent adapter does not expose model metadata yet.',
          ),
        ]
      : <ConnectionSettingsReasoningEffortOptionContract>[
          ConnectionSettingsReasoningEffortOptionContract(
            effort: null,
            label: 'Unavailable',
            description:
                supportsReasoningEffort
                ? 'No reasoning effort is currently saved for this workspace.'
                : 'This agent adapter does not expose model or reasoning metadata.',
          ),
        ];

  return ConnectionSettingsModelSectionContract(
    title: 'Model defaults',
    selectedModelId: selectedModelId,
    modelOptions: selectedModelId == null
        ? const <ConnectionSettingsModelOptionContract>[
            ConnectionSettingsModelOptionContract(
              modelId: null,
              label: 'Unavailable',
              description:
                  'This agent adapter does not expose model catalog metadata.',
            ),
          ]
        : <ConnectionSettingsModelOptionContract>[
            ConnectionSettingsModelOptionContract(
              modelId: selectedModelId,
              label: selectedModelId,
              description:
                  'Saved model value. This agent adapter does not expose model catalog metadata.',
            ),
          ],
    modelHelperText:
        'This agent adapter does not expose model catalog metadata.',
    isModelEnabled: false,
    selectedReasoningEffort: supportsReasoningEffort
        ? selectedReasoningEffort
        : null,
    reasoningEffortOptions: reasoningOptions,
    reasoningEffortHelperText: supportsReasoningEffort
        ? 'This agent adapter does not expose model metadata, so Pocket Relay can only show the saved reasoning value.'
        : 'This agent adapter does not expose reasoning controls.',
    isReasoningEffortEnabled: false,
    refreshActionLabel: state.isRefreshingModelCatalog
        ? 'Refreshing models...'
        : 'Refresh models',
    refreshActionHelperText:
        'This agent adapter does not expose model catalog refresh.',
    isRefreshActionEnabled: false,
    isRefreshActionInProgress: false,
  );
}

String? _selectedModelIdForDraft(ConnectionSettingsDraft draft) {
  final normalized = draft.model.trim();
  return normalized.isEmpty ? null : normalized;
}

String _reasoningEffortLabel(AgentAdapterReasoningEffort effort) {
  return switch (effort) {
    AgentAdapterReasoningEffort.none => 'None',
    AgentAdapterReasoningEffort.minimal => 'Minimal',
    AgentAdapterReasoningEffort.low => 'Low',
    AgentAdapterReasoningEffort.medium => 'Medium',
    AgentAdapterReasoningEffort.high => 'High',
    AgentAdapterReasoningEffort.xhigh => 'XHigh',
  };
}

String _reasoningEffortDescription(AgentAdapterReasoningEffort effort) {
  return switch (effort) {
    AgentAdapterReasoningEffort.none =>
      'Disable extra reasoning where supported.',
    AgentAdapterReasoningEffort.minimal => 'Use the lightest reasoning pass.',
    AgentAdapterReasoningEffort.low => 'Favor speed over deeper planning.',
    AgentAdapterReasoningEffort.medium => 'Balanced default for general work.',
    AgentAdapterReasoningEffort.high => 'Spend more reasoning on harder tasks.',
    AgentAdapterReasoningEffort.xhigh =>
      'Maximum reasoning depth when supported.',
  };
}

String _catalogModelLabel(ConnectionAvailableModel model) {
  final displayName = model.displayName.trim();
  return displayName.isEmpty ? model.model : displayName;
}

ConnectionSettingsModelSectionContract _buildUnavailableModelSection({
  required _ConnectionSettingsPresentationState state,
  required String? selectedModelId,
  required AgentAdapterReasoningEffort? selectedReasoningEffort,
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
