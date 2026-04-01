part of 'connection_models.dart';

class ConnectionModelCatalog {
  const ConnectionModelCatalog({
    required this.connectionId,
    required this.fetchedAt,
    this.models = const <ConnectionAvailableModel>[],
  });

  final String connectionId;
  final DateTime fetchedAt;
  final List<ConnectionAvailableModel> models;

  List<ConnectionAvailableModel> get visibleModels =>
      <ConnectionAvailableModel>[
        for (final model in models)
          if (!model.hidden) model,
      ];

  ConnectionAvailableModel? get defaultModel {
    for (final model in models) {
      if (model.isDefault) {
        return model;
      }
    }
    return null;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'connectionId': connectionId,
      'fetchedAt': fetchedAt.toIso8601String(),
      'models': models.map((model) => model.toJson()).toList(growable: false),
    };
  }

  factory ConnectionModelCatalog.fromJson(Map<String, dynamic> json) {
    return ConnectionModelCatalog(
      connectionId: _catalogString(json['connectionId']) ?? '',
      fetchedAt:
          _catalogDateTime(json['fetchedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      models: _catalogModels(json['models']),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionModelCatalog &&
        other.connectionId == connectionId &&
        other.fetchedAt == fetchedAt &&
        listEquals(other.models, models);
  }

  @override
  int get hashCode =>
      Object.hash(connectionId, fetchedAt, Object.hashAll(models));
}

class ConnectionAvailableModel {
  const ConnectionAvailableModel({
    required this.id,
    required this.model,
    required this.displayName,
    required this.description,
    required this.hidden,
    required this.supportedReasoningEfforts,
    required this.defaultReasoningEffort,
    required this.inputModalities,
    required this.supportsPersonality,
    required this.isDefault,
    this.upgrade,
    this.upgradeInfo,
    this.availabilityNuxMessage,
  });

  final String id;
  final String model;
  final String displayName;
  final String description;
  final bool hidden;
  final List<ConnectionAvailableModelReasoningEffortOption>
  supportedReasoningEfforts;
  final AgentAdapterReasoningEffort defaultReasoningEffort;
  final List<String> inputModalities;
  final bool supportsPersonality;
  final bool isDefault;
  final String? upgrade;
  final ConnectionAvailableModelUpgradeInfo? upgradeInfo;
  final String? availabilityNuxMessage;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'model': model,
      'displayName': displayName,
      'description': description,
      'hidden': hidden,
      'supportedReasoningEfforts': supportedReasoningEfforts
          .map((option) => option.toJson())
          .toList(growable: false),
      'defaultReasoningEffort': defaultReasoningEffort.name,
      'inputModalities': inputModalities,
      'supportsPersonality': supportsPersonality,
      'isDefault': isDefault,
      'upgrade': upgrade,
      'upgradeInfo': upgradeInfo?.toJson(),
      'availabilityNuxMessage': availabilityNuxMessage,
    };
  }

  factory ConnectionAvailableModel.fromJson(Map<String, dynamic> json) {
    final defaultReasoningEffort =
        agentAdapterReasoningEffortFromWireValue(
          _catalogString(json['defaultReasoningEffort']),
        ) ??
        AgentAdapterReasoningEffort.medium;
    return ConnectionAvailableModel(
      id: _catalogString(json['id']) ?? '',
      model: _catalogString(json['model']) ?? '',
      displayName: _catalogString(json['displayName']) ?? '',
      description: json['description'] as String? ?? '',
      hidden: json['hidden'] as bool? ?? false,
      supportedReasoningEfforts: _catalogReasoningEffortOptions(
        json['supportedReasoningEfforts'],
      ),
      defaultReasoningEffort: defaultReasoningEffort,
      inputModalities: _catalogStringList(json['inputModalities']),
      supportsPersonality: json['supportsPersonality'] as bool? ?? false,
      isDefault: json['isDefault'] as bool? ?? false,
      upgrade: _catalogString(json['upgrade']),
      upgradeInfo: _catalogUpgradeInfo(json['upgradeInfo']),
      availabilityNuxMessage: _catalogString(json['availabilityNuxMessage']),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionAvailableModel &&
        other.id == id &&
        other.model == model &&
        other.displayName == displayName &&
        other.description == description &&
        other.hidden == hidden &&
        listEquals(
          other.supportedReasoningEfforts,
          supportedReasoningEfforts,
        ) &&
        other.defaultReasoningEffort == defaultReasoningEffort &&
        listEquals(other.inputModalities, inputModalities) &&
        other.supportsPersonality == supportsPersonality &&
        other.isDefault == isDefault &&
        other.upgrade == upgrade &&
        other.upgradeInfo == upgradeInfo &&
        other.availabilityNuxMessage == availabilityNuxMessage;
  }

  @override
  int get hashCode => Object.hash(
    id,
    model,
    displayName,
    description,
    hidden,
    Object.hashAll(supportedReasoningEfforts),
    defaultReasoningEffort,
    Object.hashAll(inputModalities),
    supportsPersonality,
    isDefault,
    upgrade,
    upgradeInfo,
    availabilityNuxMessage,
  );
}

class ConnectionAvailableModelReasoningEffortOption {
  const ConnectionAvailableModelReasoningEffortOption({
    required this.reasoningEffort,
    required this.description,
  });

  final AgentAdapterReasoningEffort reasoningEffort;
  final String description;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'reasoningEffort': reasoningEffort.name,
      'description': description,
    };
  }

  factory ConnectionAvailableModelReasoningEffortOption.fromJson(
    Map<String, dynamic> json,
  ) {
    return ConnectionAvailableModelReasoningEffortOption(
      reasoningEffort:
          agentAdapterReasoningEffortFromWireValue(
            _catalogString(json['reasoningEffort']),
          ) ??
          AgentAdapterReasoningEffort.medium,
      description: json['description'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionAvailableModelReasoningEffortOption &&
        other.reasoningEffort == reasoningEffort &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(reasoningEffort, description);
}

class ConnectionAvailableModelUpgradeInfo {
  const ConnectionAvailableModelUpgradeInfo({
    required this.model,
    this.upgradeCopy,
    this.modelLink,
    this.migrationMarkdown,
  });

  final String model;
  final String? upgradeCopy;
  final String? modelLink;
  final String? migrationMarkdown;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'model': model,
      'upgradeCopy': upgradeCopy,
      'modelLink': modelLink,
      'migrationMarkdown': migrationMarkdown,
    };
  }

  factory ConnectionAvailableModelUpgradeInfo.fromJson(
    Map<String, dynamic> json,
  ) {
    return ConnectionAvailableModelUpgradeInfo(
      model: _catalogString(json['model']) ?? '',
      upgradeCopy: _catalogString(json['upgradeCopy']),
      modelLink: _catalogString(json['modelLink']),
      migrationMarkdown: _catalogString(json['migrationMarkdown']),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionAvailableModelUpgradeInfo &&
        other.model == model &&
        other.upgradeCopy == upgradeCopy &&
        other.modelLink == modelLink &&
        other.migrationMarkdown == migrationMarkdown;
  }

  @override
  int get hashCode =>
      Object.hash(model, upgradeCopy, modelLink, migrationMarkdown);
}

String? _catalogString(Object? value) {
  if (value is! String) {
    return null;
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime? _catalogDateTime(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

List<String> _catalogStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .whereType<String>()
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

List<ConnectionAvailableModel> _catalogModels(Object? value) {
  if (value is! List) {
    return const <ConnectionAvailableModel>[];
  }
  return value
      .whereType<Map>()
      .map(
        (entry) =>
            ConnectionAvailableModel.fromJson(Map<String, dynamic>.from(entry)),
      )
      .where((model) => model.id.isNotEmpty && model.model.isNotEmpty)
      .toList(growable: false);
}

List<ConnectionAvailableModelReasoningEffortOption>
_catalogReasoningEffortOptions(Object? value) {
  if (value is! List) {
    return const <ConnectionAvailableModelReasoningEffortOption>[];
  }
  return value
      .whereType<Map>()
      .map(
        (entry) => ConnectionAvailableModelReasoningEffortOption.fromJson(
          Map<String, dynamic>.from(entry),
        ),
      )
      .toList(growable: false);
}

ConnectionAvailableModelUpgradeInfo? _catalogUpgradeInfo(Object? value) {
  if (value is! Map) {
    return null;
  }
  final upgradeInfo = ConnectionAvailableModelUpgradeInfo.fromJson(
    Map<String, dynamic>.from(value),
  );
  if (upgradeInfo.model.isEmpty) {
    return null;
  }
  return upgradeInfo;
}
