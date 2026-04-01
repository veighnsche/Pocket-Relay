import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';

class CodexRuntimePayloadSupport {
  const CodexRuntimePayloadSupport();

  Map<String, dynamic>? asObject(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  List<dynamic>? asList(Object? value) {
    return value is List ? List<dynamic>.from(value) : null;
  }

  String? asString(Object? value) {
    return value is String ? value : null;
  }

  int? asInt(Object? value) {
    return value is num ? value.toInt() : null;
  }

  double? asDouble(Object? value) {
    return value is num ? value.toDouble() : null;
  }

  String? stringFromCandidates(List<Object?> candidates) {
    for (final candidate in candidates) {
      final value = asString(candidate)?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String? stringFromCandidatesPreservingWhitespace(List<Object?> candidates) {
    for (final candidate in candidates) {
      final value = asString(candidate);
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String? contentItemsText(List<dynamic>? contentItems) {
    if (contentItems == null) {
      return null;
    }

    final textParts = <String>[];
    for (final item in contentItems) {
      final object = asObject(item);
      final text = stringFromCandidatesPreservingWhitespace(<Object?>[
        object?['text'],
        asObject(object?['content'])?['text'],
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

  TranscriptCanonicalItemType canonicalItemType(Object? raw) {
    final normalized = _normalizeType(raw);
    if (normalized.contains('user')) {
      return TranscriptCanonicalItemType.userMessage;
    }
    if (normalized.contains('agent message') ||
        normalized.contains('assistant')) {
      return TranscriptCanonicalItemType.assistantMessage;
    }
    if (normalized.contains('reasoning') || normalized.contains('thought')) {
      return TranscriptCanonicalItemType.reasoning;
    }
    if (normalized.contains('plan') || normalized.contains('todo')) {
      return TranscriptCanonicalItemType.plan;
    }
    if (normalized.contains('command')) {
      return TranscriptCanonicalItemType.commandExecution;
    }
    if (normalized.contains('file change') ||
        normalized.contains('patch') ||
        normalized.contains('edit')) {
      return TranscriptCanonicalItemType.fileChange;
    }
    if (normalized.contains('mcp')) {
      return TranscriptCanonicalItemType.mcpToolCall;
    }
    if (normalized.contains('dynamic tool')) {
      return TranscriptCanonicalItemType.dynamicToolCall;
    }
    if (normalized.contains('collab')) {
      return TranscriptCanonicalItemType.collabAgentToolCall;
    }
    if (normalized.contains('web search')) {
      return TranscriptCanonicalItemType.webSearch;
    }
    if (normalized.contains('image generation')) {
      return TranscriptCanonicalItemType.imageGeneration;
    }
    if (normalized.contains('image')) {
      return TranscriptCanonicalItemType.imageView;
    }
    if (normalized.contains('entered review mode') ||
        normalized.contains('review entered')) {
      return TranscriptCanonicalItemType.reviewEntered;
    }
    if (normalized.contains('exited review mode') ||
        normalized.contains('review exited')) {
      return TranscriptCanonicalItemType.reviewExited;
    }
    if (normalized.contains('compact')) {
      return TranscriptCanonicalItemType.contextCompaction;
    }
    if (normalized.contains('error')) {
      return TranscriptCanonicalItemType.error;
    }
    return TranscriptCanonicalItemType.unknown;
  }

  TranscriptRuntimeTurnState turnState(String? rawStatus) {
    return switch (rawStatus) {
      'failed' => TranscriptRuntimeTurnState.failed,
      'interrupted' => TranscriptRuntimeTurnState.interrupted,
      'cancelled' => TranscriptRuntimeTurnState.cancelled,
      _ => TranscriptRuntimeTurnState.completed,
    };
  }

  TranscriptRuntimeTurnState? historicalTurnCompletionState(String? rawStatus) {
    return switch (rawStatus) {
      'running' || 'active' || 'inProgress' || 'in_progress' => null,
      'failed' => TranscriptRuntimeTurnState.failed,
      'interrupted' => TranscriptRuntimeTurnState.interrupted,
      'cancelled' => TranscriptRuntimeTurnState.cancelled,
      _ => TranscriptRuntimeTurnState.completed,
    };
  }

  TranscriptRuntimeItemStatus itemStatus(
    Object? rawStatus,
    TranscriptRuntimeItemStatus fallback,
  ) {
    return switch (asString(rawStatus)) {
      'completed' => TranscriptRuntimeItemStatus.completed,
      'failed' => TranscriptRuntimeItemStatus.failed,
      'declined' => TranscriptRuntimeItemStatus.declined,
      'inProgress' ||
      'in_progress' ||
      'running' => TranscriptRuntimeItemStatus.inProgress,
      _ => fallback,
    };
  }

  TranscriptRuntimeTurnUsage? turnUsage(Map<String, dynamic>? usage) {
    if (usage == null) {
      return null;
    }

    return TranscriptRuntimeTurnUsage(
      inputTokens: asInt(usage['input_tokens'] ?? usage['inputTokens']),
      cachedInputTokens: asInt(
        usage['cached_input_tokens'] ?? usage['cachedInputTokens'],
      ),
      outputTokens: asInt(usage['output_tokens'] ?? usage['outputTokens']),
      raw: usage,
    );
  }

  String? itemDetail(
    Map<String, dynamic> item, {
    Map<String, dynamic>? payload,
  }) {
    final nestedResult = asObject(item['result']);
    return stringFromCandidates(<Object?>[
      contentItemsText(asList(item['content'])),
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

  String? threadSourceKind(Map<String, dynamic>? thread) {
    final raw = thread?['source'];
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }

    final object = asObject(raw);
    return asString(object?['kind']) ?? asString(object?['type']);
  }

  TranscriptRuntimeCollabAgentToolCall? collaborationDetails(
    TranscriptCanonicalItemType itemType,
    Map<String, dynamic> item,
  ) {
    if (itemType != TranscriptCanonicalItemType.collabAgentToolCall) {
      return null;
    }

    final senderThreadId = asString(item['senderThreadId']);
    if (senderThreadId == null || senderThreadId.isEmpty) {
      return null;
    }

    final receiverThreadIds = asList(item['receiverThreadIds'])
        ?.map(asString)
        .whereType<String>()
        .where((threadId) => threadId.trim().isNotEmpty)
        .toList(growable: false);
    if (receiverThreadIds == null || receiverThreadIds.isEmpty) {
      return null;
    }

    final rawAgentStates = asObject(item['agentsStates']);
    final agentStates = <String, TranscriptRuntimeCollabAgentState>{};
    rawAgentStates?.forEach((threadId, rawState) {
      final state = asObject(rawState);
      final status = _collabAgentStatus(state?['status']);
      if (status == TranscriptRuntimeCollabAgentStatus.unknown) {
        return;
      }
      agentStates[threadId] = TranscriptRuntimeCollabAgentState(
        status: status,
        message: asString(state?['message']),
      );
    });

    return TranscriptRuntimeCollabAgentToolCall(
      tool: _collabAgentTool(item['tool']),
      status: _collabToolCallStatus(item['status']),
      senderThreadId: senderThreadId,
      receiverThreadIds: receiverThreadIds,
      prompt: asString(item['prompt']),
      model: asString(item['model']),
      reasoningEffort: asString(item['reasoningEffort']),
      agentsStates: agentStates,
    );
  }

  String _normalizeType(Object? raw) {
    final type = asString(raw);
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

  TranscriptRuntimeCollabAgentTool _collabAgentTool(Object? raw) {
    return switch (asString(raw)) {
      'spawnAgent' => TranscriptRuntimeCollabAgentTool.spawnAgent,
      'sendInput' => TranscriptRuntimeCollabAgentTool.sendInput,
      'resumeAgent' => TranscriptRuntimeCollabAgentTool.resumeAgent,
      'wait' => TranscriptRuntimeCollabAgentTool.wait,
      'closeAgent' => TranscriptRuntimeCollabAgentTool.closeAgent,
      _ => TranscriptRuntimeCollabAgentTool.unknown,
    };
  }

  TranscriptRuntimeCollabAgentToolCallStatus _collabToolCallStatus(
    Object? raw,
  ) {
    return switch (asString(raw)) {
      'inProgress' => TranscriptRuntimeCollabAgentToolCallStatus.inProgress,
      'completed' => TranscriptRuntimeCollabAgentToolCallStatus.completed,
      'failed' => TranscriptRuntimeCollabAgentToolCallStatus.failed,
      _ => TranscriptRuntimeCollabAgentToolCallStatus.unknown,
    };
  }

  TranscriptRuntimeCollabAgentStatus _collabAgentStatus(Object? raw) {
    return switch (asString(raw)) {
      'pendingInit' => TranscriptRuntimeCollabAgentStatus.pendingInit,
      'running' => TranscriptRuntimeCollabAgentStatus.running,
      'completed' => TranscriptRuntimeCollabAgentStatus.completed,
      'errored' => TranscriptRuntimeCollabAgentStatus.errored,
      'shutdown' => TranscriptRuntimeCollabAgentStatus.shutdown,
      'notFound' => TranscriptRuntimeCollabAgentStatus.notFound,
      _ => TranscriptRuntimeCollabAgentStatus.unknown,
    };
  }
}
