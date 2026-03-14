import 'package:pocket_relay/src/features/chat/models/codex_remote_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/conversation_entry.dart';

class CodexSessionReducer {
  const CodexSessionReducer();

  CodexSessionState addUserMessage(
    CodexSessionState state, {
    required String text,
    DateTime? createdAt,
  }) {
    final entry = ConversationEntry(
      id: _eventEntryId('user', createdAt ?? DateTime.now()),
      kind: ConversationEntryKind.user,
      title: 'You',
      body: text,
      createdAt: createdAt ?? DateTime.now(),
    );

    return _upsertEntry(
      state.copyWith(connectionStatus: CodexRuntimeSessionState.running),
      entry,
    );
  }

  CodexSessionState startLegacyTurn(CodexSessionState state) {
    return state.copyWith(connectionStatus: CodexRuntimeSessionState.running);
  }

  CodexSessionState finishLegacyStream(CodexSessionState state) {
    if (!state.isBusy) {
      return state;
    }
    return state.copyWith(
      connectionStatus: CodexRuntimeSessionState.ready,
      clearTurnId: true,
    );
  }

  CodexSessionState stopLegacyTurn(
    CodexSessionState state, {
    required String message,
    DateTime? createdAt,
  }) {
    final eventTime = createdAt ?? DateTime.now();
    final entry = ConversationEntry(
      id: _eventEntryId('status', eventTime),
      kind: ConversationEntryKind.status,
      title: 'Run stopped',
      body: message,
      createdAt: eventTime,
    );

    return _upsertEntry(
      state.copyWith(
        connectionStatus: CodexRuntimeSessionState.ready,
        clearTurnId: true,
      ),
      entry,
    );
  }

  CodexSessionState startFreshThread(
    CodexSessionState state, {
    String? message,
    DateTime? createdAt,
  }) {
    final cleared = state.copyWith(
      clearThreadId: true,
      clearTurnId: true,
      activeItems: const <String, CodexSessionActiveItem>{},
      pendingApprovalRequests: const <String, CodexSessionPendingRequest>{},
      pendingUserInputRequests:
          const <String, CodexSessionPendingUserInputRequest>{},
    );
    if (message == null || message.trim().isEmpty) {
      return cleared;
    }

    final eventTime = createdAt ?? DateTime.now();
    return _upsertEntry(
      cleared,
      ConversationEntry(
        id: _eventEntryId('status', eventTime),
        kind: ConversationEntryKind.status,
        title: 'New thread',
        body: message,
        createdAt: eventTime,
      ),
    );
  }

  CodexSessionState clearTranscript(CodexSessionState state) {
    return state.copyWith(
      clearThreadId: true,
      clearTurnId: true,
      transcript: const <ConversationEntry>[],
      activeItems: const <String, CodexSessionActiveItem>{},
      pendingApprovalRequests: const <String, CodexSessionPendingRequest>{},
      pendingUserInputRequests:
          const <String, CodexSessionPendingUserInputRequest>{},
      clearLatestUsageSummary: true,
    );
  }

  CodexSessionState detachThread(CodexSessionState state) {
    return state.copyWith(clearThreadId: true, clearTurnId: true);
  }

  CodexSessionState reduceLegacyRemoteEvent(
    CodexSessionState state,
    CodexRemoteEvent event, {
    required bool ephemeralSession,
  }) {
    switch (event) {
      case ThreadStartedEvent(:final threadId):
        if (ephemeralSession) {
          return state;
        }

        final nextState = state.copyWith(threadId: threadId);
        if (state.threadId == threadId) {
          return nextState;
        }

        return _upsertEntry(
          nextState,
          ConversationEntry(
            id: 'thread_$threadId',
            kind: ConversationEntryKind.status,
            title: 'Thread ready',
            body: 'Remote session ${_shortenId(threadId)} is active.',
            createdAt: DateTime.now(),
          ),
        );
      case EntryUpsertedEvent(:final entry):
        return _upsertEntry(state, entry);
      case InformationalEvent(:final message, :final isError):
        return _upsertEntry(
          state,
          ConversationEntry(
            id: _eventEntryId(isError ? 'error' : 'status', DateTime.now()),
            kind: isError
                ? ConversationEntryKind.error
                : ConversationEntryKind.status,
            title: isError ? 'Remote issue' : 'Status',
            body: message,
            createdAt: DateTime.now(),
          ),
        );
      case TurnFinishedEvent():
        final nextState = state.copyWith(
          connectionStatus: CodexRuntimeSessionState.ready,
          clearTurnId: true,
          clearThreadId: ephemeralSession,
          latestUsageSummary: _buildLegacyUsageSummary(event),
        );
        return _upsertEntry(
          nextState,
          ConversationEntry(
            id: _eventEntryId('usage', DateTime.now()),
            kind: ConversationEntryKind.usage,
            title: 'Turn complete',
            body:
                nextState.latestUsageSummary ??
                'The remote Codex turn finished.',
            createdAt: DateTime.now(),
          ),
        );
    }
  }

  CodexSessionState reduceRuntimeEvent(
    CodexSessionState state,
    CodexRuntimeEvent event,
  ) {
    switch (event) {
      case CodexRuntimeSessionStartedEvent():
        if (event.message == null || event.message!.trim().isEmpty) {
          return state;
        }
        return _upsertEntry(
          state,
          _statusEntry(
            prefix: 'status',
            title: 'Session',
            body: event.message!,
            createdAt: event.createdAt,
          ),
        );
      case CodexRuntimeSessionStateChangedEvent():
        final nextState = state.copyWith(connectionStatus: event.state);
        if (event.reason == null || event.reason!.trim().isEmpty) {
          return nextState;
        }
        return _upsertEntry(
          nextState,
          _statusEntry(
            prefix: 'status',
            title: 'Session',
            body: event.reason!,
            createdAt: event.createdAt,
          ),
        );
      case CodexRuntimeSessionExitedEvent():
        final nextState = state.copyWith(
          connectionStatus: event.exitKind == CodexRuntimeSessionExitKind.error
              ? CodexRuntimeSessionState.error
              : CodexRuntimeSessionState.stopped,
          clearThreadId: true,
          clearTurnId: true,
          activeItems: const <String, CodexSessionActiveItem>{},
          pendingApprovalRequests: const <String, CodexSessionPendingRequest>{},
          pendingUserInputRequests:
              const <String, CodexSessionPendingUserInputRequest>{},
        );
        return _upsertEntry(
          nextState,
          ConversationEntry(
            id: _eventEntryId('session-exit', event.createdAt),
            kind: event.exitKind == CodexRuntimeSessionExitKind.error
                ? ConversationEntryKind.error
                : ConversationEntryKind.status,
            title: 'Session exited',
            body: event.reason ?? 'The Codex session ended.',
            createdAt: event.createdAt,
          ),
        );
      case CodexRuntimeThreadStartedEvent():
        final nextState = state.copyWith(threadId: event.providerThreadId);
        return _upsertEntry(
          nextState,
          ConversationEntry(
            id: 'thread_${event.providerThreadId}',
            kind: ConversationEntryKind.status,
            title: 'Thread ready',
            body:
                'Remote session ${_shortenId(event.providerThreadId)} is active.',
            createdAt: event.createdAt,
          ),
        );
      case CodexRuntimeThreadStateChangedEvent():
        final isClosed = event.state == CodexRuntimeThreadState.closed;
        final nextState = state.copyWith(
          clearThreadId: isClosed,
          clearTurnId: isClosed,
          activeItems: isClosed
              ? const <String, CodexSessionActiveItem>{}
              : state.activeItems,
        );
        return _upsertEntry(
          nextState,
          _statusEntry(
            prefix: 'thread-state',
            title: 'Thread ${_threadStateLabel(event.state)}',
            body: _threadStateMessage(event),
            createdAt: event.createdAt,
          ),
        );
      case CodexRuntimeTurnStartedEvent():
        return state.copyWith(
          connectionStatus: CodexRuntimeSessionState.running,
          threadId: event.threadId ?? state.threadId,
          turnId: event.turnId,
        );
      case CodexRuntimeTurnCompletedEvent():
        final nextState = state.copyWith(
          connectionStatus: CodexRuntimeSessionState.ready,
          clearTurnId: true,
          latestUsageSummary: _buildRuntimeUsageSummary(event),
        );
        final usageSummary = nextState.latestUsageSummary;
        if (usageSummary == null || usageSummary.isEmpty) {
          return nextState;
        }
        return _upsertEntry(
          nextState,
          ConversationEntry(
            id: _eventEntryId('usage', event.createdAt),
            kind: ConversationEntryKind.usage,
            title: 'Turn complete',
            body: usageSummary,
            createdAt: event.createdAt,
          ),
        );
      case CodexRuntimeTurnAbortedEvent():
        return _upsertEntry(
          state.copyWith(
            connectionStatus: CodexRuntimeSessionState.ready,
            clearTurnId: true,
          ),
          ConversationEntry(
            id: _eventEntryId('status', event.createdAt),
            kind: ConversationEntryKind.status,
            title: 'Turn aborted',
            body: event.reason ?? 'The active turn was aborted.',
            createdAt: event.createdAt,
          ),
        );
      case CodexRuntimeItemStartedEvent():
        return _applyItemLifecycle(state, event, removeAfterUpsert: false);
      case CodexRuntimeItemUpdatedEvent():
        return _applyItemLifecycle(state, event, removeAfterUpsert: false);
      case CodexRuntimeItemCompletedEvent():
        return _applyItemLifecycle(state, event, removeAfterUpsert: true);
      case CodexRuntimeContentDeltaEvent():
        return _applyContentDelta(state, event);
      case CodexRuntimeRequestOpenedEvent():
        return _applyRequestOpened(state, event);
      case CodexRuntimeRequestResolvedEvent():
        return _applyRequestResolved(state, event);
      case CodexRuntimeUserInputRequestedEvent():
        return _applyUserInputRequested(state, event);
      case CodexRuntimeUserInputResolvedEvent():
        return _applyUserInputResolved(state, event);
      case CodexRuntimeWarningEvent():
        return _upsertEntry(
          state,
          _statusEntry(
            prefix: 'warning',
            title: 'Warning',
            body: event.details == null || event.details!.trim().isEmpty
                ? event.summary
                : '${event.summary}\n\n${event.details}',
            createdAt: event.createdAt,
          ),
        );
      case CodexRuntimeErrorEvent():
        return _upsertEntry(
          state,
          ConversationEntry(
            id: _eventEntryId('error', event.createdAt),
            kind: ConversationEntryKind.error,
            title: 'Runtime error',
            body: event.message,
            createdAt: event.createdAt,
          ),
        );
    }
  }

  CodexSessionState _applyItemLifecycle(
    CodexSessionState state,
    CodexRuntimeItemLifecycleEvent event, {
    required bool removeAfterUpsert,
  }) {
    final existing = state.activeItems[event.itemId!];
    final nextItem = _activeItemFromLifecycle(event, existing: existing);
    final nextEntry = _entryFromActiveItem(nextItem);
    final nextActiveItems = <String, CodexSessionActiveItem>{
      ...state.activeItems,
      event.itemId!: nextItem,
    };

    final nextState = _upsertEntry(
      state.copyWith(
        activeItems: removeAfterUpsert
            ? <String, CodexSessionActiveItem>{
                ...nextActiveItems..remove(event.itemId!),
              }
            : nextActiveItems,
      ),
      nextEntry,
    );

    return nextState;
  }

  CodexSessionState _applyContentDelta(
    CodexSessionState state,
    CodexRuntimeContentDeltaEvent event,
  ) {
    final itemId = event.itemId;
    final threadId = event.threadId;
    final turnId = event.turnId;
    if (itemId == null || threadId == null || turnId == null) {
      return state;
    }

    final existing =
        state.activeItems[itemId] ?? _activeItemFromContentDelta(event);
    final updatedItem = existing.copyWith(
      body: '${existing.body}${event.delta}',
      isRunning: true,
    );

    return _upsertEntry(
      state.copyWith(
        activeItems: <String, CodexSessionActiveItem>{
          ...state.activeItems,
          itemId: updatedItem,
        },
      ),
      _entryFromActiveItem(updatedItem),
    );
  }

  CodexSessionState _applyRequestOpened(
    CodexSessionState state,
    CodexRuntimeRequestOpenedEvent event,
  ) {
    final requestId = event.requestId;
    if (requestId == null) {
      return state;
    }

    if (event.requestType == CodexCanonicalRequestType.mcpServerElicitation) {
      final pendingUserInput = CodexSessionPendingUserInputRequest(
        requestId: requestId,
        requestType: event.requestType,
        createdAt: event.createdAt,
        threadId: event.threadId,
        turnId: event.turnId,
        itemId: event.itemId,
        detail: event.detail,
        args: event.args,
      );
      return _upsertEntry(
        state.copyWith(
          pendingUserInputRequests:
              <String, CodexSessionPendingUserInputRequest>{
                ...state.pendingUserInputRequests,
                requestId: pendingUserInput,
              },
        ),
        ConversationEntry(
          id: 'request_$requestId',
          kind: ConversationEntryKind.status,
          title: _requestTitle(event.requestType),
          body: event.detail ?? 'Codex requested additional user input.',
          createdAt: event.createdAt,
        ),
      );
    }

    final pendingRequest = CodexSessionPendingRequest(
      requestId: requestId,
      requestType: event.requestType,
      createdAt: event.createdAt,
      threadId: event.threadId,
      turnId: event.turnId,
      itemId: event.itemId,
      detail: event.detail,
      args: event.args,
    );

    return _upsertEntry(
      state.copyWith(
        pendingApprovalRequests: <String, CodexSessionPendingRequest>{
          ...state.pendingApprovalRequests,
          requestId: pendingRequest,
        },
      ),
      ConversationEntry(
        id: 'request_$requestId',
        kind: ConversationEntryKind.status,
        title: _requestTitle(event.requestType),
        body: event.detail ?? 'Codex needs a decision before it can continue.',
        createdAt: event.createdAt,
      ),
    );
  }

  CodexSessionState _applyRequestResolved(
    CodexSessionState state,
    CodexRuntimeRequestResolvedEvent event,
  ) {
    final requestId = event.requestId;
    if (requestId == null) {
      return state;
    }

    final nextApprovalRequests = <String, CodexSessionPendingRequest>{
      ...state.pendingApprovalRequests,
    }..remove(requestId);
    final nextInputRequests = <String, CodexSessionPendingUserInputRequest>{
      ...state.pendingUserInputRequests,
    }..remove(requestId);

    return _upsertEntry(
      state.copyWith(
        pendingApprovalRequests: nextApprovalRequests,
        pendingUserInputRequests: nextInputRequests,
      ),
      ConversationEntry(
        id: 'request_$requestId',
        kind: ConversationEntryKind.status,
        title: '${_requestTitle(event.requestType)} resolved',
        body: 'Codex received a response for this request.',
        createdAt: event.createdAt,
      ),
    );
  }

  CodexSessionState _applyUserInputRequested(
    CodexSessionState state,
    CodexRuntimeUserInputRequestedEvent event,
  ) {
    final requestId = event.requestId;
    if (requestId == null) {
      return state;
    }

    final pendingRequest = CodexSessionPendingUserInputRequest(
      requestId: requestId,
      requestType: CodexCanonicalRequestType.toolUserInput,
      createdAt: event.createdAt,
      threadId: event.threadId,
      turnId: event.turnId,
      itemId: event.itemId,
      questions: event.questions,
      args: event.rawPayload,
    );

    return _upsertEntry(
      state.copyWith(
        pendingUserInputRequests: <String, CodexSessionPendingUserInputRequest>{
          ...state.pendingUserInputRequests,
          requestId: pendingRequest,
        },
      ),
      ConversationEntry(
        id: 'request_$requestId',
        kind: ConversationEntryKind.status,
        title: 'Input required',
        body: _questionsSummary(event.questions),
        createdAt: event.createdAt,
      ),
    );
  }

  CodexSessionState _applyUserInputResolved(
    CodexSessionState state,
    CodexRuntimeUserInputResolvedEvent event,
  ) {
    final requestId = event.requestId;
    if (requestId == null) {
      return state;
    }

    return _upsertEntry(
      state.copyWith(
        pendingUserInputRequests: <String, CodexSessionPendingUserInputRequest>{
          ...state.pendingUserInputRequests,
        }..remove(requestId),
      ),
      ConversationEntry(
        id: 'request_$requestId',
        kind: ConversationEntryKind.status,
        title: 'Input submitted',
        body: _answersSummary(event.answers),
        createdAt: event.createdAt,
      ),
    );
  }

  CodexSessionActiveItem _activeItemFromLifecycle(
    CodexRuntimeItemLifecycleEvent event, {
    CodexSessionActiveItem? existing,
  }) {
    final kind = _entryKindForItemType(event.itemType);
    final title = _itemTitle(event, existing?.title);
    final body = _itemBody(event, existing?.body ?? '');
    final exitCode = _extractExitCode(event.snapshot) ?? existing?.exitCode;
    return CodexSessionActiveItem(
      itemId: event.itemId!,
      threadId: event.threadId!,
      turnId: event.turnId!,
      itemType: event.itemType,
      entryId: existing?.entryId ?? 'item_${event.itemId}',
      kind: kind,
      createdAt: existing?.createdAt ?? event.createdAt,
      title: title,
      body: body,
      isRunning: event.status == CodexRuntimeItemStatus.inProgress,
      exitCode: exitCode,
    );
  }

  CodexSessionActiveItem _activeItemFromContentDelta(
    CodexRuntimeContentDeltaEvent event,
  ) {
    final itemType = _itemTypeFromStreamKind(event.streamKind);
    return CodexSessionActiveItem(
      itemId: event.itemId!,
      threadId: event.threadId!,
      turnId: event.turnId!,
      itemType: itemType,
      entryId: 'item_${event.itemId}',
      kind: _entryKindForItemType(itemType),
      createdAt: event.createdAt,
      title: _defaultItemTitle(itemType),
      body: '',
      isRunning: true,
    );
  }

  ConversationEntry _entryFromActiveItem(CodexSessionActiveItem item) {
    return ConversationEntry(
      id: item.entryId,
      kind: item.kind,
      title: item.title ?? _defaultItemTitle(item.itemType),
      body: item.body,
      createdAt: item.createdAt,
      isRunning: item.isRunning,
      exitCode: item.exitCode,
    );
  }

  CodexSessionState _upsertEntry(
    CodexSessionState state,
    ConversationEntry entry,
  ) {
    final nextTranscript = List<ConversationEntry>.from(state.transcript);
    final index = nextTranscript.indexWhere(
      (existing) => existing.id == entry.id,
    );
    if (index == -1) {
      nextTranscript.add(entry);
    } else {
      nextTranscript[index] = entry;
    }

    return state.copyWith(transcript: nextTranscript);
  }

  ConversationEntry _statusEntry({
    required String prefix,
    required String title,
    required String body,
    required DateTime createdAt,
  }) {
    return ConversationEntry(
      id: _eventEntryId(prefix, createdAt),
      kind: ConversationEntryKind.status,
      title: title,
      body: body,
      createdAt: createdAt,
    );
  }

  String _itemTitle(
    CodexRuntimeItemLifecycleEvent event,
    String? existingTitle,
  ) {
    if (event.itemType == CodexCanonicalItemType.commandExecution) {
      return event.detail?.trim().isNotEmpty == true
          ? event.detail!
          : (existingTitle ?? event.title ?? 'Command');
    }
    return existingTitle ?? event.title ?? _defaultItemTitle(event.itemType);
  }

  String _itemBody(CodexRuntimeItemLifecycleEvent event, String currentBody) {
    final snapshotText = _extractTextFromSnapshot(event.snapshot);
    if (event.itemType == CodexCanonicalItemType.commandExecution) {
      if (snapshotText != null && snapshotText.isNotEmpty) {
        return snapshotText;
      }
      if (event.rawMethod == 'item/commandExecution/terminalInteraction' &&
          event.detail != null &&
          event.detail!.isNotEmpty) {
        return event.detail!;
      }
      return currentBody;
    }

    final body = _stringFromCandidates(<Object?>[snapshotText, event.detail]);
    if (body != null && body.isNotEmpty) {
      return body;
    }
    return currentBody;
  }

  static String? _extractTextFromSnapshot(Map<String, dynamic>? snapshot) {
    if (snapshot == null) {
      return null;
    }

    final result = snapshot['result'];
    final nestedResult = result is Map<String, dynamic> ? result : null;
    return _stringFromCandidates(<Object?>[
      snapshot['aggregatedOutput'],
      snapshot['aggregated_output'],
      snapshot['text'],
      snapshot['summary'],
      snapshot['patch'],
      nestedResult?['output'],
      nestedResult?['text'],
    ]);
  }

  static int? _extractExitCode(Map<String, dynamic>? snapshot) {
    final value = snapshot?['exitCode'] ?? snapshot?['exit_code'];
    return value is num ? value.toInt() : null;
  }

  static ConversationEntryKind _entryKindForItemType(
    CodexCanonicalItemType itemType,
  ) {
    return switch (itemType) {
      CodexCanonicalItemType.commandExecution => ConversationEntryKind.command,
      CodexCanonicalItemType.error => ConversationEntryKind.error,
      CodexCanonicalItemType.unknown => ConversationEntryKind.status,
      _ => ConversationEntryKind.assistant,
    };
  }

  static CodexCanonicalItemType _itemTypeFromStreamKind(
    CodexRuntimeContentStreamKind streamKind,
  ) {
    return switch (streamKind) {
      CodexRuntimeContentStreamKind.assistantText =>
        CodexCanonicalItemType.assistantMessage,
      CodexRuntimeContentStreamKind.reasoningText ||
      CodexRuntimeContentStreamKind.reasoningSummaryText =>
        CodexCanonicalItemType.reasoning,
      CodexRuntimeContentStreamKind.planText => CodexCanonicalItemType.plan,
      CodexRuntimeContentStreamKind.commandOutput =>
        CodexCanonicalItemType.commandExecution,
      CodexRuntimeContentStreamKind.fileChangeOutput =>
        CodexCanonicalItemType.fileChange,
      _ => CodexCanonicalItemType.unknown,
    };
  }

  static String _defaultItemTitle(CodexCanonicalItemType itemType) {
    return switch (itemType) {
      CodexCanonicalItemType.assistantMessage => 'Codex',
      CodexCanonicalItemType.reasoning => 'Reasoning',
      CodexCanonicalItemType.plan => 'Plan',
      CodexCanonicalItemType.commandExecution => 'Command',
      CodexCanonicalItemType.fileChange => 'File change',
      CodexCanonicalItemType.webSearch => 'Web search',
      CodexCanonicalItemType.imageView => 'Image view',
      CodexCanonicalItemType.error => 'Error',
      _ => 'Codex',
    };
  }

  static String _requestTitle(CodexCanonicalRequestType requestType) {
    return switch (requestType) {
      CodexCanonicalRequestType.commandExecutionApproval => 'Command approval',
      CodexCanonicalRequestType.fileReadApproval => 'File read approval',
      CodexCanonicalRequestType.fileChangeApproval => 'File change approval',
      CodexCanonicalRequestType.applyPatchApproval => 'Patch approval',
      CodexCanonicalRequestType.execCommandApproval => 'Command approval',
      CodexCanonicalRequestType.permissionsRequestApproval =>
        'Permissions request',
      CodexCanonicalRequestType.toolUserInput => 'Input required',
      CodexCanonicalRequestType.mcpServerElicitation => 'MCP input required',
      CodexCanonicalRequestType.dynamicToolCall => 'Tool call',
      CodexCanonicalRequestType.authTokensRefresh => 'Auth refresh',
      CodexCanonicalRequestType.unknown => 'Request',
    };
  }

  static String _threadStateLabel(CodexRuntimeThreadState state) {
    return switch (state) {
      CodexRuntimeThreadState.active => 'active',
      CodexRuntimeThreadState.idle => 'idle',
      CodexRuntimeThreadState.archived => 'archived',
      CodexRuntimeThreadState.closed => 'closed',
      CodexRuntimeThreadState.compacted => 'compacted',
      CodexRuntimeThreadState.error => 'error',
    };
  }

  static String _threadStateMessage(CodexRuntimeThreadStateChangedEvent event) {
    return switch (event.state) {
      CodexRuntimeThreadState.closed => 'The current thread was closed.',
      CodexRuntimeThreadState.archived => 'The current thread was archived.',
      CodexRuntimeThreadState.compacted =>
        'Codex compacted the current thread context.',
      CodexRuntimeThreadState.error => 'The current thread reported an error.',
      _ => 'The thread state changed to ${_threadStateLabel(event.state)}.',
    };
  }

  static String _questionsSummary(
    List<CodexRuntimeUserInputQuestion> questions,
  ) {
    return questions
        .map((question) => '${question.header}: ${question.question}')
        .join('\n\n');
  }

  static String _answersSummary(Map<String, List<String>> answers) {
    if (answers.isEmpty) {
      return 'The requested input was submitted.';
    }

    return answers.entries
        .map((entry) => '${entry.key}: ${entry.value.join(', ')}')
        .join('\n');
  }

  static String _buildLegacyUsageSummary(TurnFinishedEvent event) {
    final parts = <String>[];
    final usage = event.usage;

    if (usage?.inputTokens != null) {
      parts.add('input ${usage!.inputTokens}');
    }
    if ((usage?.cachedInputTokens ?? 0) > 0) {
      parts.add('cached ${usage!.cachedInputTokens}');
    }
    if (usage?.outputTokens != null) {
      parts.add('output ${usage!.outputTokens}');
    }
    if (event.exitCode != null) {
      parts.add('exit ${event.exitCode}');
    }

    if (parts.isEmpty) {
      return 'The remote Codex turn finished.';
    }

    return parts.join(' · ');
  }

  static String _buildRuntimeUsageSummary(
    CodexRuntimeTurnCompletedEvent event,
  ) {
    final parts = <String>[];
    final usage = event.usage;

    if (usage?.inputTokens != null) {
      parts.add('input ${usage!.inputTokens}');
    }
    if ((usage?.cachedInputTokens ?? 0) > 0) {
      parts.add('cached ${usage!.cachedInputTokens}');
    }
    if (usage?.outputTokens != null) {
      parts.add('output ${usage!.outputTokens}');
    }
    if (event.totalCostUsd != null) {
      parts.add('cost \$${event.totalCostUsd!.toStringAsFixed(4)}');
    }
    if (event.stopReason != null && event.stopReason!.trim().isNotEmpty) {
      parts.add(event.stopReason!);
    }
    if (event.errorMessage != null && event.errorMessage!.trim().isNotEmpty) {
      parts.add(event.errorMessage!);
    }

    if (parts.isEmpty) {
      return 'The active Codex turn finished.';
    }

    return parts.join(' · ');
  }

  static String _eventEntryId(String prefix, DateTime createdAt) {
    return '$prefix-${createdAt.microsecondsSinceEpoch}';
  }

  static String _shortenId(String value) {
    if (value.length <= 12) {
      return value;
    }
    return '${value.substring(0, 6)}…${value.substring(value.length - 4)}';
  }

  static String? _stringFromCandidates(List<Object?> candidates) {
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }
}
