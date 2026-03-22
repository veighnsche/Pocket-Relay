part of 'runtime_event_mapper.dart';

const _payloadSupport = CodexRuntimePayloadSupport();

Map<String, dynamic>? _asObject(Object? value) =>
    _payloadSupport.asObject(value);

List<dynamic>? _asList(Object? value) => _payloadSupport.asList(value);

String? _asString(Object? value) => _payloadSupport.asString(value);

int? _asInt(Object? value) => _payloadSupport.asInt(value);

double? _asDouble(Object? value) => _payloadSupport.asDouble(value);

String? _stringFromCandidates(List<Object?> candidates) =>
    _payloadSupport.stringFromCandidates(candidates);

String? _stringFromCandidatesPreservingWhitespace(List<Object?> candidates) =>
    _payloadSupport.stringFromCandidatesPreservingWhitespace(candidates);

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

String? _reasoningEffortFromPayload(Map<String, dynamic>? payload) {
  return _stringFromCandidates(<Object?>[
    payload?['effort'],
    payload?['reasoningEffort'],
    payload?['reasoning_effort'],
  ]);
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

CodexCanonicalItemType _canonicalItemType(Object? raw) =>
    _payloadSupport.canonicalItemType(raw);

String _itemTitle(CodexCanonicalItemType itemType) {
  return codexItemTitle(itemType);
}

String? _itemDetail(Map<String, dynamic> item, Map<String, dynamic>? payload) =>
    _payloadSupport.itemDetail(item, payload: payload);

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

String? _threadSourceKind(Map<String, dynamic>? thread) =>
    _payloadSupport.threadSourceKind(thread);

CodexRuntimeCollabAgentToolCall? _collaborationDetails(
  CodexCanonicalItemType itemType,
  Map<String, dynamic> item,
) => _payloadSupport.collaborationDetails(itemType, item);

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

CodexRuntimeTurnState _turnState(String? rawStatus) =>
    _payloadSupport.turnState(rawStatus);

CodexRuntimeItemStatus _itemStatus(
  Object? rawStatus,
  CodexRuntimeItemStatus fallback,
) => _payloadSupport.itemStatus(rawStatus, fallback);

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

CodexRuntimeTurnUsage? _toTurnUsage(Map<String, dynamic>? usage) =>
    _payloadSupport.turnUsage(usage);

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
