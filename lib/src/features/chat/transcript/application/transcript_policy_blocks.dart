part of 'transcript_policy.dart';

CodexSessionState _applyStatusImpl(
  TranscriptPolicy policy,
  CodexSessionState state,
  CodexRuntimeStatusEvent event,
) {
  if (event.rawMethod == 'thread/tokenUsage/updated') {
    final usageBlock = CodexUsageBlock(
      id: policy._support.eventEntryId('thread-usage', event.createdAt),
      createdAt: event.createdAt,
      title: event.title,
      body: event.message,
    );
    final activeTurn = policy._support.ensureActiveTurn(
      state.activeTurn,
      turnId: event.turnId,
      threadId: event.threadId,
      createdAt: event.createdAt,
    );
    return state.copyWithProjectedTranscript(
      activeTurn: activeTurn?.copyWith(
        pendingThreadTokenUsageBlock: usageBlock,
      ),
    );
  }
  if (!policy._support.isTranscriptStatusSignal(event)) {
    return state;
  }
  return _stateWithTranscriptBlockImpl(
    policy,
    state,
    CodexStatusBlock(
      id: policy._support.eventEntryId('status', event.createdAt),
      createdAt: event.createdAt,
      title: event.title,
      body: event.message,
      statusKind: policy._support.statusKindForRuntimeStatus(event),
      isTranscriptSignal: true,
    ),
    turnId: event.turnId,
    threadId: event.threadId,
  );
}

CodexSessionState _markUnpinnedHostKeySavedImpl(
  CodexSessionState state, {
  required String blockId,
}) {
  final blockIndex = state.blocks.indexWhere(
    (block) => block is CodexSshUnpinnedHostKeyBlock && block.id == blockId,
  );
  if (blockIndex == -1) {
    return state;
  }

  final block = state.blocks[blockIndex] as CodexSshUnpinnedHostKeyBlock;
  if (block.isSaved) {
    return state;
  }

  final nextBlocks = List<CodexUiBlock>.from(state.blocks);
  nextBlocks[blockIndex] = block.copyWith(isSaved: true);
  return state.copyWithProjectedTranscript(blocks: nextBlocks);
}

String _sshUnpinnedHostKeyBlockIdImpl({
  required String host,
  required int port,
}) {
  return 'ssh-unpinned-$host-$port';
}

String _sshConnectFailedBlockIdImpl({required String host, required int port}) {
  return 'ssh-connect-failed-$host-$port';
}

String _sshHostKeyMismatchBlockIdImpl({
  required String host,
  required int port,
}) {
  return 'ssh-hostkey-mismatch-$host-$port';
}

String _sshAuthenticationFailedBlockIdImpl({
  required String host,
  required int port,
  required String username,
}) {
  return 'ssh-auth-failed-$username@$host-$port';
}
