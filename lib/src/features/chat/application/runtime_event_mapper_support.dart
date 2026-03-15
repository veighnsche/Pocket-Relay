part of 'runtime_event_mapper.dart';

Map<String, dynamic>? _asObject(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

List<dynamic>? _asList(Object? value) {
  return value is List ? List<dynamic>.from(value) : null;
}

String? _asString(Object? value) {
  return value is String ? value : null;
}

int? _asInt(Object? value) {
  return value is num ? value.toInt() : null;
}

double? _asDouble(Object? value) {
  return value is num ? value.toDouble() : null;
}

String? _stringFromCandidates(List<Object?> candidates) {
  for (final candidate in candidates) {
    final value = _asString(candidate)?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

String? _stringFromCandidatesPreservingWhitespace(List<Object?> candidates) {
  for (final candidate in candidates) {
    final value = _asString(candidate);
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

String? _eventReason(Map<String, dynamic>? payload) {
  return _stringFromCandidates(<Object?>[
    payload?['reason'],
    payload?['message'],
    payload?['summary'],
  ]);
}

String? _contentDelta(Map<String, dynamic>? payload) {
  return _stringFromCandidatesPreservingWhitespace(<Object?>[
    payload?['delta'],
    payload?['text'],
    _asObject(payload?['content'])?['text'],
  ]);
}

String? _contentItemsText(List<dynamic>? contentItems) {
  if (contentItems == null) {
    return null;
  }

  final textParts = <String>[];
  for (final item in contentItems) {
    final object = _asObject(item);
    final text = _stringFromCandidatesPreservingWhitespace(<Object?>[
      object?['text'],
      _asObject(object?['content'])?['text'],
    ]);
    if (text != null && text.isNotEmpty) {
      textParts.add(text);
    }
  }

  if (textParts.isEmpty) {
    return null;
  }
  return textParts.join('\n');
}

String _threadTokenUsageMessage(Map<String, dynamic>? payload) {
  final tokenUsage = _asObject(payload?['tokenUsage']);
  final last = _asObject(tokenUsage?['last']);
  final total = _asObject(tokenUsage?['total']);
  final contextWindow = _asInt(tokenUsage?['modelContextWindow']);

  String formatBreakdown(Map<String, dynamic>? usage) {
    if (usage == null) {
      return 'unavailable';
    }

    final parts = <String>[
      'input ${_asInt(usage['inputTokens']) ?? 0}',
      'cached ${_asInt(usage['cachedInputTokens']) ?? 0}',
      'output ${_asInt(usage['outputTokens']) ?? 0}',
    ];
    final reasoning = _asInt(usage['reasoningOutputTokens']);
    if (reasoning != null && reasoning > 0) {
      parts.add('reasoning $reasoning');
    }
    final totalTokens = _asInt(usage['totalTokens']);
    if (totalTokens != null) {
      parts.add('total $totalTokens');
    }
    return parts.join(' · ');
  }

  return 'Last: ${formatBreakdown(last)}\n'
      'Total: ${formatBreakdown(total)}'
      '${contextWindow == null ? '' : '\nContext window: $contextWindow'}';
}

CodexCanonicalItemType _canonicalItemType(Object? raw) {
  final normalized = _normalizeType(raw);
  if (normalized.contains('user')) {
    return CodexCanonicalItemType.userMessage;
  }
  if (normalized.contains('agent message') ||
      normalized.contains('assistant')) {
    return CodexCanonicalItemType.assistantMessage;
  }
  if (normalized.contains('reasoning') || normalized.contains('thought')) {
    return CodexCanonicalItemType.reasoning;
  }
  if (normalized.contains('plan') || normalized.contains('todo')) {
    return CodexCanonicalItemType.plan;
  }
  if (normalized.contains('command')) {
    return CodexCanonicalItemType.commandExecution;
  }
  if (normalized.contains('file change') ||
      normalized.contains('patch') ||
      normalized.contains('edit')) {
    return CodexCanonicalItemType.fileChange;
  }
  if (normalized.contains('mcp')) {
    return CodexCanonicalItemType.mcpToolCall;
  }
  if (normalized.contains('dynamic tool')) {
    return CodexCanonicalItemType.dynamicToolCall;
  }
  if (normalized.contains('collab')) {
    return CodexCanonicalItemType.collabAgentToolCall;
  }
  if (normalized.contains('web search')) {
    return CodexCanonicalItemType.webSearch;
  }
  if (normalized.contains('image generation')) {
    return CodexCanonicalItemType.imageGeneration;
  }
  if (normalized.contains('image')) {
    return CodexCanonicalItemType.imageView;
  }
  if (normalized.contains('entered review mode') ||
      normalized.contains('review entered')) {
    return CodexCanonicalItemType.reviewEntered;
  }
  if (normalized.contains('exited review mode') ||
      normalized.contains('review exited')) {
    return CodexCanonicalItemType.reviewExited;
  }
  if (normalized.contains('compact')) {
    return CodexCanonicalItemType.contextCompaction;
  }
  if (normalized.contains('error')) {
    return CodexCanonicalItemType.error;
  }
  return CodexCanonicalItemType.unknown;
}

String _normalizeType(Object? raw) {
  final type = _asString(raw);
  if (type == null || type.trim().isEmpty) {
    return 'item';
  }

  return type
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .replaceAll(RegExp(r'[._/-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
}

String _itemTitle(CodexCanonicalItemType itemType) {
  return codexItemTitle(itemType);
}

String? _itemDetail(Map<String, dynamic> item, Map<String, dynamic>? payload) {
  final nestedResult = _asObject(item['result']);
  return _stringFromCandidates(<Object?>[
    _contentItemsText(_asList(item['content'])),
    item['command'],
    item['title'],
    item['summary'],
    item['text'],
    item['review'],
    item['path'],
    item['prompt'],
    item['query'],
    item['tool'],
    item['revisedPrompt'],
    item['result'],
    nestedResult?['command'],
    nestedResult?['path'],
    nestedResult?['text'],
    payload?['command'],
    payload?['message'],
    payload?['prompt'],
    payload?['path'],
    payload?['tool'],
  ]);
}

CodexCanonicalRequestType _requestTypeFromMethod(String method) {
  return switch (method) {
    'item/commandExecution/requestApproval' =>
      CodexCanonicalRequestType.commandExecutionApproval,
    'item/fileChange/requestApproval' =>
      CodexCanonicalRequestType.fileChangeApproval,
    'applyPatchApproval' => CodexCanonicalRequestType.applyPatchApproval,
    'execCommandApproval' => CodexCanonicalRequestType.execCommandApproval,
    'item/permissions/requestApproval' =>
      CodexCanonicalRequestType.permissionsRequestApproval,
    'tool/requestUserInput' => CodexCanonicalRequestType.toolUserInput,
    'item/tool/requestUserInput' => CodexCanonicalRequestType.toolUserInput,
    'mcpServer/elicitation/request' =>
      CodexCanonicalRequestType.mcpServerElicitation,
    _ => CodexCanonicalRequestType.unknown,
  };
}

CodexCanonicalRequestType _requestTypeFromResolvedPayload(
  Map<String, dynamic>? payload,
) {
  final request = _asObject(payload?['request']);
  final method = _asString(request?['method']) ?? _asString(payload?['method']);
  if (method != null) {
    return _requestTypeFromMethod(method);
  }
  return CodexCanonicalRequestType.unknown;
}

String? _requestDetail(Map<String, dynamic>? payload) {
  return _stringFromCandidates(<Object?>[
    payload?['message'],
    payload?['serverName'],
    payload?['command'],
    payload?['reason'],
    payload?['prompt'],
    payload?['tool'],
    payload?['previousAccountId'],
  ]);
}

CodexRuntimeThreadState _threadStateFor(
  String method,
  Map<String, dynamic>? payload,
) {
  if (method == 'thread/archived') {
    return CodexRuntimeThreadState.archived;
  }
  if (method == 'thread/closed') {
    return CodexRuntimeThreadState.closed;
  }
  if (method == 'thread/compacted') {
    return CodexRuntimeThreadState.compacted;
  }

  final status = _asObject(payload?['status']);
  final type = _asString(status?['type']) ?? _asString(payload?['state']);
  return switch (type) {
    'idle' => CodexRuntimeThreadState.idle,
    'archived' => CodexRuntimeThreadState.archived,
    'closed' => CodexRuntimeThreadState.closed,
    'compacted' => CodexRuntimeThreadState.compacted,
    'systemError' || 'error' || 'failed' => CodexRuntimeThreadState.error,
    _ => CodexRuntimeThreadState.active,
  };
}

CodexRuntimeTurnState _turnState(String? rawStatus) {
  return switch (rawStatus) {
    'failed' => CodexRuntimeTurnState.failed,
    'interrupted' => CodexRuntimeTurnState.interrupted,
    'cancelled' => CodexRuntimeTurnState.cancelled,
    _ => CodexRuntimeTurnState.completed,
  };
}

CodexRuntimeItemStatus _itemStatus(
  Object? rawStatus,
  CodexRuntimeItemStatus fallback,
) {
  return switch (_asString(rawStatus)) {
    'completed' => CodexRuntimeItemStatus.completed,
    'failed' => CodexRuntimeItemStatus.failed,
    'declined' => CodexRuntimeItemStatus.declined,
    'inProgress' ||
    'in_progress' ||
    'running' => CodexRuntimeItemStatus.inProgress,
    _ => fallback,
  };
}

CodexRuntimeContentStreamKind _streamKindFromMethod(String method) {
  return switch (method) {
    'item/agentMessage/delta' => CodexRuntimeContentStreamKind.assistantText,
    'item/reasoning/textDelta' => CodexRuntimeContentStreamKind.reasoningText,
    'item/reasoning/summaryTextDelta' =>
      CodexRuntimeContentStreamKind.reasoningSummaryText,
    'item/plan/delta' => CodexRuntimeContentStreamKind.planText,
    'item/commandExecution/outputDelta' =>
      CodexRuntimeContentStreamKind.commandOutput,
    'item/fileChange/outputDelta' =>
      CodexRuntimeContentStreamKind.fileChangeOutput,
    _ => CodexRuntimeContentStreamKind.unknown,
  };
}

CodexRuntimeTurnUsage? _toTurnUsage(Map<String, dynamic>? usage) {
  if (usage == null) {
    return null;
  }

  return CodexRuntimeTurnUsage(
    inputTokens: _asInt(usage['input_tokens'] ?? usage['inputTokens']),
    cachedInputTokens: _asInt(
      usage['cached_input_tokens'] ?? usage['cachedInputTokens'],
    ),
    outputTokens: _asInt(usage['output_tokens'] ?? usage['outputTokens']),
    raw: usage,
  );
}

List<CodexRuntimeUserInputQuestion> _toUserInputQuestions(
  Map<String, dynamic>? payload,
) {
  final questions = _asList(payload?['questions']);
  if (questions == null) {
    return const <CodexRuntimeUserInputQuestion>[];
  }

  return questions
      .map(_asObject)
      .whereType<Map<String, dynamic>>()
      .map((question) {
        final id = _asString(question['id'])?.trim();
        final header = _asString(question['header'])?.trim();
        final prompt = _asString(question['question'])?.trim();
        if (id == null || header == null || prompt == null) {
          return null;
        }

        final options =
            _asList(question['options'])
                ?.map(_asObject)
                .whereType<Map<String, dynamic>>()
                .map((option) {
                  final label = _asString(option['label'])?.trim();
                  final description = _asString(option['description'])?.trim();
                  if (label == null ||
                      label.isEmpty ||
                      description == null ||
                      description.isEmpty) {
                    return null;
                  }
                  return CodexRuntimeUserInputOption(
                    label: label,
                    description: description,
                  );
                })
                .whereType<CodexRuntimeUserInputOption>()
                .toList() ??
            const <CodexRuntimeUserInputOption>[];

        return CodexRuntimeUserInputQuestion(
          id: id,
          header: header,
          question: prompt,
          options: options,
          isOther: question['isOther'] == true,
          isSecret: question['isSecret'] == true,
        );
      })
      .whereType<CodexRuntimeUserInputQuestion>()
      .toList();
}

List<CodexRuntimePlanStep> _toPlanSteps(List<dynamic>? rawPlan) {
  if (rawPlan == null) {
    return const <CodexRuntimePlanStep>[];
  }

  return rawPlan
      .map(_asObject)
      .whereType<Map<String, dynamic>>()
      .map((step) {
        final title = _asString(step['step'])?.trim();
        if (title == null || title.isEmpty) {
          return null;
        }

        final status = switch (_asString(step['status'])) {
          'completed' => CodexRuntimePlanStepStatus.completed,
          'inProgress' => CodexRuntimePlanStepStatus.inProgress,
          _ => CodexRuntimePlanStepStatus.pending,
        };

        return CodexRuntimePlanStep(step: title, status: status);
      })
      .whereType<CodexRuntimePlanStep>()
      .toList();
}

Map<String, List<String>> _toUserInputAnswers(Map<String, dynamic>? answers) {
  if (answers == null) {
    return const <String, List<String>>{};
  }

  final result = <String, List<String>>{};
  for (final entry in answers.entries) {
    final value = entry.value;
    if (value is String) {
      result[entry.key] = <String>[value];
      continue;
    }
    if (value is List) {
      result[entry.key] = value.whereType<String>().toList();
      continue;
    }

    final answerObject = _asObject(value);
    final answerList = _asList(answerObject?['answers'])?.whereType<String>();
    if (answerList != null) {
      result[entry.key] = answerList.toList();
    }
  }
  return result;
}

String? _requestTokenFromRaw(Object? rawValue) {
  if (rawValue == null) {
    return null;
  }

  try {
    return CodexJsonRpcId.fromRaw(rawValue).token;
  } on FormatException {
    return null;
  }
}
