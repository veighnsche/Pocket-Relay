part of 'transcript_item_policy.dart';

TranscriptSessionState _applyItemLifecycle(
  TranscriptItemPolicy policy,
  TranscriptSessionState state,
  TranscriptRuntimeItemLifecycleEvent event, {
  required bool removeAfterUpsert,
}) {
  final activeTurn = policy._support.ensureActiveTurn(
    state.activeTurn,
    turnId: event.turnId,
    threadId: event.threadId,
    createdAt: event.createdAt,
  );
  final existing = activeTurn?.itemsById[event.itemId!];
  final nextItem = _activeItemFromLifecycle(
    policy,
    state,
    activeTurn,
    event,
    existing: existing,
  );
  final suppressedState = _suppressedLocalUserMessageState(
    policy,
    state,
    activeTurn,
    nextItem,
  );
  if (suppressedState != null) {
    return suppressedState;
  }

  return state.copyWithProjectedTranscript(
    activeTurn: _nextActiveTurnForLifecycle(
      policy,
      activeTurn,
      nextItem,
      removeAfterUpsert: removeAfterUpsert,
    ),
  );
}

TranscriptSessionActiveItem _activeItemFromLifecycle(
  TranscriptItemPolicy policy,
  TranscriptSessionState state,
  TranscriptActiveTurnState? activeTurn,
  TranscriptRuntimeItemLifecycleEvent event, {
  TranscriptSessionActiveItem? existing,
}) {
  final blockKind = policy._blockFactory.blockKindForItemType(event.itemType);
  final title = _itemTitle(policy, event, existing?.title);
  final aggregatedBody = _itemBody(
    policy,
    event,
    existing?.aggregatedBody ?? '',
  );
  final exitCode = _extractExitCode(event.snapshot) ?? existing?.exitCode;
  final forkArtifact = _shouldForkVisibleArtifact(
    activeTurn,
    existing,
    itemType: event.itemType,
  );
  final entryId = existing == null || forkArtifact
      ? _nextItemEntryId(policy, state, activeTurn, itemId: event.itemId!)
      : existing.entryId;
  final artifactBaseBody = existing == null
      ? ''
      : (forkArtifact ? existing.aggregatedBody : existing.artifactBaseBody);
  final body = _visibleBodyForArtifact(
    aggregatedBody,
    artifactBaseBody: artifactBaseBody,
    fallbackToFullBody:
        forkArtifact && event.status != TranscriptRuntimeItemStatus.inProgress,
  );
  return TranscriptSessionActiveItem(
    itemId: event.itemId!,
    threadId: event.threadId!,
    turnId: event.turnId!,
    itemType: event.itemType,
    entryId: entryId,
    blockKind: blockKind,
    createdAt: existing == null || forkArtifact
        ? event.createdAt
        : existing.createdAt,
    title: title,
    body: body,
    aggregatedBody: aggregatedBody,
    artifactBaseBody: artifactBaseBody,
    isRunning: event.status == TranscriptRuntimeItemStatus.inProgress,
    exitCode: exitCode,
    snapshot: _nextLifecycleSnapshot(event, existing?.snapshot),
  );
}

Map<String, dynamic>? _nextLifecycleSnapshot(
  TranscriptRuntimeItemLifecycleEvent event,
  Map<String, dynamic>? existingSnapshot,
) {
  final eventSnapshot = event.snapshot;
  if (eventSnapshot == null) {
    return existingSnapshot;
  }

  if (event.itemType == TranscriptCanonicalItemType.commandExecution &&
      existingSnapshot != null &&
      event.rawMethod == 'item/commandExecution/terminalInteraction') {
    return <String, dynamic>{...existingSnapshot, ...eventSnapshot};
  }

  return eventSnapshot;
}

String _itemTitle(
  TranscriptItemPolicy policy,
  TranscriptRuntimeItemLifecycleEvent event,
  String? existingTitle,
) {
  if (event.itemType == TranscriptCanonicalItemType.commandExecution) {
    final rawTitle = _commandExecutionRawTitle(policy, event, existingTitle);
    return policy._blockFactory.normalizeCommandExecutionTitle(rawTitle);
  }
  return existingTitle ??
      event.title ??
      policy._blockFactory.defaultItemTitle(event.itemType);
}

String _commandExecutionRawTitle(
  TranscriptItemPolicy policy,
  TranscriptRuntimeItemLifecycleEvent event,
  String? existingTitle,
) {
  final snapshot = event.snapshot;
  final snapshotCommand = policy._support.stringFromCandidates(<Object?>[
    snapshot?['command'],
    (snapshot?['result'] as Map?)?['command'],
  ]);
  if (snapshotCommand != null) {
    return snapshotCommand;
  }
  if (_meaningfulCommandExecutionTitle(policy, event.title) case final title?) {
    return title;
  }

  final detail = event.detail;
  if (event.rawMethod != 'item/commandExecution/terminalInteraction' &&
      detail?.trim().isNotEmpty == true) {
    return detail!;
  }
  if (_meaningfulCommandExecutionTitle(policy, existingTitle)
      case final existingTitle?) {
    return existingTitle;
  }
  return 'Command';
}

String? _meaningfulCommandExecutionTitle(
  TranscriptItemPolicy policy,
  String? value,
) {
  if (value == null) {
    return null;
  }
  final trimmed = value.trim();
  if (trimmed.isEmpty ||
      trimmed ==
          policy._blockFactory.defaultItemTitle(
            TranscriptCanonicalItemType.commandExecution,
          )) {
    return null;
  }
  return value;
}

String _itemBody(
  TranscriptItemPolicy policy,
  TranscriptRuntimeItemLifecycleEvent event,
  String currentBody,
) {
  final snapshotText = policy._itemSupport.extractTextFromSnapshot(
    event.snapshot,
  );
  if (event.itemType == TranscriptCanonicalItemType.commandExecution) {
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

  final body = policy._support.stringFromCandidates(<Object?>[
    snapshotText,
    event.detail,
  ]);
  if (body != null && body.isNotEmpty) {
    return body;
  }
  if (currentBody.isNotEmpty) {
    return currentBody;
  }
  return policy._itemSupport.defaultLifecycleBody(event.itemType) ??
      currentBody;
}

TranscriptActiveTurnState? _nextActiveTurnForLifecycle(
  TranscriptItemPolicy policy,
  TranscriptActiveTurnState? activeTurn,
  TranscriptSessionActiveItem item, {
  required bool removeAfterUpsert,
}) {
  if (activeTurn == null || activeTurn.turnId != item.turnId) {
    return activeTurn;
  }

  final nextItems = <String, TranscriptSessionActiveItem>{
    ...activeTurn.itemsById,
    item.itemId: item,
  };
  if (removeAfterUpsert) {
    nextItems.remove(item.itemId);
  }

  return policy._turnArtifactBuilder.upsertItem(
    activeTurn.copyWith(itemsById: nextItems),
    item,
  );
}
