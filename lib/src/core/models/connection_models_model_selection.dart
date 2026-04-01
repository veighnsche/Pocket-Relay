part of 'connection_models.dart';

ConnectionAvailableModel? modelCatalogModelForModel(
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

ConnectionAvailableModel? visibleModelCatalogModelForModel(
  ConnectionModelCatalog? availableModelCatalog,
  String? modelId,
) {
  return modelCatalogModelForModel(
    availableModelCatalog,
    modelId,
    includeHidden: false,
  );
}

ConnectionAvailableModel? defaultModelCatalogModel(
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

ConnectionAvailableModel? effectiveModelCatalogModelForModel(
  ConnectionModelCatalog? availableModelCatalog,
  String? modelId,
) {
  return modelCatalogModelForModel(availableModelCatalog, modelId) ??
      defaultModelCatalogModel(availableModelCatalog);
}

AgentAdapterReasoningEffort? normalizedReasoningEffortForModel(
  String? modelId,
  AgentAdapterReasoningEffort? effort, {
  ConnectionModelCatalog? availableModelCatalog,
}) {
  if (effort == null) {
    return null;
  }

  final availableModel = effectiveModelCatalogModelForModel(
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
