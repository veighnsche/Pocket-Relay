import 'dart:async';

import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/services/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/services/codex_json_rpc_codec.dart';

class CodexRuntimeEventMapper {
  final _pendingRequests = <String, _PendingRequestInfo>{};

  List<CodexRuntimeEvent> mapEvent(CodexAppServerEvent event) {
    final now = DateTime.now();

    switch (event) {
      case CodexAppServerConnectedEvent(:final userAgent):
        return <CodexRuntimeEvent>[
          CodexRuntimeSessionStartedEvent(
            createdAt: now,
            rawMethod: 'transport/connected',
            userAgent: userAgent,
          ),
          CodexRuntimeSessionStateChangedEvent(
            createdAt: now,
            state: CodexRuntimeSessionState.ready,
            reason: userAgent == null
                ? 'App-server connected.'
                : 'App-server connected as $userAgent.',
            rawMethod: 'transport/connected',
          ),
        ];
      case CodexAppServerDisconnectedEvent(:final exitCode):
        return <CodexRuntimeEvent>[
          CodexRuntimeSessionExitedEvent(
            createdAt: now,
            exitKind: exitCode == null || exitCode == 0
                ? CodexRuntimeSessionExitKind.graceful
                : CodexRuntimeSessionExitKind.error,
            exitCode: exitCode,
            reason: exitCode == null
                ? 'App-server disconnected.'
                : 'App-server exited with code $exitCode.',
            rawMethod: 'transport/disconnected',
          ),
        ];
      case CodexAppServerDiagnosticEvent(:final message, :final isError):
        return <CodexRuntimeEvent>[
          isError
              ? CodexRuntimeErrorEvent(
                  createdAt: now,
                  message: message,
                  errorClass: CodexRuntimeErrorClass.transportError,
                  rawMethod: 'transport/diagnostic',
                )
              : CodexRuntimeWarningEvent(
                  createdAt: now,
                  summary: message,
                  rawMethod: 'transport/diagnostic',
                ),
        ];
      case CodexAppServerRequestEvent():
        return _mapRequestEvent(event, now);
      case CodexAppServerNotificationEvent():
        return _mapNotificationEvent(event, now);
    }
  }

  Stream<CodexRuntimeEvent> bind(Stream<CodexAppServerEvent> events) async* {
    await for (final event in events) {
      yield* Stream<CodexRuntimeEvent>.fromIterable(mapEvent(event));
    }
  }

  List<CodexRuntimeEvent> _mapRequestEvent(
    CodexAppServerRequestEvent event,
    DateTime now,
  ) {
    final payload = _asObject(event.params);
    final threadId = _asString(payload?['threadId']);
    final turnId = _asString(payload?['turnId']);
    final itemId = _asString(payload?['itemId']);
    final requestType = _requestTypeFromMethod(event.method);

    _pendingRequests[event.requestId] = _PendingRequestInfo(
      requestType: requestType,
      threadId: threadId,
      turnId: turnId,
      itemId: itemId,
    );

    if (event.method == 'item/tool/requestUserInput') {
      final questions = _toUserInputQuestions(payload);
      if (questions.isEmpty) {
        return const <CodexRuntimeEvent>[];
      }

      return <CodexRuntimeEvent>[
        CodexRuntimeUserInputRequestedEvent(
          createdAt: now,
          threadId: threadId,
          turnId: turnId,
          itemId: itemId,
          requestId: event.requestId,
          rawMethod: event.method,
          rawPayload: event.params,
          questions: questions,
        ),
      ];
    }

    return <CodexRuntimeEvent>[
      CodexRuntimeRequestOpenedEvent(
        createdAt: now,
        threadId: threadId,
        turnId: turnId,
        itemId: itemId,
        requestId: event.requestId,
        rawMethod: event.method,
        rawPayload: event.params,
        requestType: requestType,
        detail: _requestDetail(payload),
        args: event.params,
      ),
    ];
  }

  List<CodexRuntimeEvent> _mapNotificationEvent(
    CodexAppServerNotificationEvent event,
    DateTime now,
  ) {
    final payload = _asObject(event.params);

    switch (event.method) {
      case 'session/connecting':
        return <CodexRuntimeEvent>[
          CodexRuntimeSessionStateChangedEvent(
            createdAt: now,
            state: CodexRuntimeSessionState.starting,
            reason: _eventReason(payload) ?? 'Starting app-server session.',
            rawMethod: event.method,
            rawPayload: event.params,
          ),
        ];
      case 'session/ready':
        return <CodexRuntimeEvent>[
          CodexRuntimeSessionStateChangedEvent(
            createdAt: now,
            state: CodexRuntimeSessionState.ready,
            reason: _eventReason(payload),
            rawMethod: event.method,
            rawPayload: event.params,
          ),
        ];
      case 'session/started':
        return <CodexRuntimeEvent>[
          CodexRuntimeSessionStartedEvent(
            createdAt: now,
            rawMethod: event.method,
            rawPayload: event.params,
            message: _eventReason(payload),
          ),
        ];
      case 'session/exited':
      case 'session/closed':
        return <CodexRuntimeEvent>[
          CodexRuntimeSessionExitedEvent(
            createdAt: now,
            exitKind: event.method == 'session/closed'
                ? CodexRuntimeSessionExitKind.graceful
                : CodexRuntimeSessionExitKind.error,
            exitCode: _asInt(payload?['exitCode']),
            reason: _eventReason(payload),
            rawMethod: event.method,
            rawPayload: event.params,
          ),
        ];
      case 'thread/started':
        final thread = _asObject(payload?['thread']);
        final providerThreadId =
            _asString(thread?['id']) ?? _asString(payload?['threadId']);
        if (providerThreadId == null || providerThreadId.isEmpty) {
          return const <CodexRuntimeEvent>[];
        }

        return <CodexRuntimeEvent>[
          CodexRuntimeThreadStartedEvent(
            createdAt: now,
            threadId: providerThreadId,
            providerThreadId: providerThreadId,
            rawMethod: event.method,
            rawPayload: event.params,
          ),
        ];
      case 'thread/status/changed':
      case 'thread/archived':
      case 'thread/unarchived':
      case 'thread/closed':
      case 'thread/compacted':
        final threadId = _asString(payload?['threadId']);
        return <CodexRuntimeEvent>[
          CodexRuntimeThreadStateChangedEvent(
            createdAt: now,
            threadId: threadId,
            state: _threadStateFor(event.method, payload),
            detail: event.params,
            rawMethod: event.method,
            rawPayload: event.params,
          ),
        ];
      case 'turn/started':
        final threadId = _asString(payload?['threadId']);
        final turn = _asObject(payload?['turn']);
        final turnId = _asString(turn?['id']) ?? _asString(payload?['turnId']);
        return <CodexRuntimeEvent>[
          CodexRuntimeTurnStartedEvent(
            createdAt: now,
            threadId: threadId,
            turnId: turnId,
            rawMethod: event.method,
            rawPayload: event.params,
            model: _asString(turn?['model']),
            effort: _asString(turn?['effort']),
          ),
        ];
      case 'turn/completed':
        final threadId = _asString(payload?['threadId']);
        final turn = _asObject(payload?['turn']);
        final turnId = _asString(turn?['id']) ?? _asString(payload?['turnId']);
        final turnError = _asObject(turn?['error']);
        return <CodexRuntimeEvent>[
          CodexRuntimeTurnCompletedEvent(
            createdAt: now,
            threadId: threadId,
            turnId: turnId,
            rawMethod: event.method,
            rawPayload: event.params,
            state: _turnState(_asString(turn?['status'])),
            stopReason: _asString(turn?['stopReason']),
            usage: _toTurnUsage(_asObject(turn?['usage'])),
            modelUsage: _asObject(turn?['modelUsage']),
            totalCostUsd: _asDouble(turn?['totalCostUsd']),
            errorMessage: _asString(turnError?['message']),
          ),
        ];
      case 'turn/aborted':
        return <CodexRuntimeEvent>[
          CodexRuntimeTurnAbortedEvent(
            createdAt: now,
            threadId: _asString(payload?['threadId']),
            turnId: _asString(payload?['turnId']),
            rawMethod: event.method,
            rawPayload: event.params,
            reason: _eventReason(payload) ?? 'Turn aborted.',
          ),
        ];
      case 'item/started':
        final itemEvent = _mapItemLifecycle(
          payload,
          now,
          rawMethod: event.method,
          rawPayload: event.params,
          fallbackStatus: CodexRuntimeItemStatus.inProgress,
          builder:
              ({
                required createdAt,
                required itemType,
                required threadId,
                required turnId,
                required itemId,
                required status,
                required rawMethod,
                required rawPayload,
                required title,
                required detail,
                required snapshot,
              }) => CodexRuntimeItemStartedEvent(
                createdAt: createdAt,
                itemType: itemType,
                threadId: threadId,
                turnId: turnId,
                itemId: itemId,
                status: status,
                rawMethod: rawMethod,
                rawPayload: rawPayload,
                title: title,
                detail: detail,
                snapshot: snapshot,
              ),
        );
        return itemEvent == null
            ? const <CodexRuntimeEvent>[]
            : <CodexRuntimeEvent>[itemEvent];
      case 'item/completed':
        final itemEvent = _mapItemLifecycle(
          payload,
          now,
          rawMethod: event.method,
          rawPayload: event.params,
          fallbackStatus: CodexRuntimeItemStatus.completed,
          builder:
              ({
                required createdAt,
                required itemType,
                required threadId,
                required turnId,
                required itemId,
                required status,
                required rawMethod,
                required rawPayload,
                required title,
                required detail,
                required snapshot,
              }) => CodexRuntimeItemCompletedEvent(
                createdAt: createdAt,
                itemType: itemType,
                threadId: threadId,
                turnId: turnId,
                itemId: itemId,
                status: status,
                rawMethod: rawMethod,
                rawPayload: rawPayload,
                title: title,
                detail: detail,
                snapshot: snapshot,
              ),
        );
        return itemEvent == null
            ? const <CodexRuntimeEvent>[]
            : <CodexRuntimeEvent>[itemEvent];
      case 'item/reasoning/summaryPartAdded':
      case 'item/commandExecution/terminalInteraction':
        final itemEvent = _mapItemLifecycle(
          payload,
          now,
          rawMethod: event.method,
          rawPayload: event.params,
          fallbackStatus: CodexRuntimeItemStatus.inProgress,
          builder:
              ({
                required createdAt,
                required itemType,
                required threadId,
                required turnId,
                required itemId,
                required status,
                required rawMethod,
                required rawPayload,
                required title,
                required detail,
                required snapshot,
              }) => CodexRuntimeItemUpdatedEvent(
                createdAt: createdAt,
                itemType: itemType,
                threadId: threadId,
                turnId: turnId,
                itemId: itemId,
                status: status,
                rawMethod: rawMethod,
                rawPayload: rawPayload,
                title: title,
                detail: detail,
                snapshot: snapshot,
              ),
        );
        return itemEvent == null
            ? const <CodexRuntimeEvent>[]
            : <CodexRuntimeEvent>[itemEvent];
      case 'item/agentMessage/delta':
      case 'item/reasoning/textDelta':
      case 'item/reasoning/summaryTextDelta':
      case 'item/plan/delta':
      case 'item/commandExecution/outputDelta':
      case 'item/fileChange/outputDelta':
        final delta = _contentDelta(payload);
        final itemId = _asString(payload?['itemId']);
        final threadId = _asString(payload?['threadId']);
        final turnId = _asString(payload?['turnId']);
        if (delta == null ||
            delta.isEmpty ||
            itemId == null ||
            threadId == null ||
            turnId == null) {
          return const <CodexRuntimeEvent>[];
        }

        return <CodexRuntimeEvent>[
          CodexRuntimeContentDeltaEvent(
            createdAt: now,
            threadId: threadId,
            turnId: turnId,
            itemId: itemId,
            rawMethod: event.method,
            rawPayload: event.params,
            streamKind: _streamKindFromMethod(event.method),
            delta: delta,
            contentIndex: _asInt(payload?['contentIndex']),
            summaryIndex: _asInt(payload?['summaryIndex']),
          ),
        ];
      case 'serverRequest/resolved':
        final requestId = _requestTokenFromRaw(payload?['requestId']);
        if (requestId == null) {
          return const <CodexRuntimeEvent>[];
        }

        final pending = _pendingRequests.remove(requestId);
        final requestType =
            pending?.requestType ?? _requestTypeFromResolvedPayload(payload);
        return <CodexRuntimeEvent>[
          CodexRuntimeRequestResolvedEvent(
            createdAt: now,
            threadId: _asString(payload?['threadId']) ?? pending?.threadId,
            turnId: pending?.turnId,
            itemId: pending?.itemId,
            requestId: requestId,
            rawMethod: event.method,
            rawPayload: event.params,
            requestType: requestType,
            resolution: payload?['resolution'] ?? event.params,
          ),
        ];
      case 'item/tool/requestUserInput/answered':
        final requestId = _requestTokenFromRaw(payload?['requestId']);
        if (requestId != null) {
          _pendingRequests.remove(requestId);
        }
        return <CodexRuntimeEvent>[
          CodexRuntimeUserInputResolvedEvent(
            createdAt: now,
            threadId: _asString(payload?['threadId']),
            turnId: _asString(payload?['turnId']),
            itemId: _asString(payload?['itemId']),
            requestId: requestId,
            rawMethod: event.method,
            rawPayload: event.params,
            answers: _toUserInputAnswers(_asObject(payload?['answers'])),
          ),
        ];
      case 'error':
        final message =
            _asString(payload?['message']) ?? 'Codex runtime error.';
        return <CodexRuntimeEvent>[
          CodexRuntimeErrorEvent(
            createdAt: now,
            threadId: _asString(payload?['threadId']),
            turnId: _asString(payload?['turnId']),
            itemId: _asString(payload?['itemId']),
            rawMethod: event.method,
            rawPayload: event.params,
            message: message,
            errorClass: CodexRuntimeErrorClass.providerError,
            detail: event.params,
          ),
        ];
      case 'configWarning':
        final summary =
            _asString(payload?['summary']) ?? 'Configuration warning.';
        final details = _stringFromCandidates(<Object?>[
          payload?['details'],
          payload?['path'],
        ]);
        return <CodexRuntimeEvent>[
          CodexRuntimeWarningEvent(
            createdAt: now,
            rawMethod: event.method,
            rawPayload: event.params,
            summary: summary,
            details: details,
          ),
        ];
      case 'deprecationNotice':
        final summary = _asString(payload?['summary']) ?? 'Deprecation notice.';
        return <CodexRuntimeEvent>[
          CodexRuntimeWarningEvent(
            createdAt: now,
            rawMethod: event.method,
            rawPayload: event.params,
            summary: summary,
            details: _asString(payload?['details']),
          ),
        ];
      default:
        return const <CodexRuntimeEvent>[];
    }
  }

  CodexRuntimeItemLifecycleEvent? _mapItemLifecycle(
    Map<String, dynamic>? payload,
    DateTime now, {
    required String rawMethod,
    required Object? rawPayload,
    required CodexRuntimeItemStatus fallbackStatus,
    required CodexRuntimeItemLifecycleEvent Function({
      required DateTime createdAt,
      required CodexCanonicalItemType itemType,
      required String threadId,
      required String turnId,
      required String itemId,
      required CodexRuntimeItemStatus status,
      required String rawMethod,
      required Object? rawPayload,
      required String? title,
      required String? detail,
      required Map<String, dynamic>? snapshot,
    })
    builder,
  }) {
    final item = _asObject(payload?['item']) ?? payload;
    final threadId = _asString(payload?['threadId']);
    final turnId = _asString(payload?['turnId']);
    final itemId = _asString(item?['id']) ?? _asString(payload?['itemId']);
    if (item == null || threadId == null || turnId == null || itemId == null) {
      return null;
    }

    final itemType = _canonicalItemType(item['type'] ?? item['kind']);
    return builder(
      createdAt: now,
      itemType: itemType,
      threadId: threadId,
      turnId: turnId,
      itemId: itemId,
      status: _itemStatus(item['status'], fallbackStatus),
      rawMethod: rawMethod,
      rawPayload: rawPayload,
      title: _itemTitle(itemType),
      detail: _itemDetail(item, payload),
      snapshot: item,
    );
  }

  static Map<String, dynamic>? _asObject(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static List<dynamic>? _asList(Object? value) {
    return value is List ? List<dynamic>.from(value) : null;
  }

  static String? _asString(Object? value) {
    return value is String ? value : null;
  }

  static int? _asInt(Object? value) {
    return value is num ? value.toInt() : null;
  }

  static double? _asDouble(Object? value) {
    return value is num ? value.toDouble() : null;
  }

  static String? _stringFromCandidates(List<Object?> candidates) {
    for (final candidate in candidates) {
      final value = _asString(candidate)?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static String? _eventReason(Map<String, dynamic>? payload) {
    return _stringFromCandidates(<Object?>[
      payload?['reason'],
      payload?['message'],
      payload?['summary'],
    ]);
  }

  static String? _contentDelta(Map<String, dynamic>? payload) {
    return _stringFromCandidates(<Object?>[
      payload?['delta'],
      payload?['text'],
      _asObject(payload?['content'])?['text'],
    ]);
  }

  static CodexCanonicalItemType _canonicalItemType(Object? raw) {
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
    if (normalized.contains('image')) {
      return CodexCanonicalItemType.imageView;
    }
    if (normalized.contains('review entered')) {
      return CodexCanonicalItemType.reviewEntered;
    }
    if (normalized.contains('review exited')) {
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

  static String _normalizeType(Object? raw) {
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

  static String? _itemTitle(CodexCanonicalItemType itemType) {
    return switch (itemType) {
      CodexCanonicalItemType.assistantMessage => 'Assistant message',
      CodexCanonicalItemType.userMessage => 'User message',
      CodexCanonicalItemType.reasoning => 'Reasoning',
      CodexCanonicalItemType.plan => 'Plan',
      CodexCanonicalItemType.commandExecution => 'Ran command',
      CodexCanonicalItemType.fileChange => 'File change',
      CodexCanonicalItemType.mcpToolCall => 'MCP tool call',
      CodexCanonicalItemType.dynamicToolCall => 'Tool call',
      CodexCanonicalItemType.webSearch => 'Web search',
      CodexCanonicalItemType.imageView => 'Image view',
      CodexCanonicalItemType.error => 'Error',
      _ => null,
    };
  }

  static String? _itemDetail(
    Map<String, dynamic> item,
    Map<String, dynamic>? payload,
  ) {
    final nestedResult = _asObject(item['result']);
    return _stringFromCandidates(<Object?>[
      item['command'],
      item['title'],
      item['summary'],
      item['text'],
      item['path'],
      item['prompt'],
      nestedResult?['command'],
      payload?['command'],
      payload?['message'],
      payload?['prompt'],
    ]);
  }

  static CodexCanonicalRequestType _requestTypeFromMethod(String method) {
    return switch (method) {
      'item/commandExecution/requestApproval' =>
        CodexCanonicalRequestType.commandExecutionApproval,
      'item/fileRead/requestApproval' =>
        CodexCanonicalRequestType.fileReadApproval,
      'item/fileChange/requestApproval' =>
        CodexCanonicalRequestType.fileChangeApproval,
      'applyPatchApproval' => CodexCanonicalRequestType.applyPatchApproval,
      'execCommandApproval' => CodexCanonicalRequestType.execCommandApproval,
      'item/permissions/requestApproval' =>
        CodexCanonicalRequestType.permissionsRequestApproval,
      'item/tool/requestUserInput' => CodexCanonicalRequestType.toolUserInput,
      'item/tool/call' => CodexCanonicalRequestType.dynamicToolCall,
      'account/chatgptAuthTokens/refresh' =>
        CodexCanonicalRequestType.authTokensRefresh,
      _ => CodexCanonicalRequestType.unknown,
    };
  }

  static CodexCanonicalRequestType _requestTypeFromResolvedPayload(
    Map<String, dynamic>? payload,
  ) {
    final request = _asObject(payload?['request']);
    final method =
        _asString(request?['method']) ?? _asString(payload?['method']);
    if (method != null) {
      return _requestTypeFromMethod(method);
    }
    return CodexCanonicalRequestType.unknown;
  }

  static String? _requestDetail(Map<String, dynamic>? payload) {
    return _stringFromCandidates(<Object?>[
      payload?['command'],
      payload?['reason'],
      payload?['prompt'],
    ]);
  }

  static CodexRuntimeThreadState _threadStateFor(
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

  static CodexRuntimeTurnState _turnState(String? rawStatus) {
    return switch (rawStatus) {
      'failed' => CodexRuntimeTurnState.failed,
      'interrupted' => CodexRuntimeTurnState.interrupted,
      'cancelled' => CodexRuntimeTurnState.cancelled,
      _ => CodexRuntimeTurnState.completed,
    };
  }

  static CodexRuntimeItemStatus _itemStatus(
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

  static CodexRuntimeContentStreamKind _streamKindFromMethod(String method) {
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

  static CodexRuntimeTurnUsage? _toTurnUsage(Map<String, dynamic>? usage) {
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

  static List<CodexRuntimeUserInputQuestion> _toUserInputQuestions(
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
                    final description = _asString(
                      option['description'],
                    )?.trim();
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

  static Map<String, List<String>> _toUserInputAnswers(
    Map<String, dynamic>? answers,
  ) {
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

  static String? _requestTokenFromRaw(Object? rawValue) {
    if (rawValue == null) {
      return null;
    }

    try {
      return CodexJsonRpcId.fromRaw(rawValue).token;
    } on FormatException {
      return null;
    }
  }
}

class _PendingRequestInfo {
  const _PendingRequestInfo({
    required this.requestType,
    this.threadId,
    this.turnId,
    this.itemId,
  });

  final CodexCanonicalRequestType requestType;
  final String? threadId;
  final String? turnId;
  final String? itemId;
}
