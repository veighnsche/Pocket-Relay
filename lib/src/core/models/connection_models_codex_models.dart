part of 'connection_models.dart';

// Reference snapshot sourced from .reference/codex/codex-rs/core/models.json.
// Keep this app-owned copy narrow to the visible picker models so the settings
// surface can mirror the reference frontend without re-implementing the TUI.
class CodexReferenceModel {
  const CodexReferenceModel({
    required this.id,
    required this.label,
    required this.description,
    required this.defaultReasoningEffort,
    required this.supportedReasoningEfforts,
  });

  final String id;
  final String label;
  final String description;
  final CodexReasoningEffort defaultReasoningEffort;
  final List<CodexReasoningEffort> supportedReasoningEfforts;
}

const List<CodexReferenceModel>
codexReferenceVisibleModels = <CodexReferenceModel>[
  CodexReferenceModel(
    id: 'gpt-5.3-codex',
    label: 'gpt-5.3-codex',
    description: 'Latest frontier agentic coding model.',
    defaultReasoningEffort: CodexReasoningEffort.medium,
    supportedReasoningEfforts: <CodexReasoningEffort>[
      CodexReasoningEffort.low,
      CodexReasoningEffort.medium,
      CodexReasoningEffort.high,
      CodexReasoningEffort.xhigh,
    ],
  ),
  CodexReferenceModel(
    id: 'gpt-5.4',
    label: 'gpt-5.4',
    description: 'Latest frontier agentic coding model.',
    defaultReasoningEffort: CodexReasoningEffort.medium,
    supportedReasoningEfforts: <CodexReasoningEffort>[
      CodexReasoningEffort.low,
      CodexReasoningEffort.medium,
      CodexReasoningEffort.high,
      CodexReasoningEffort.xhigh,
    ],
  ),
  CodexReferenceModel(
    id: 'gpt-5.2-codex',
    label: 'gpt-5.2-codex',
    description: 'Frontier agentic coding model.',
    defaultReasoningEffort: CodexReasoningEffort.medium,
    supportedReasoningEfforts: <CodexReasoningEffort>[
      CodexReasoningEffort.low,
      CodexReasoningEffort.medium,
      CodexReasoningEffort.high,
      CodexReasoningEffort.xhigh,
    ],
  ),
  CodexReferenceModel(
    id: 'gpt-5.1-codex-max',
    label: 'gpt-5.1-codex-max',
    description: 'Codex-optimized flagship for deep and fast reasoning.',
    defaultReasoningEffort: CodexReasoningEffort.medium,
    supportedReasoningEfforts: <CodexReasoningEffort>[
      CodexReasoningEffort.low,
      CodexReasoningEffort.medium,
      CodexReasoningEffort.high,
      CodexReasoningEffort.xhigh,
    ],
  ),
  CodexReferenceModel(
    id: 'gpt-5.2',
    label: 'gpt-5.2',
    description:
        'Latest frontier model with improvements across knowledge, reasoning and coding',
    defaultReasoningEffort: CodexReasoningEffort.medium,
    supportedReasoningEfforts: <CodexReasoningEffort>[
      CodexReasoningEffort.low,
      CodexReasoningEffort.medium,
      CodexReasoningEffort.high,
      CodexReasoningEffort.xhigh,
    ],
  ),
  CodexReferenceModel(
    id: 'gpt-5.1-codex-mini',
    label: 'gpt-5.1-codex-mini',
    description: 'Optimized for codex. Cheaper, faster, but less capable.',
    defaultReasoningEffort: CodexReasoningEffort.medium,
    supportedReasoningEfforts: <CodexReasoningEffort>[
      CodexReasoningEffort.medium,
      CodexReasoningEffort.high,
    ],
  ),
];

CodexReferenceModel get codexDefaultReferenceModel =>
    codexReferenceVisibleModels.first;

ConnectionModelCatalog codexReferenceModelCatalog({
  String connectionId = 'reference',
  DateTime? fetchedAt,
}) {
  return ConnectionModelCatalog(
    connectionId: connectionId,
    fetchedAt:
        fetchedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    models: <ConnectionAvailableModel>[
      for (final model in codexReferenceVisibleModels)
        ConnectionAvailableModel(
          id: model.id,
          model: model.id,
          displayName: model.label,
          description: model.description,
          hidden: false,
          supportedReasoningEfforts:
              model.supportedReasoningEfforts
                  .map(
                    (effort) => ConnectionAvailableModelReasoningEffortOption(
                      reasoningEffort: effort,
                      description: '',
                    ),
                  )
                  .toList(growable: false),
          defaultReasoningEffort: model.defaultReasoningEffort,
          inputModalities: const <String>[],
          supportsPersonality: false,
          isDefault: model.id == codexDefaultReferenceModel.id,
        ),
    ],
  );
}

ConnectionAvailableModel? codexCatalogModelForModel(
  ConnectionModelCatalog? availableModelCatalog,
  String? modelId, {
  bool includeHidden = true,
}) {
  final normalized = modelId?.trim();
  if (availableModelCatalog == null ||
      normalized == null ||
      normalized.isEmpty) {
    return null;
  }

  for (final model in availableModelCatalog.models) {
    if (!includeHidden && model.hidden) {
      continue;
    }
    if (model.model == normalized) {
      return model;
    }
  }

  return null;
}

ConnectionAvailableModel? codexVisibleCatalogModelForModel(
  ConnectionModelCatalog? availableModelCatalog,
  String? modelId,
) {
  return codexCatalogModelForModel(
    availableModelCatalog,
    modelId,
    includeHidden: false,
  );
}

ConnectionAvailableModel? codexDefaultCatalogModel(
  ConnectionModelCatalog? availableModelCatalog,
) {
  if (availableModelCatalog == null) {
    return null;
  }

  final defaultModel = availableModelCatalog.defaultModel;
  if (defaultModel != null) {
    return defaultModel;
  }

  final visibleModels = availableModelCatalog.visibleModels;
  if (visibleModels.isNotEmpty) {
    return visibleModels.first;
  }

  final models = availableModelCatalog.models;
  if (models.isNotEmpty) {
    return models.first;
  }

  return null;
}

ConnectionAvailableModel? codexEffectiveCatalogModelForModel(
  ConnectionModelCatalog? availableModelCatalog,
  String? modelId,
) {
  return codexCatalogModelForModel(availableModelCatalog, modelId) ??
      codexDefaultCatalogModel(availableModelCatalog);
}

CodexReasoningEffort? codexNormalizedReasoningEffortForModel(
  String? modelId,
  CodexReasoningEffort? effort, {
  ConnectionModelCatalog? availableModelCatalog,
}) {
  if (effort == null) {
    return null;
  }

  final availableModel = codexEffectiveCatalogModelForModel(
    availableModelCatalog,
    modelId,
  );
  if (availableModel != null) {
    for (final option in availableModel.supportedReasoningEfforts) {
      if (option.reasoningEffort == effort) {
        return effort;
      }
    }

    return availableModel.defaultReasoningEffort;
  }
  return effort;
}
