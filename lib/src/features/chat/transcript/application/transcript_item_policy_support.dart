part of 'transcript_item_policy.dart';

int? _extractExitCode(Map<String, dynamic>? snapshot) {
  final value = snapshot?['exitCode'] ?? snapshot?['exit_code'];
  return value is num ? value.toInt() : null;
}

bool _shouldForkVisibleArtifact(
  TranscriptActiveTurnState? activeTurn,
  TranscriptSessionActiveItem? existing, {
  TranscriptCanonicalItemType? itemType,
}) {
  final effectiveItemType = itemType ?? existing?.itemType;
  if (effectiveItemType == TranscriptCanonicalItemType.commandExecution) {
    return false;
  }

  if (activeTurn == null || existing == null || activeTurn.artifacts.isEmpty) {
    return false;
  }

  final currentArtifactId = activeTurn.itemArtifactIds[existing.itemId];
  if (currentArtifactId == null) {
    return false;
  }

  return activeTurn.artifacts.last.id != currentArtifactId;
}

String _nextItemEntryId(
  TranscriptItemPolicy policy,
  TranscriptSessionState state,
  TranscriptActiveTurnState? activeTurn, {
  required String itemId,
}) {
  final usedIds = <String>{
    ...transcriptUiBlockIds(state.blocks),
    if (activeTurn != null) ...transcriptTurnArtifactIds(activeTurn.artifacts),
  };
  bool conflicts(String candidate) {
    return usedIds.contains(candidate) ||
        usedIds.contains('work_group_$candidate') ||
        usedIds.contains('changed_files_group_$candidate');
  }

  final baseId = 'item_$itemId';
  if (!conflicts(baseId)) {
    return baseId;
  }

  var ordinal = 2;
  var candidate = '$baseId-$ordinal';
  while (conflicts(candidate)) {
    ordinal += 1;
    candidate = '$baseId-$ordinal';
  }
  return candidate;
}

String _visibleBodyForArtifact(
  String aggregatedBody, {
  required String artifactBaseBody,
  bool fallbackToFullBody = false,
}) {
  if (artifactBaseBody.isEmpty) {
    return aggregatedBody;
  }

  final visibleBody = aggregatedBody.startsWith(artifactBaseBody)
      ? aggregatedBody.substring(artifactBaseBody.length)
      : aggregatedBody;
  if (visibleBody.isEmpty && fallbackToFullBody) {
    return aggregatedBody;
  }
  return visibleBody;
}

TranscriptSessionState? _suppressedLocalUserMessageState(
  TranscriptItemPolicy policy,
  TranscriptSessionState state,
  TranscriptActiveTurnState? activeTurn,
  TranscriptSessionActiveItem item,
) {
  if (item.itemType != TranscriptCanonicalItemType.userMessage) {
    return null;
  }

  if (state.localUserMessageProviderBindings.containsKey(item.itemId)) {
    return _stateAfterSuppressedLocalUserMessage(
      state,
      activeTurn: state.activeTurn,
      itemId: item.itemId,
    );
  }

  if (state.pendingLocalUserMessageBlockIds.isEmpty) {
    return null;
  }

  final providerDraft = policy._itemSupport.extractStructuredUserMessageDraft(
    item.snapshot,
  );
  final text = item.body.trim();
  if (text.isEmpty && providerDraft == null) {
    return null;
  }

  final pendingMatch = _matchingPendingLocalUserMessage(
    state.blocks,
    state.pendingLocalUserMessageBlockIds,
    text: text,
    providerDraft: providerDraft,
  );
  if (pendingMatch == null) {
    return null;
  }

  return _stateAfterSuppressedLocalUserMessage(
    state,
    activeTurn: activeTurn,
    itemId: item.itemId,
    pendingLocalUserMessageBlockIds: pendingMatch.$2,
    localUserMessageProviderBindings: <String, String>{
      ...state.localUserMessageProviderBindings,
      item.itemId: pendingMatch.$1.id,
    },
  );
}

TranscriptSessionState _stateAfterSuppressedLocalUserMessage(
  TranscriptSessionState state, {
  required TranscriptActiveTurnState? activeTurn,
  required String itemId,
  List<String>? pendingLocalUserMessageBlockIds,
  Map<String, String>? localUserMessageProviderBindings,
}) {
  return state.copyWithProjectedTranscript(
    activeTurn: _activeTurnAfterSuppressedLocalUserMessage(
      activeTurn,
      itemId: itemId,
    ),
    pendingLocalUserMessageBlockIds:
        pendingLocalUserMessageBlockIds ??
        state.pendingLocalUserMessageBlockIds,
    localUserMessageProviderBindings:
        localUserMessageProviderBindings ??
        state.localUserMessageProviderBindings,
  );
}

TranscriptUserMessageBlock? _userMessageBlockById(
  List<TranscriptUiBlock> blocks,
  String blockId,
) {
  for (final block in blocks.reversed) {
    if (block is TranscriptUserMessageBlock && block.id == blockId) {
      return block;
    }
  }
  return null;
}

(TranscriptUserMessageBlock, List<String>)? _matchingPendingLocalUserMessage(
  List<TranscriptUiBlock> blocks,
  List<String> pendingBlockIds, {
  required String text,
  ChatComposerDraft? providerDraft,
}) {
  final nextPendingBlockIds = <String>[];
  final requiresStructuredMatch =
      providerDraft != null && providerDraft.hasStructuredDraft;

  for (var index = 0; index < pendingBlockIds.length; index += 1) {
    final blockId = pendingBlockIds[index];
    final block = _userMessageBlockById(blocks, blockId);
    if (block == null) {
      continue;
    }
    final matchesProviderDraft =
        providerDraft != null &&
        _draftsMatchForProviderBinding(block.draft, providerDraft);
    if (matchesProviderDraft ||
        (!requiresStructuredMatch && block.text.trim() == text)) {
      nextPendingBlockIds.addAll(pendingBlockIds.skip(index + 1));
      return (block, nextPendingBlockIds);
    }
    nextPendingBlockIds.add(blockId);
  }

  return null;
}

bool _draftsMatchForProviderBinding(
  ChatComposerDraft localDraft,
  ChatComposerDraft providerDraft,
) {
  final normalizedLocal = localDraft.normalized();
  final normalizedProvider = providerDraft.normalized();
  if (normalizedLocal.text != normalizedProvider.text) {
    return false;
  }
  if (!listEquals(
    normalizedLocal.textElements,
    normalizedProvider.textElements,
  )) {
    return false;
  }
  return _imageAttachmentsEqualForProviderBinding(
    normalizedLocal.imageAttachments,
    normalizedProvider.imageAttachments,
  );
}

bool _imageAttachmentsEqualForProviderBinding(
  List<ChatComposerImageAttachment> left,
  List<ChatComposerImageAttachment> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    final leftAttachment = left[index];
    final rightAttachment = right[index];
    if (leftAttachment.imageUrl != rightAttachment.imageUrl) {
      return false;
    }
    if (leftAttachment.placeholder?.trim() !=
        rightAttachment.placeholder?.trim()) {
      return false;
    }
  }
  return true;
}

TranscriptActiveTurnState? _activeTurnAfterSuppressedLocalUserMessage(
  TranscriptActiveTurnState? activeTurn, {
  required String itemId,
}) {
  if (activeTurn == null) {
    return null;
  }

  final hasItem = activeTurn.itemsById.containsKey(itemId);
  final hasArtifactBinding = activeTurn.itemArtifactIds.containsKey(itemId);
  if (!hasItem && !hasArtifactBinding) {
    return activeTurn;
  }

  final nextItems = <String, TranscriptSessionActiveItem>{
    ...activeTurn.itemsById,
  }..remove(itemId);
  final nextArtifactIds = <String, String>{...activeTurn.itemArtifactIds}
    ..remove(itemId);

  return activeTurn.copyWith(
    itemsById: nextItems,
    itemArtifactIds: nextArtifactIds,
  );
}
