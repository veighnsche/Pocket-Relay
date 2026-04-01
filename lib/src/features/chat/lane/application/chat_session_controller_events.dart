part of 'chat_session_controller.dart';

void _handleChatSessionAppServerEvent(
  ChatSessionController controller,
  AgentAdapterEvent event,
) {
  if (event is AgentAdapterDisconnectedEvent) {
    controller._resetModelCatalogHydration();
  }
  if (event is AgentAdapterRequestEvent &&
      controller._isUnsupportedHostRequest(event.method)) {
    unawaited(_handleUnsupportedChatSessionHostRequest(controller, event));
    return;
  }

  final runtimeEvents = controller._runtimeEventMapper.mapEvent(event);
  if (controller._isTrackingSshBootstrapFailures &&
      runtimeEvents
          .map(codexRuntimeEventFromAgentAdapter)
          .any(controller._isSshBootstrapFailureRuntimeEvent)) {
    controller._sawTrackedSshBootstrapFailure = true;
  }
  if (controller._isTrackingSshBootstrapFailures &&
      runtimeEvents
          .map(codexRuntimeEventFromAgentAdapter)
          .any((event) => event is CodexRuntimeUnpinnedHostKeyEvent)) {
    controller._sawTrackedUnpinnedHostKeyFailure = true;
  }

  for (final runtimeEvent in runtimeEvents) {
    _applyChatSessionRuntimeEvent(
      controller,
      codexRuntimeEventFromAgentAdapter(runtimeEvent),
    );
  }
}

Future<void> _handleUnsupportedChatSessionHostRequest(
  ChatSessionController controller,
  AgentAdapterRequestEvent event,
) async {
  final payload = _chatSessionControllerAsObject(event.params);
  final threadId = _chatSessionControllerAsString(payload?['threadId']);
  final turnId = _chatSessionControllerAsString(payload?['turnId']);
  final itemId = _chatSessionControllerAsString(payload?['itemId']);
  final toolName =
      _chatSessionControllerAsString(payload?['tool']) ?? 'dynamic tool';

  final (title, message) = switch (event.method) {
    'account/chatgptAuthTokens/refresh' => (
      'Auth refresh unsupported',
      'Pocket Relay does not manage external ChatGPT tokens, so this app-server auth refresh request was rejected.',
    ),
    'item/tool/call' => (
      'Dynamic tool unsupported',
      'Pocket Relay does not implement the experimental host-side tool "$toolName", so the request was rejected.',
    ),
    _ => (
      'Request unsupported',
      'Pocket Relay rejected an unsupported app-server request.',
    ),
  };

  _applyChatSessionRuntimeEvent(
    controller,
    CodexRuntimeStatusEvent(
      createdAt: DateTime.now(),
      threadId: threadId,
      turnId: turnId,
      itemId: itemId,
      requestId: event.requestId,
      rawMethod: event.method,
      rawPayload: event.params,
      title: title,
      message: message,
    ),
  );

  try {
    if (event.method == 'item/tool/call') {
      await controller.agentAdapterClient.respondDynamicToolCall(
        requestId: event.requestId,
        success: false,
        contentItems: <Map<String, Object?>>[
          <String, Object?>{'type': 'inputText', 'text': message},
        ],
      );
      return;
    }

    await controller.agentAdapterClient.rejectServerRequest(
      requestId: event.requestId,
      message: message,
    );
  } catch (error) {
    final userFacingError = ChatSessionErrors.rejectUnsupportedRequestFailed();
    _reportChatSessionAppServerFailure(
      controller,
      userFacingError: userFacingError,
      runtimeErrorMessage: ChatSessionErrors.runtimeMessage(
        userFacingError,
        error: error,
      ),
    );
  }
}

void _applyChatSessionRuntimeEvent(
  ChatSessionController controller,
  CodexRuntimeEvent event,
) {
  if (controller._isBufferingRuntimeEvents) {
    controller._bufferedRuntimeEvents.add(event);
    return;
  }
  controller._applySessionState(
    controller._sessionReducer.reduceRuntimeEvent(
      controller._sessionState,
      event,
    ),
  );
  if (event is CodexRuntimeThreadStartedEvent) {
    unawaited(_hydrateChatSessionThreadMetadataIfNeeded(controller, event));
  }
}
