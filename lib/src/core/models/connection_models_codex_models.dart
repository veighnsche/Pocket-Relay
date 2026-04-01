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
  final AgentAdapterReasoningEffort defaultReasoningEffort;
  final List<AgentAdapterReasoningEffort> supportedReasoningEfforts;
}

const List<CodexReferenceModel>
codexReferenceVisibleModels = <CodexReferenceModel>[
  CodexReferenceModel(
    id: 'gpt-5.3-codex',
    label: 'gpt-5.3-codex',
    description: 'Latest frontier agentic coding model.',
    defaultReasoningEffort: AgentAdapterReasoningEffort.medium,
    supportedReasoningEfforts: <AgentAdapterReasoningEffort>[
      AgentAdapterReasoningEffort.low,
      AgentAdapterReasoningEffort.medium,
      AgentAdapterReasoningEffort.high,
      AgentAdapterReasoningEffort.xhigh,
    ],
  ),
  CodexReferenceModel(
    id: 'gpt-5.4',
    label: 'gpt-5.4',
    description: 'Latest frontier agentic coding model.',
    defaultReasoningEffort: AgentAdapterReasoningEffort.medium,
    supportedReasoningEfforts: <AgentAdapterReasoningEffort>[
      AgentAdapterReasoningEffort.low,
      AgentAdapterReasoningEffort.medium,
      AgentAdapterReasoningEffort.high,
      AgentAdapterReasoningEffort.xhigh,
    ],
  ),
  CodexReferenceModel(
    id: 'gpt-5.2-codex',
    label: 'gpt-5.2-codex',
    description: 'Frontier agentic coding model.',
    defaultReasoningEffort: AgentAdapterReasoningEffort.medium,
    supportedReasoningEfforts: <AgentAdapterReasoningEffort>[
      AgentAdapterReasoningEffort.low,
      AgentAdapterReasoningEffort.medium,
      AgentAdapterReasoningEffort.high,
      AgentAdapterReasoningEffort.xhigh,
    ],
  ),
  CodexReferenceModel(
    id: 'gpt-5.1-codex-max',
    label: 'gpt-5.1-codex-max',
    description: 'Codex-optimized flagship for deep and fast reasoning.',
    defaultReasoningEffort: AgentAdapterReasoningEffort.medium,
    supportedReasoningEfforts: <AgentAdapterReasoningEffort>[
      AgentAdapterReasoningEffort.low,
      AgentAdapterReasoningEffort.medium,
      AgentAdapterReasoningEffort.high,
      AgentAdapterReasoningEffort.xhigh,
    ],
  ),
  CodexReferenceModel(
    id: 'gpt-5.2',
    label: 'gpt-5.2',
    description:
        'Latest frontier model with improvements across knowledge, reasoning and coding',
    defaultReasoningEffort: AgentAdapterReasoningEffort.medium,
    supportedReasoningEfforts: <AgentAdapterReasoningEffort>[
      AgentAdapterReasoningEffort.low,
      AgentAdapterReasoningEffort.medium,
      AgentAdapterReasoningEffort.high,
      AgentAdapterReasoningEffort.xhigh,
    ],
  ),
  CodexReferenceModel(
    id: 'gpt-5.1-codex-mini',
    label: 'gpt-5.1-codex-mini',
    description: 'Optimized for codex. Cheaper, faster, but less capable.',
    defaultReasoningEffort: AgentAdapterReasoningEffort.medium,
    supportedReasoningEfforts: <AgentAdapterReasoningEffort>[
      AgentAdapterReasoningEffort.medium,
      AgentAdapterReasoningEffort.high,
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
    fetchedAt: fetchedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    models: <ConnectionAvailableModel>[
      for (final model in codexReferenceVisibleModels)
        ConnectionAvailableModel(
          id: model.id,
          model: model.id,
          displayName: model.label,
          description: model.description,
          hidden: false,
          supportedReasoningEfforts: model.supportedReasoningEfforts
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

@Deprecated('Use modelCatalogModelForModel instead.')
ConnectionAvailableModel? codexCatalogModelForModel(
  ConnectionModelCatalog? availableModelCatalog,
  String? modelId, {
  bool includeHidden = true,
}) => modelCatalogModelForModel(
  availableModelCatalog,
  modelId,
  includeHidden: includeHidden,
);

@Deprecated('Use visibleModelCatalogModelForModel instead.')
ConnectionAvailableModel? codexVisibleCatalogModelForModel(
  ConnectionModelCatalog? availableModelCatalog,
  String? modelId,
) => visibleModelCatalogModelForModel(availableModelCatalog, modelId);

@Deprecated('Use defaultModelCatalogModel instead.')
ConnectionAvailableModel? codexDefaultCatalogModel(
  ConnectionModelCatalog? availableModelCatalog,
) => defaultModelCatalogModel(availableModelCatalog);

@Deprecated('Use effectiveModelCatalogModelForModel instead.')
ConnectionAvailableModel? codexEffectiveCatalogModelForModel(
  ConnectionModelCatalog? availableModelCatalog,
  String? modelId,
) => effectiveModelCatalogModelForModel(availableModelCatalog, modelId);

@Deprecated('Use normalizedReasoningEffortForModel instead.')
CodexReasoningEffort? codexNormalizedReasoningEffortForModel(
  String? modelId,
  CodexReasoningEffort? effort, {
  ConnectionModelCatalog? availableModelCatalog,
}) => normalizedReasoningEffortForModel(
  modelId,
  effort,
  availableModelCatalog: availableModelCatalog,
);
