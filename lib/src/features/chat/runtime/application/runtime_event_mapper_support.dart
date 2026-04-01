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

TranscriptCanonicalItemType _canonicalItemType(Object? raw) =>
    _payloadSupport.canonicalItemType(raw);

String _itemTitle(TranscriptCanonicalItemType itemType) {
  return transcriptItemTitle(itemType);
}

String? _itemDetail(Map<String, dynamic> item, Map<String, dynamic>? payload) =>
    _payloadSupport.itemDetail(item, payload: payload);

TranscriptCanonicalRequestType _requestTypeFromMethod(String method) {
  return switch (method) {
    'item/commandExecution/requestApproval' =>
      TranscriptCanonicalRequestType.commandExecutionApproval,
    'item/fileChange/requestApproval' =>
      TranscriptCanonicalRequestType.fileChangeApproval,
    'applyPatchApproval' => TranscriptCanonicalRequestType.applyPatchApproval,
    'execCommandApproval' => TranscriptCanonicalRequestType.execCommandApproval,
    'item/permissions/requestApproval' =>
      TranscriptCanonicalRequestType.permissionsRequestApproval,
    'tool/requestUserInput' => TranscriptCanonicalRequestType.toolUserInput,
    'item/tool/requestUserInput' =>
      TranscriptCanonicalRequestType.toolUserInput,
    'mcpServer/elicitation/request' =>
      TranscriptCanonicalRequestType.mcpServerElicitation,
    _ => TranscriptCanonicalRequestType.unknown,
  };
}

TranscriptCanonicalRequestType _requestTypeFromResolvedPayload(
  Map<String, dynamic>? payload,
) {
  final request = _asObject(payload?['request']);
  final method = _asString(request?['method']) ?? _asString(payload?['method']);
  if (method != null) {
    return _requestTypeFromMethod(method);
  }
  return TranscriptCanonicalRequestType.unknown;
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

TranscriptRuntimeCollabAgentToolCall? _collaborationDetails(
  TranscriptCanonicalItemType itemType,
  Map<String, dynamic> item,
) => _payloadSupport.collaborationDetails(itemType, item);

TranscriptRuntimeThreadState _threadStateFor(
  String method,
  Map<String, dynamic>? payload,
) {
  if (method == 'thread/archived') {
    return TranscriptRuntimeThreadState.archived;
  }
  if (method == 'thread/closed') {
    return TranscriptRuntimeThreadState.closed;
  }
  if (method == 'thread/compacted') {
    return TranscriptRuntimeThreadState.compacted;
  }

  final status = _asObject(payload?['status']);
  final type = _asString(status?['type']) ?? _asString(payload?['state']);
  return switch (type) {
    'idle' => TranscriptRuntimeThreadState.idle,
    'archived' => TranscriptRuntimeThreadState.archived,
    'closed' => TranscriptRuntimeThreadState.closed,
    'compacted' => TranscriptRuntimeThreadState.compacted,
    'systemError' || 'error' || 'failed' => TranscriptRuntimeThreadState.error,
    _ => TranscriptRuntimeThreadState.active,
  };
}

TranscriptRuntimeTurnState _turnState(String? rawStatus) =>
    _payloadSupport.turnState(rawStatus);

TranscriptRuntimeItemStatus _itemStatus(
  Object? rawStatus,
  TranscriptRuntimeItemStatus fallback,
) => _payloadSupport.itemStatus(rawStatus, fallback);

TranscriptRuntimeContentStreamKind _streamKindFromMethod(String method) {
  return switch (method) {
    'item/agentMessage/delta' =>
      TranscriptRuntimeContentStreamKind.assistantText,
    'item/reasoning/textDelta' =>
      TranscriptRuntimeContentStreamKind.reasoningText,
    'item/reasoning/summaryTextDelta' =>
      TranscriptRuntimeContentStreamKind.reasoningSummaryText,
    'item/plan/delta' => TranscriptRuntimeContentStreamKind.planText,
    'item/commandExecution/outputDelta' =>
      TranscriptRuntimeContentStreamKind.commandOutput,
    'item/fileChange/outputDelta' =>
      TranscriptRuntimeContentStreamKind.fileChangeOutput,
    _ => TranscriptRuntimeContentStreamKind.unknown,
  };
}

TranscriptRuntimeTurnUsage? _toTurnUsage(Map<String, dynamic>? usage) =>
    _payloadSupport.turnUsage(usage);

List<TranscriptRuntimeUserInputQuestion> _toUserInputQuestions(
  Map<String, dynamic>? payload,
) {
  final questions = _asList(payload?['questions']);
  if (questions == null) {
    return const <TranscriptRuntimeUserInputQuestion>[];
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
                  return TranscriptRuntimeUserInputOption(
                    label: label,
                    description: description,
                  );
                })
                .whereType<TranscriptRuntimeUserInputOption>()
                .toList() ??
            const <TranscriptRuntimeUserInputOption>[];

        return TranscriptRuntimeUserInputQuestion(
          id: id,
          header: header,
          question: prompt,
          options: options,
          isOther: question['isOther'] == true,
          isSecret: question['isSecret'] == true,
        );
      })
      .whereType<TranscriptRuntimeUserInputQuestion>()
      .toList();
}

List<TranscriptRuntimePlanStep> _toPlanSteps(List<dynamic>? rawPlan) {
  if (rawPlan == null) {
    return const <TranscriptRuntimePlanStep>[];
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
          'completed' => TranscriptRuntimePlanStepStatus.completed,
          'inProgress' => TranscriptRuntimePlanStepStatus.inProgress,
          _ => TranscriptRuntimePlanStepStatus.pending,
        };

        return TranscriptRuntimePlanStep(step: title, status: status);
      })
      .whereType<TranscriptRuntimePlanStep>()
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
