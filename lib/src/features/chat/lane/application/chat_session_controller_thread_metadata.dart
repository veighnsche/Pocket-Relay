part of 'chat_session_controller.dart';

Future<void> _hydrateChatSessionThreadMetadataIfNeeded(
  ChatSessionController controller,
  CodexRuntimeThreadStartedEvent event,
) async {
  final threadId = event.providerThreadId.trim();
  if (!controller._shouldHydrateThreadMetadata(threadId, event)) {
    return;
  }

  controller._threadMetadataHydrationAttempts.add(threadId);
  try {
    final thread = await controller.agentAdapterClient.readThread(
      threadId: threadId,
    );
    if (controller._isDisposed || !controller._hasThreadMetadata(thread)) {
      return;
    }

    _applyChatSessionRuntimeEvent(
      controller,
      CodexRuntimeThreadStartedEvent(
        createdAt: DateTime.now(),
        threadId: thread.id,
        providerThreadId: thread.id,
        rawMethod: 'thread/read(response)',
        threadName: thread.name,
        sourceKind: thread.sourceKind,
        agentNickname: thread.agentNickname,
        agentRole: thread.agentRole,
      ),
    );
  } catch (error) {
    controller._emitDiagnosticWarning(
      ChatSessionErrors.threadMetadataHydrationFailed(
        threadId: threadId,
        error: error,
      ),
      rawMethod: 'local/thread-metadata-hydration',
    );
  }
}
