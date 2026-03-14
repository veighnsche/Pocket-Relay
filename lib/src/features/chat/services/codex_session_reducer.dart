import 'package:pocket_relay/src/features/chat/models/codex_remote_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/models/conversation_entry.dart';

class CodexSessionReducer {
  const CodexSessionReducer();

  CodexSessionState addUserMessage(
    CodexSessionState state, {
    required String text,
    DateTime? createdAt,
  }) {
    final block = CodexUserMessageBlock(
      id: _eventEntryId('user', createdAt ?? DateTime.now()),
      createdAt: createdAt ?? DateTime.now(),
      text: text,
    );

    return _upsertBlock(
      state.copyWith(connectionStatus: CodexRuntimeSessionState.running),
      block,
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
    final block = CodexStatusBlock(
      id: _eventEntryId('status', eventTime),
      createdAt: eventTime,
      title: 'Run stopped',
      body: message,
      isTranscriptSignal: true,
    );

    return _upsertBlock(
      state.copyWith(
        connectionStatus: CodexRuntimeSessionState.ready,
        clearTurnId: true,
      ),
      block,
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
    return _upsertBlock(
      cleared,
      CodexStatusBlock(
        id: _eventEntryId('status', eventTime),
        createdAt: eventTime,
        title: 'New thread',
        body: message,
        isTranscriptSignal: true,
      ),
    );
  }

  CodexSessionState clearTranscript(CodexSessionState state) {
    return state.copyWith(
      clearThreadId: true,
      clearTurnId: true,
      blocks: const <CodexUiBlock>[],
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

        return state.copyWith(threadId: threadId);
      case EntryUpsertedEvent(:final entry):
        return _upsertBlock(state, _blockFromLegacyEntry(entry));
      case InformationalEvent(:final message, :final isError):
        if (!isError) {
          return state;
        }
        return _upsertBlock(
          state,
          CodexErrorBlock(
            id: _eventEntryId('error', DateTime.now()),
            createdAt: DateTime.now(),
            title: 'Remote issue',
            body: message,
          ),
        );
      case TurnFinishedEvent():
        final nextState = state.copyWith(
          connectionStatus: CodexRuntimeSessionState.ready,
          clearTurnId: true,
          clearThreadId: ephemeralSession,
          latestUsageSummary: _buildLegacyUsageSummary(event),
        );
        return _upsertBlock(
          nextState,
          CodexUsageBlock(
            id: _eventEntryId('usage', DateTime.now()),
            createdAt: DateTime.now(),
            title: 'Turn complete',
            body:
                nextState.latestUsageSummary ??
                'The remote Codex turn finished.',
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
        return state;
      case CodexRuntimeSessionStateChangedEvent():
        return state.copyWith(connectionStatus: event.state);
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
        if (event.exitKind != CodexRuntimeSessionExitKind.error) {
          return nextState;
        }
        return _upsertBlock(
          nextState,
          CodexErrorBlock(
            id: _eventEntryId('session-exit', event.createdAt),
            createdAt: event.createdAt,
            title: 'Session exited',
            body: event.reason ?? 'The Codex session ended.',
          ),
        );
      case CodexRuntimeThreadStartedEvent():
        return state.copyWith(threadId: event.providerThreadId);
      case CodexRuntimeThreadStateChangedEvent():
        final isClosed = event.state == CodexRuntimeThreadState.closed;
        return state.copyWith(
          clearThreadId: isClosed,
          clearTurnId: isClosed,
          activeItems: isClosed
              ? const <String, CodexSessionActiveItem>{}
              : state.activeItems,
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
        return _upsertBlock(
          nextState,
          CodexUsageBlock(
            id: _eventEntryId('usage', event.createdAt),
            createdAt: event.createdAt,
            title: 'Turn complete',
            body: usageSummary,
          ),
        );
      case CodexRuntimeTurnAbortedEvent():
        return _upsertBlock(
          state.copyWith(
            connectionStatus: CodexRuntimeSessionState.ready,
            clearTurnId: true,
          ),
          CodexStatusBlock(
            id: _eventEntryId('status', event.createdAt),
            createdAt: event.createdAt,
            title: 'Turn aborted',
            body: event.reason ?? 'The active turn was aborted.',
            isTranscriptSignal: true,
          ),
        );
      case CodexRuntimeTurnPlanUpdatedEvent():
        return _upsertBlock(
          state,
          CodexPlanUpdateBlock(
            id: 'turn_plan_${event.turnId ?? event.createdAt.toIso8601String()}',
            createdAt: event.createdAt,
            explanation: event.explanation,
            steps: event.steps,
          ),
        );
      case CodexRuntimeTurnDiffUpdatedEvent():
        return _upsertBlock(
          state,
          CodexChangedFilesBlock(
            id: 'turn_diff_${event.turnId ?? event.createdAt.toIso8601String()}',
            createdAt: event.createdAt,
            title: 'Changed files',
            files: _changedFilesFromSources(
              snapshot: null,
              body: event.unifiedDiff,
              rawPayload: event.rawPayload,
            ),
            unifiedDiff: event.unifiedDiff,
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
        return _upsertBlock(
          state,
          _statusEntry(
            prefix: 'warning',
            title: 'Warning',
            body: event.details == null || event.details!.trim().isEmpty
                ? event.summary
                : '${event.summary}\n\n${event.details}',
            createdAt: event.createdAt,
            isTranscriptSignal: true,
          ),
        );
      case CodexRuntimeStatusEvent():
        if (event.rawMethod == 'thread/tokenUsage/updated') {
          return _upsertBlock(
            state,
            CodexUsageBlock(
              id: _threadTokenUsageBlockId(event.threadId),
              createdAt: event.createdAt,
              title: event.title,
              body: event.message,
            ),
          );
        }
        if (!_isTranscriptStatusSignal(event)) {
          return state;
        }
        return _upsertBlock(
          state,
          CodexStatusBlock(
            id: _eventEntryId('status', event.createdAt),
            createdAt: event.createdAt,
            title: event.title,
            body: event.message,
            isTranscriptSignal: true,
          ),
        );
      case CodexRuntimeErrorEvent():
        return _upsertBlock(
          state,
          CodexErrorBlock(
            id: _eventEntryId('error', event.createdAt),
            createdAt: event.createdAt,
            title: 'Runtime error',
            body: event.message,
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
    final nextBlock = _blockFromActiveItem(nextItem);
    final nextActiveItems = <String, CodexSessionActiveItem>{
      ...state.activeItems,
      event.itemId!: nextItem,
    };

    final nextState = state.copyWith(
      activeItems: removeAfterUpsert
          ? <String, CodexSessionActiveItem>{
              ...nextActiveItems..remove(event.itemId!),
            }
          : nextActiveItems,
    );

    if (_shouldSuppressItemBlock(state, nextItem)) {
      return nextState;
    }

    return _upsertBlock(nextState, nextBlock);
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

    return _upsertBlock(
      state.copyWith(
        activeItems: <String, CodexSessionActiveItem>{
          ...state.activeItems,
          itemId: updatedItem,
        },
      ),
      _blockFromActiveItem(updatedItem),
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
      return _upsertBlock(
        state.copyWith(
          pendingUserInputRequests:
              <String, CodexSessionPendingUserInputRequest>{
                ...state.pendingUserInputRequests,
                requestId: pendingUserInput,
              },
        ),
        CodexUserInputRequestBlock(
          id: 'request_$requestId',
          createdAt: event.createdAt,
          requestId: requestId,
          requestType: event.requestType,
          title: _requestTitle(event.requestType),
          body: event.detail ?? 'Codex requested additional user input.',
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

    return _upsertBlock(
      state.copyWith(
        pendingApprovalRequests: <String, CodexSessionPendingRequest>{
          ...state.pendingApprovalRequests,
          requestId: pendingRequest,
        },
      ),
      CodexApprovalRequestBlock(
        id: 'request_$requestId',
        createdAt: event.createdAt,
        requestId: requestId,
        requestType: event.requestType,
        title: _requestTitle(event.requestType),
        body: event.detail ?? 'Codex needs a decision before it can continue.',
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

    return _upsertBlock(
      state.copyWith(
        pendingApprovalRequests: nextApprovalRequests,
        pendingUserInputRequests: nextInputRequests,
      ),
      _resolvedRequestBlock(
        id: 'request_$requestId',
        createdAt: event.createdAt,
        requestId: requestId,
        requestType: event.requestType,
        title: '${_requestTitle(event.requestType)} resolved',
        body: 'Codex received a response for this request.',
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

    return _upsertBlock(
      state.copyWith(
        pendingUserInputRequests: <String, CodexSessionPendingUserInputRequest>{
          ...state.pendingUserInputRequests,
          requestId: pendingRequest,
        },
      ),
      CodexUserInputRequestBlock(
        id: 'request_$requestId',
        createdAt: event.createdAt,
        requestId: requestId,
        requestType: CodexCanonicalRequestType.toolUserInput,
        title: 'Input required',
        body: _questionsSummary(event.questions),
        questions: event.questions,
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

    return _upsertBlock(
      state.copyWith(
        pendingUserInputRequests: <String, CodexSessionPendingUserInputRequest>{
          ...state.pendingUserInputRequests,
        }..remove(requestId),
      ),
      CodexUserInputRequestBlock(
        id: 'request_$requestId',
        createdAt: event.createdAt,
        requestId: requestId,
        requestType: CodexCanonicalRequestType.toolUserInput,
        title: 'Input submitted',
        body: _answersSummary(event.answers),
        isResolved: true,
        answers: event.answers,
      ),
    );
  }

  CodexSessionActiveItem _activeItemFromLifecycle(
    CodexRuntimeItemLifecycleEvent event, {
    CodexSessionActiveItem? existing,
  }) {
    final blockKind = _blockKindForItemType(event.itemType);
    final title = _itemTitle(event, existing?.title);
    final body = _itemBody(event, existing?.body ?? '');
    final exitCode = _extractExitCode(event.snapshot) ?? existing?.exitCode;
    return CodexSessionActiveItem(
      itemId: event.itemId!,
      threadId: event.threadId!,
      turnId: event.turnId!,
      itemType: event.itemType,
      entryId: existing?.entryId ?? 'item_${event.itemId}',
      blockKind: blockKind,
      createdAt: existing?.createdAt ?? event.createdAt,
      title: title,
      body: body,
      isRunning: event.status == CodexRuntimeItemStatus.inProgress,
      exitCode: exitCode,
      snapshot: event.snapshot ?? existing?.snapshot,
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
      blockKind: _blockKindForItemType(itemType),
      createdAt: event.createdAt,
      title: _defaultItemTitle(itemType),
      body: '',
      isRunning: true,
      snapshot: null,
    );
  }

  CodexUiBlock _blockFromLegacyEntry(ConversationEntry entry) {
    return switch (entry.kind) {
      ConversationEntryKind.user => CodexUserMessageBlock(
        id: entry.id,
        createdAt: entry.createdAt,
        text: entry.body,
      ),
      ConversationEntryKind.assistant => CodexTextBlock(
        id: entry.id,
        kind: CodexUiBlockKind.assistantMessage,
        createdAt: entry.createdAt,
        title: entry.title,
        body: entry.body,
        isRunning: entry.isRunning,
      ),
      ConversationEntryKind.command => CodexCommandExecutionBlock(
        id: entry.id,
        createdAt: entry.createdAt,
        command: entry.title,
        output: entry.body,
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      ConversationEntryKind.status => CodexStatusBlock(
        id: entry.id,
        createdAt: entry.createdAt,
        title: entry.title,
        body: entry.body,
      ),
      ConversationEntryKind.error => CodexErrorBlock(
        id: entry.id,
        createdAt: entry.createdAt,
        title: entry.title,
        body: entry.body,
      ),
      ConversationEntryKind.usage => CodexUsageBlock(
        id: entry.id,
        createdAt: entry.createdAt,
        title: entry.title,
        body: entry.body,
      ),
    };
  }

  CodexUiBlock _blockFromActiveItem(CodexSessionActiveItem item) {
    final title = item.title ?? _defaultItemTitle(item.itemType);
    return switch (item.blockKind) {
      CodexUiBlockKind.userMessage => CodexUserMessageBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        text: item.body,
      ),
      CodexUiBlockKind.commandExecution => CodexCommandExecutionBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        command: title,
        output: item.body,
        isRunning: item.isRunning,
        exitCode: item.exitCode,
      ),
      CodexUiBlockKind.workLogEntry => CodexWorkLogEntryBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        title: title,
        entryKind: _workLogEntryKindFor(item.itemType),
        preview: _workLogPreview(item),
        isRunning: item.isRunning,
        exitCode: item.exitCode,
      ),
      CodexUiBlockKind.changedFiles => CodexChangedFilesBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        title: title,
        files: _changedFilesFromSources(
          snapshot: item.snapshot,
          body: item.body,
        ),
        unifiedDiff: _unifiedDiffFromSources(
          snapshot: item.snapshot,
          body: item.body,
        ),
        isRunning: item.isRunning,
      ),
      CodexUiBlockKind.reasoning => CodexTextBlock(
        id: item.entryId,
        kind: CodexUiBlockKind.reasoning,
        createdAt: item.createdAt,
        title: title,
        body: item.body,
        isRunning: item.isRunning,
      ),
      CodexUiBlockKind.proposedPlan => CodexProposedPlanBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        title: title,
        markdown: item.body,
        isStreaming: item.isRunning,
      ),
      CodexUiBlockKind.plan => CodexPlanUpdateBlock(
        id: item.entryId,
        createdAt: item.createdAt,
      ),
      CodexUiBlockKind.status => CodexStatusBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        title: title,
        body: item.body,
      ),
      CodexUiBlockKind.error => CodexErrorBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        title: title,
        body: item.body,
      ),
      _ => CodexTextBlock(
        id: item.entryId,
        kind: CodexUiBlockKind.assistantMessage,
        createdAt: item.createdAt,
        title: title,
        body: item.body,
        isRunning: item.isRunning,
      ),
    };
  }

  CodexUiBlock _resolvedRequestBlock({
    required String id,
    required DateTime createdAt,
    required String requestId,
    required CodexCanonicalRequestType requestType,
    required String title,
    required String body,
  }) {
    final isUserInput =
        requestType == CodexCanonicalRequestType.toolUserInput ||
        requestType == CodexCanonicalRequestType.mcpServerElicitation;
    if (isUserInput) {
      return CodexUserInputRequestBlock(
        id: id,
        createdAt: createdAt,
        requestId: requestId,
        requestType: requestType,
        title: title,
        body: body,
        isResolved: true,
      );
    }

    return CodexApprovalRequestBlock(
      id: id,
      createdAt: createdAt,
      requestId: requestId,
      requestType: requestType,
      title: title,
      body: body,
      isResolved: true,
      resolutionLabel: 'resolved',
    );
  }

  CodexSessionState _upsertBlock(CodexSessionState state, CodexUiBlock block) {
    final nextBlocks = List<CodexUiBlock>.from(state.blocks);
    final index = nextBlocks.indexWhere((existing) => existing.id == block.id);
    if (index == -1) {
      nextBlocks.add(block);
    } else {
      nextBlocks[index] = block;
    }

    return state.copyWith(blocks: nextBlocks);
  }

  CodexStatusBlock _statusEntry({
    required String prefix,
    required String title,
    required String body,
    required DateTime createdAt,
    bool isTranscriptSignal = false,
  }) {
    return CodexStatusBlock(
      id: _eventEntryId(prefix, createdAt),
      createdAt: createdAt,
      title: title,
      body: body,
      isTranscriptSignal: isTranscriptSignal,
    );
  }

  static bool _isTranscriptStatusSignal(CodexRuntimeStatusEvent event) {
    return switch (event.rawMethod) {
      'account/chatgptAuthTokens/refresh' ||
      'item/tool/call' ||
      'item/fileRead/requestApproval' =>
        true,
      _ => false,
    };
  }

  static String _threadTokenUsageBlockId(String? threadId) {
    return 'thread_token_usage_${threadId ?? 'current'}';
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
    if (currentBody.isNotEmpty) {
      return currentBody;
    }
    return switch (event.itemType) {
      CodexCanonicalItemType.reviewEntered => 'Codex entered review mode.',
      CodexCanonicalItemType.reviewExited => 'Codex exited review mode.',
      CodexCanonicalItemType.contextCompaction =>
        'Codex compacted the current thread context.',
      _ => currentBody,
    };
  }

  bool _shouldSuppressItemBlock(
    CodexSessionState state,
    CodexSessionActiveItem item,
  ) {
    if (item.itemType == CodexCanonicalItemType.reasoning &&
        item.body.trim().isEmpty) {
      return true;
    }

    if (item.itemType != CodexCanonicalItemType.userMessage) {
      return false;
    }

    final text = item.body.trim();
    if (text.isEmpty) {
      return true;
    }

    final latestBlock = state.blocks.isEmpty ? null : state.blocks.last;
    return latestBlock is CodexUserMessageBlock && latestBlock.text == text;
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
      snapshot['review'],
      snapshot['revisedPrompt'],
      snapshot['patch'],
      snapshot['result'],
      nestedResult?['output'],
      nestedResult?['text'],
      nestedResult?['path'],
    ]);
  }

  static int? _extractExitCode(Map<String, dynamic>? snapshot) {
    final value = snapshot?['exitCode'] ?? snapshot?['exit_code'];
    return value is num ? value.toInt() : null;
  }

  static CodexUiBlockKind _blockKindForItemType(
    CodexCanonicalItemType itemType,
  ) {
    return switch (itemType) {
      CodexCanonicalItemType.userMessage => CodexUiBlockKind.userMessage,
      CodexCanonicalItemType.commandExecution ||
      CodexCanonicalItemType.webSearch ||
      CodexCanonicalItemType.imageView ||
      CodexCanonicalItemType.imageGeneration ||
      CodexCanonicalItemType.mcpToolCall ||
      CodexCanonicalItemType.dynamicToolCall ||
      CodexCanonicalItemType.collabAgentToolCall =>
        CodexUiBlockKind.workLogEntry,
      CodexCanonicalItemType.reasoning => CodexUiBlockKind.reasoning,
      CodexCanonicalItemType.plan => CodexUiBlockKind.proposedPlan,
      CodexCanonicalItemType.fileChange => CodexUiBlockKind.changedFiles,
      CodexCanonicalItemType.reviewEntered ||
      CodexCanonicalItemType.reviewExited ||
      CodexCanonicalItemType.contextCompaction ||
      CodexCanonicalItemType.unknown => CodexUiBlockKind.status,
      CodexCanonicalItemType.error => CodexUiBlockKind.error,
      _ => CodexUiBlockKind.assistantMessage,
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
      CodexCanonicalItemType.userMessage => 'You',
      CodexCanonicalItemType.assistantMessage => 'Codex',
      CodexCanonicalItemType.reasoning => 'Reasoning',
      CodexCanonicalItemType.plan => 'Proposed plan',
      CodexCanonicalItemType.commandExecution => 'Command',
      CodexCanonicalItemType.fileChange => 'Changed files',
      CodexCanonicalItemType.webSearch => 'Web search',
      CodexCanonicalItemType.imageView => 'Image view',
      CodexCanonicalItemType.imageGeneration => 'Image generation',
      CodexCanonicalItemType.mcpToolCall => 'MCP tool call',
      CodexCanonicalItemType.dynamicToolCall => 'Tool call',
      CodexCanonicalItemType.collabAgentToolCall => 'Agent tool call',
      CodexCanonicalItemType.reviewEntered => 'Review started',
      CodexCanonicalItemType.reviewExited => 'Review finished',
      CodexCanonicalItemType.contextCompaction => 'Context compacted',
      CodexCanonicalItemType.error => 'Error',
      _ => 'Codex',
    };
  }

  static CodexWorkLogEntryKind _workLogEntryKindFor(
    CodexCanonicalItemType itemType,
  ) {
    return switch (itemType) {
      CodexCanonicalItemType.commandExecution =>
        CodexWorkLogEntryKind.commandExecution,
      CodexCanonicalItemType.webSearch => CodexWorkLogEntryKind.webSearch,
      CodexCanonicalItemType.imageView => CodexWorkLogEntryKind.imageView,
      CodexCanonicalItemType.imageGeneration =>
        CodexWorkLogEntryKind.imageGeneration,
      CodexCanonicalItemType.mcpToolCall => CodexWorkLogEntryKind.mcpToolCall,
      CodexCanonicalItemType.dynamicToolCall =>
        CodexWorkLogEntryKind.dynamicToolCall,
      CodexCanonicalItemType.collabAgentToolCall =>
        CodexWorkLogEntryKind.collabAgentToolCall,
      CodexCanonicalItemType.fileChange => CodexWorkLogEntryKind.fileChange,
      _ => CodexWorkLogEntryKind.unknown,
    };
  }

  static String? _workLogPreview(CodexSessionActiveItem item) {
    final body = item.body.trim();
    if (body.isEmpty) {
      return null;
    }

    if (item.itemType == CodexCanonicalItemType.commandExecution) {
      final lines = body
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      return lines.isEmpty ? null : lines.last;
    }

    return body.split(RegExp(r'\r?\n')).first.trim();
  }

  static List<CodexChangedFile> _changedFilesFromSources({
    Map<String, dynamic>? snapshot,
    String? body,
    Object? rawPayload,
  }) {
    final filesByPath = <String, CodexChangedFile>{};

    void addFiles(Iterable<CodexChangedFile> files) {
      for (final file in files) {
        final existing = filesByPath[file.path];
        if (existing == null) {
          filesByPath[file.path] = file;
          continue;
        }
        filesByPath[file.path] = CodexChangedFile(
          path: file.path,
          additions: file.additions > 0 ? file.additions : existing.additions,
          deletions: file.deletions > 0 ? file.deletions : existing.deletions,
        );
      }
    }

    addFiles(_extractChangedFilesFromObject(snapshot));
    if (rawPayload is Map<String, dynamic>) {
      addFiles(_extractChangedFilesFromObject(rawPayload));
    } else if (rawPayload is Map) {
      addFiles(
        _extractChangedFilesFromObject(Map<String, dynamic>.from(rawPayload)),
      );
    }

    final unifiedDiff = _unifiedDiffFromSources(snapshot: snapshot, body: body);
    if (unifiedDiff != null && unifiedDiff.isNotEmpty) {
      addFiles(_extractChangedFilesFromDiff(unifiedDiff));
    }

    return filesByPath.values.toList(growable: false)
      ..sort((left, right) => left.path.compareTo(right.path));
  }

  static String? _unifiedDiffFromSources({
    Map<String, dynamic>? snapshot,
    String? body,
  }) {
    final diff = _stringFromCandidates(<Object?>[
      body,
      snapshot?['unifiedDiff'],
      snapshot?['diff'],
      snapshot?['patch'],
      snapshot?['text'],
      snapshot?['aggregatedOutput'],
      snapshot?['aggregated_output'],
    ]);
    if (diff == null) {
      return null;
    }
    return diff.contains('diff --git') || diff.contains('@@') ? diff : null;
  }

  static List<CodexChangedFile> _extractChangedFilesFromObject(
    Map<String, dynamic>? value,
  ) {
    if (value == null) {
      return const <CodexChangedFile>[];
    }

    final paths = <String>{};

    void collect(Object? current, int depth) {
      if (current == null || depth > 4 || paths.length >= 20) {
        return;
      }

      if (current is List) {
        for (final entry in current) {
          collect(entry, depth + 1);
          if (paths.length >= 20) {
            return;
          }
        }
        return;
      }

      final map = switch (current) {
        final Map<String, dynamic> typedMap => typedMap,
        final Map rawMap => Map<String, dynamic>.from(rawMap),
        _ => null,
      };
      if (map == null) {
        return;
      }

      for (final key in <String>[
        'path',
        'filePath',
        'relativePath',
        'filename',
        'newPath',
        'oldPath',
      ]) {
        final candidate = map[key];
        if (candidate is String && candidate.trim().isNotEmpty) {
          paths.add(candidate.trim());
        }
      }

      for (final nestedKey in <String>[
        'item',
        'result',
        'input',
        'data',
        'changes',
        'files',
        'edits',
        'patch',
        'patches',
        'operations',
      ]) {
        if (map.containsKey(nestedKey)) {
          collect(map[nestedKey], depth + 1);
        }
      }
    }

    collect(value, 0);
    return paths
        .map((path) => CodexChangedFile(path: path))
        .toList(growable: false);
  }

  static List<CodexChangedFile> _extractChangedFilesFromDiff(String diff) {
    final files = <String, _DiffStat>{};
    String? currentPath;

    for (final line in diff.split(RegExp(r'\r?\n'))) {
      if (line.startsWith('diff --git ')) {
        final match = RegExp(r'^diff --git a/(.+?) b/(.+)$').firstMatch(line);
        final path = _normalizeDiffPath(match?.group(2));
        if (path != null) {
          currentPath = path;
          files.putIfAbsent(path, () => const _DiffStat());
        }
        continue;
      }

      if (line.startsWith('+++ ')) {
        final path = _normalizeDiffPath(line.substring(4).trim());
        if (path != null) {
          currentPath = path;
          files.putIfAbsent(path, () => const _DiffStat());
        }
        continue;
      }

      if (line.startsWith('rename to ')) {
        final path = _normalizeDiffPath(line.substring('rename to '.length));
        if (path != null) {
          currentPath = path;
          files.putIfAbsent(path, () => const _DiffStat());
        }
        continue;
      }

      if (currentPath == null) {
        continue;
      }

      if (line.startsWith('+++') || line.startsWith('---')) {
        continue;
      }

      if (line.startsWith('+')) {
        final stat = files[currentPath] ?? const _DiffStat();
        files[currentPath] = stat.copyWith(additions: stat.additions + 1);
      } else if (line.startsWith('-')) {
        final stat = files[currentPath] ?? const _DiffStat();
        files[currentPath] = stat.copyWith(deletions: stat.deletions + 1);
      }
    }

    return files.entries
        .map(
          (entry) => CodexChangedFile(
            path: entry.key,
            additions: entry.value.additions,
            deletions: entry.value.deletions,
          ),
        )
        .toList(growable: false);
  }

  static String? _normalizeDiffPath(String? rawPath) {
    if (rawPath == null) {
      return null;
    }

    final trimmed = rawPath.trim();
    if (trimmed.isEmpty || trimmed == '/dev/null') {
      return null;
    }

    if (trimmed.startsWith('a/') || trimmed.startsWith('b/')) {
      return trimmed.substring(2);
    }
    return trimmed;
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

  static String? _stringFromCandidates(List<Object?> candidates) {
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }
}

class _DiffStat {
  const _DiffStat({this.additions = 0, this.deletions = 0});

  final int additions;
  final int deletions;

  _DiffStat copyWith({int? additions, int? deletions}) {
    return _DiffStat(
      additions: additions ?? this.additions,
      deletions: deletions ?? this.deletions,
    );
  }
}
