part of 'codex_app_server_request_api.dart';

String _requireThreadId(String threadId) {
  final effectiveThreadId = threadId.trim();
  if (effectiveThreadId.isEmpty) {
    throw const CodexAppServerException('Thread id cannot be empty.');
  }
  return effectiveThreadId;
}

CodexAppServerTurnInput _turnInputFor({
  String? text,
  CodexAppServerTurnInput? input,
}) {
  if (input != null) {
    return input;
  }
  if (text != null) {
    return CodexAppServerTurnInput.text(text.trim());
  }
  throw const CodexAppServerException(
    'Turn input requires either text or structured input.',
  );
}

List<Object> _turnInputPayload(CodexAppServerTurnInput input) {
  final items = <Object>[];
  for (final image in input.images) {
    if (image.url.isEmpty) {
      continue;
    }
    items.add(<String, Object?>{'type': 'image', 'url': image.url});
  }
  if (input.hasText) {
    items.add(<String, Object?>{
      'type': 'text',
      'text': input.text,
      'text_elements': input.textElements
          .map((element) => element.toJson())
          .toList(growable: false),
    });
  }
  return items;
}

Map<String, dynamic>? _asObject(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

Map<String, dynamic> _requireObject(Object? value, String label) {
  final object = _asObject(value);
  if (object == null) {
    throw CodexAppServerException('$label was not an object.');
  }
  return object;
}

String? _asString(Object? value) {
  return value is String ? value : null;
}

bool? _asBool(Object? value) {
  return value is bool ? value : null;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }

  return value
      .whereType<String>()
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

CodexAppServerSession _sessionFromPayload(
  Map<String, dynamic> payload, {
  required CodexAppServerThreadSummary thread,
  required String threadId,
  required String fallbackCwd,
  String fallbackModel = '',
  String fallbackModelProvider = '',
}) {
  return CodexAppServerSession(
    threadId: threadId,
    cwd: _asString(payload['cwd']) ?? fallbackCwd,
    model: _asString(payload['model']) ?? fallbackModel,
    modelProvider: _asString(payload['modelProvider']) ?? fallbackModelProvider,
    reasoningEffort: _responseReasoningEffort(payload),
    thread: thread,
    approvalPolicy: payload['approvalPolicy'],
    sandbox: payload['sandbox'],
  );
}

String? _responseReasoningEffort(Map<String, dynamic> payload) {
  return _asString(payload['reasoningEffort']) ??
      _asString(payload['reasoning_effort']) ??
      _asString(payload['effort']);
}

CodexAppServerModel? _asModel(Object? value) {
  final model = _asObject(value);
  final id = _asString(model?['id'])?.trim() ?? '';
  final modelName = _asString(model?['model'])?.trim() ?? '';
  final defaultReasoningEffort = codexReasoningEffortFromWireValue(
    _asString(model?['defaultReasoningEffort']) ??
        _asString(model?['default_reasoning_effort']),
  );
  if (id.isEmpty || modelName.isEmpty || defaultReasoningEffort == null) {
    return null;
  }

  final displayName =
      _asString(model?['displayName'])?.trim() ??
      _asString(model?['display_name'])?.trim();
  return CodexAppServerModel(
    id: id,
    model: modelName,
    displayName: displayName == null || displayName.isEmpty
        ? modelName
        : displayName,
    description: _asString(model?['description']) ?? '',
    hidden: _asBool(model?['hidden']) ?? false,
    supportedReasoningEfforts: _reasoningEffortOptions(
      model?['supportedReasoningEfforts'] ??
          model?['supported_reasoning_efforts'],
    ),
    defaultReasoningEffort: defaultReasoningEffort,
    inputModalities: _normalizedInputModalities(
      model?['inputModalities'] ?? model?['input_modalities'],
    ),
    supportsPersonality:
        _asBool(model?['supportsPersonality']) ??
        _asBool(model?['supports_personality']) ??
        false,
    isDefault:
        _asBool(model?['isDefault']) ?? _asBool(model?['is_default']) ?? false,
    upgrade: _asString(model?['upgrade']),
    upgradeInfo: _asModelUpgradeInfo(
      model?['upgradeInfo'] ?? model?['upgrade_info'],
    ),
    availabilityNuxMessage: _availabilityNuxMessage(
      model?['availabilityNux'] ?? model?['availability_nux'],
    ),
  );
}

List<String> _normalizedInputModalities(Object? value) {
  final normalized = <String>[];
  for (final entry in _stringList(value)) {
    final modality = entry.toLowerCase();
    if (normalized.contains(modality)) {
      continue;
    }
    normalized.add(modality);
  }
  return List<String>.unmodifiable(normalized);
}

List<CodexAppServerReasoningEffortOption> _reasoningEffortOptions(Object? raw) {
  if (raw is! List) {
    return const <CodexAppServerReasoningEffortOption>[];
  }

  return raw
      .map(_asReasoningEffortOption)
      .whereType<CodexAppServerReasoningEffortOption>()
      .toList(growable: false);
}

CodexAppServerReasoningEffortOption? _asReasoningEffortOption(Object? value) {
  final option = _asObject(value);
  final reasoningEffort = codexReasoningEffortFromWireValue(
    _asString(option?['reasoningEffort']) ??
        _asString(option?['reasoning_effort']),
  );
  if (reasoningEffort == null) {
    return null;
  }

  return CodexAppServerReasoningEffortOption(
    reasoningEffort: reasoningEffort,
    description: _asString(option?['description']) ?? '',
  );
}

CodexAppServerModelUpgradeInfo? _asModelUpgradeInfo(Object? value) {
  final upgradeInfo = _asObject(value);
  final model = _asString(upgradeInfo?['model'])?.trim() ?? '';
  if (model.isEmpty) {
    return null;
  }

  return CodexAppServerModelUpgradeInfo(
    model: model,
    upgradeCopy: _asString(upgradeInfo?['upgradeCopy']),
    modelLink: _asString(upgradeInfo?['modelLink']),
    migrationMarkdown: _asString(upgradeInfo?['migrationMarkdown']),
  );
}

String? _availabilityNuxMessage(Object? value) {
  final availabilityNux = _asObject(value);
  final message = _asString(availabilityNux?['message'])?.trim();
  if (message == null || message.isEmpty) {
    return null;
  }
  return message;
}

CodexAppServerThreadSummary _requireThreadSummary(Object? value, String label) {
  final thread = _asThreadSummary(value);
  if (thread == null) {
    throw CodexAppServerException('$label did not include a thread object.');
  }
  return thread;
}

CodexAppServerThreadSummary? _asThreadSummary(
  Object? value, {
  Object? fallbackThreadId,
}) {
  final thread = _asObject(value);
  final threadId =
      _asString(thread?['id']) ?? _asString(fallbackThreadId) ?? '';
  if (threadId.isEmpty) {
    return null;
  }

  return CodexAppServerThreadSummary(
    id: threadId,
    preview: _asString(thread?['preview']) ?? '',
    ephemeral: thread?['ephemeral'] as bool? ?? false,
    modelProvider: _asString(thread?['modelProvider']) ?? '',
    createdAt: _parseUnixTimestamp(thread?['createdAt']),
    updatedAt: _parseUnixTimestamp(thread?['updatedAt']),
    path: _asString(thread?['path']),
    cwd: _asString(thread?['cwd']),
    promptCount:
        _asInt(thread?['promptCount']) ??
        _countUserPromptItems(thread?['turns']),
    name: _asString(thread?['name']),
    sourceKind: _sourceKind(thread?['source']),
    agentNickname: _asString(thread?['agentNickname']),
    agentRole: _asString(thread?['agentRole']),
  );
}

String? _sourceKind(Object? raw) {
  if (raw is String && raw.trim().isNotEmpty) {
    return raw.trim();
  }

  final object = _asObject(raw);
  return _asString(object?['kind']) ?? _asString(object?['type']);
}

DateTime? _parseUnixTimestamp(Object? raw) {
  if (raw is! num) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(
    raw.toInt() * 1000,
    isUtc: true,
  ).toLocal();
}

int? _countUserPromptItems(Object? rawTurns) {
  if (rawTurns is! List) {
    return null;
  }

  var count = 0;
  for (final turn in rawTurns.whereType<Map>()) {
    final items = turn['items'];
    if (items is! List) {
      continue;
    }
    for (final item in items.whereType<Map>()) {
      if (_asString(item['type']) == 'userMessage') {
        count += 1;
      }
    }
  }
  return count;
}

int? _asInt(Object? value) {
  return value is num ? value.toInt() : null;
}

String _approvalPolicyFor(ConnectionProfile profile) {
  return profile.dangerouslyBypassSandbox ? 'never' : 'on-request';
}

String _sandboxFor(ConnectionProfile profile) {
  return profile.dangerouslyBypassSandbox
      ? 'danger-full-access'
      : 'workspace-write';
}

Map<String, Object?> _grantedPermissionsFromRequest(
  Map<String, dynamic>? requested,
) {
  if (requested == null) {
    return const <String, Object?>{};
  }

  return <String, Object?>{
    if (requested['network'] != null) 'network': requested['network'],
    if (requested['fileSystem'] != null) 'fileSystem': requested['fileSystem'],
    if (requested['macos'] != null) 'macos': requested['macos'],
  };
}
