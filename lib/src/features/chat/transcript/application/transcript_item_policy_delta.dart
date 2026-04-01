part of 'transcript_item_policy.dart';

TranscriptSessionState _applyContentDelta(
  TranscriptItemPolicy policy,
  TranscriptSessionState state,
  TranscriptRuntimeContentDeltaEvent event,
) {
  final itemId = event.itemId;
  final threadId = event.threadId;
  final turnId = event.turnId;
  if (itemId == null || threadId == null || turnId == null) {
    return state;
  }

  final activeTurn = policy._support.ensureActiveTurn(
    state.activeTurn,
    turnId: turnId,
    threadId: threadId,
    createdAt: event.createdAt,
  );
  final existing = activeTurn?.itemsById[itemId];
  final updatedItem = _activeItemFromContentDelta(
    policy,
    state,
    activeTurn,
    event,
    existing: existing,
  );

  return state.copyWithProjectedTranscript(
    activeTurn: _nextActiveTurnForContentDelta(policy, activeTurn, updatedItem),
  );
}

TranscriptSessionActiveItem _activeItemFromContentDelta(
  TranscriptItemPolicy policy,
  TranscriptSessionState state,
  TranscriptActiveTurnState? activeTurn,
  TranscriptRuntimeContentDeltaEvent event, {
  TranscriptSessionActiveItem? existing,
}) {
  final itemType =
      existing?.itemType ??
      policy._itemSupport.itemTypeFromStreamKind(event.streamKind);
  final forkArtifact = _shouldForkVisibleArtifact(
    activeTurn,
    existing,
    itemType: itemType,
  );
  final previousAggregatedBody = existing?.aggregatedBody ?? '';
  final aggregatedBody = '$previousAggregatedBody${event.delta}';
  final artifactBaseBody = existing == null
      ? ''
      : (forkArtifact ? previousAggregatedBody : existing.artifactBaseBody);
  return TranscriptSessionActiveItem(
    itemId: event.itemId!,
    threadId: event.threadId!,
    turnId: event.turnId!,
    itemType: itemType,
    entryId: existing == null || forkArtifact
        ? _nextItemEntryId(policy, state, activeTurn, itemId: event.itemId!)
        : existing.entryId,
    blockKind:
        existing?.blockKind ??
        policy._blockFactory.blockKindForItemType(itemType),
    createdAt: existing == null || forkArtifact
        ? event.createdAt
        : existing.createdAt,
    title: existing?.title ?? policy._blockFactory.defaultItemTitle(itemType),
    body: _visibleBodyForArtifact(
      aggregatedBody,
      artifactBaseBody: artifactBaseBody,
    ),
    aggregatedBody: aggregatedBody,
    artifactBaseBody: artifactBaseBody,
    isRunning: true,
    exitCode: existing?.exitCode,
    snapshot: _nextContentDeltaSnapshot(event, existing?.snapshot),
  );
}

Map<String, dynamic>? _nextContentDeltaSnapshot(
  TranscriptRuntimeContentDeltaEvent event,
  Map<String, dynamic>? existingSnapshot,
) {
  if (event.streamKind != TranscriptRuntimeContentStreamKind.commandOutput ||
      existingSnapshot == null ||
      !_isBackgroundTerminalWaitSnapshot(existingSnapshot)) {
    return existingSnapshot;
  }

  final nextSnapshot = Map<String, dynamic>.from(existingSnapshot)
    ..remove('stdin');
  return nextSnapshot.isEmpty ? null : nextSnapshot;
}

bool _isBackgroundTerminalWaitSnapshot(Map<String, dynamic> snapshot) {
  final stdin = snapshot['stdin'];
  if (stdin is! String || stdin.isNotEmpty) {
    return false;
  }

  final processId = snapshot['processId'] ?? snapshot['process_id'];
  return processId is String && processId.isNotEmpty;
}

TranscriptActiveTurnState? _nextActiveTurnForContentDelta(
  TranscriptItemPolicy policy,
  TranscriptActiveTurnState? activeTurn,
  TranscriptSessionActiveItem item,
) {
  if (activeTurn == null || activeTurn.turnId != item.turnId) {
    return activeTurn;
  }

  return policy._turnArtifactBuilder.upsertItem(
    activeTurn.copyWith(
      itemsById: <String, TranscriptSessionActiveItem>{
        ...activeTurn.itemsById,
        item.itemId: item,
      },
    ),
    item,
  );
}
