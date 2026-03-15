import 'package:pocket_relay/src/features/chat/application/transcript_item_block_factory.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_item_support.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_policy_support.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_turn_segmenter.dart';
import 'package:pocket_relay/src/core/utils/monotonic_clock.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

class TranscriptItemPolicy {
  const TranscriptItemPolicy({
    TranscriptPolicySupport support = const TranscriptPolicySupport(),
    TranscriptItemBlockFactory blockFactory =
        const TranscriptItemBlockFactory(),
    TranscriptItemSupport itemSupport = const TranscriptItemSupport(),
    TranscriptTurnArtifactBuilder turnArtifactBuilder =
        const TranscriptTurnArtifactBuilder(),
  }) : _support = support,
       _blockFactory = blockFactory,
       _itemSupport = itemSupport,
       _turnArtifactBuilder = turnArtifactBuilder;

  final TranscriptPolicySupport _support;
  final TranscriptItemBlockFactory _blockFactory;
  final TranscriptItemSupport _itemSupport;
  final TranscriptTurnArtifactBuilder _turnArtifactBuilder;

  CodexSessionState applyItemLifecycle(
    CodexSessionState state,
    CodexRuntimeItemLifecycleEvent event, {
    required bool removeAfterUpsert,
  }) {
    final activeTurn = _ensureActiveTurn(
      state.activeTurn,
      turnId: event.turnId,
      threadId: event.threadId,
      createdAt: event.createdAt,
    );
    final existing = activeTurn?.itemsById[event.itemId!];
    final nextItem = _activeItemFromLifecycle(
      state,
      activeTurn,
      event,
      existing: existing,
    );
    final suppressedState = _suppressedLocalUserMessageState(
      state,
      activeTurn,
      nextItem,
    );
    if (suppressedState != null) {
      return suppressedState;
    }

    return state.copyWith(
      activeTurn: _nextActiveTurnForLifecycle(
        activeTurn,
        nextItem,
        removeAfterUpsert: removeAfterUpsert,
      ),
    );
  }

  CodexSessionState applyContentDelta(
    CodexSessionState state,
    CodexRuntimeContentDeltaEvent event,
  ) {
    final itemId = event.itemId;
    final threadId = event.threadId;
    final turnId = event.turnId;
    if (itemId == null || threadId == null || turnId == null) {
      return state;
    }

    final activeTurn = _ensureActiveTurn(
      state.activeTurn,
      turnId: turnId,
      threadId: threadId,
      createdAt: event.createdAt,
    );
    final existing = activeTurn?.itemsById[itemId];
    final updatedItem = _activeItemFromContentDelta(
      state,
      activeTurn,
      event,
      existing: existing,
    );

    return state.copyWith(
      activeTurn: _nextActiveTurnForContentDelta(activeTurn, updatedItem),
    );
  }

  CodexSessionActiveItem _activeItemFromLifecycle(
    CodexSessionState state,
    CodexActiveTurnState? activeTurn,
    CodexRuntimeItemLifecycleEvent event, {
    CodexSessionActiveItem? existing,
  }) {
    final blockKind = _blockFactory.blockKindForItemType(event.itemType);
    final title = _itemTitle(event, existing?.title);
    final aggregatedBody = _itemBody(event, existing?.aggregatedBody ?? '');
    final exitCode = _extractExitCode(event.snapshot) ?? existing?.exitCode;
    final forkArtifact = _shouldForkVisibleArtifact(activeTurn, existing);
    final entryId = existing == null || forkArtifact
        ? _nextItemEntryId(state, activeTurn, itemId: event.itemId!)
        : existing.entryId;
    final artifactBaseBody = existing == null
        ? ''
        : (forkArtifact ? existing.aggregatedBody : existing.artifactBaseBody);
    final body = _visibleBodyForArtifact(
      aggregatedBody,
      artifactBaseBody: artifactBaseBody,
      fallbackToFullBody:
          forkArtifact && event.status != CodexRuntimeItemStatus.inProgress,
    );
    return CodexSessionActiveItem(
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
      isRunning: event.status == CodexRuntimeItemStatus.inProgress,
      exitCode: exitCode,
      snapshot: event.snapshot ?? existing?.snapshot,
    );
  }

  CodexSessionActiveItem _activeItemFromContentDelta(
    CodexSessionState state,
    CodexActiveTurnState? activeTurn,
    CodexRuntimeContentDeltaEvent event, {
    CodexSessionActiveItem? existing,
  }) {
    final itemType =
        existing?.itemType ??
        _itemSupport.itemTypeFromStreamKind(event.streamKind);
    final forkArtifact = _shouldForkVisibleArtifact(activeTurn, existing);
    final previousAggregatedBody = existing?.aggregatedBody ?? '';
    final aggregatedBody = '$previousAggregatedBody${event.delta}';
    final artifactBaseBody = existing == null
        ? ''
        : (forkArtifact ? previousAggregatedBody : existing.artifactBaseBody);
    return CodexSessionActiveItem(
      itemId: event.itemId!,
      threadId: event.threadId!,
      turnId: event.turnId!,
      itemType: itemType,
      entryId: existing == null || forkArtifact
          ? _nextItemEntryId(state, activeTurn, itemId: event.itemId!)
          : existing.entryId,
      blockKind:
          existing?.blockKind ?? _blockFactory.blockKindForItemType(itemType),
      createdAt: existing == null || forkArtifact
          ? event.createdAt
          : existing.createdAt,
      title: existing?.title ?? _blockFactory.defaultItemTitle(itemType),
      body: _visibleBodyForArtifact(
        aggregatedBody,
        artifactBaseBody: artifactBaseBody,
      ),
      aggregatedBody: aggregatedBody,
      artifactBaseBody: artifactBaseBody,
      isRunning: true,
      exitCode: existing?.exitCode,
      snapshot: existing?.snapshot,
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
    return existingTitle ??
        event.title ??
        _blockFactory.defaultItemTitle(event.itemType);
  }

  String _itemBody(CodexRuntimeItemLifecycleEvent event, String currentBody) {
    final snapshotText = _itemSupport.extractTextFromSnapshot(event.snapshot);
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

    final body = _support.stringFromCandidates(<Object?>[
      snapshotText,
      event.detail,
    ]);
    if (body != null && body.isNotEmpty) {
      return body;
    }
    if (currentBody.isNotEmpty) {
      return currentBody;
    }
    return _itemSupport.defaultLifecycleBody(event.itemType) ?? currentBody;
  }

  int? _extractExitCode(Map<String, dynamic>? snapshot) {
    final value = snapshot?['exitCode'] ?? snapshot?['exit_code'];
    return value is num ? value.toInt() : null;
  }

  bool _shouldForkVisibleArtifact(
    CodexActiveTurnState? activeTurn,
    CodexSessionActiveItem? existing,
  ) {
    if (activeTurn == null ||
        existing == null ||
        activeTurn.artifacts.isEmpty) {
      return false;
    }

    final currentArtifactId = activeTurn.itemArtifactIds[existing.itemId];
    if (currentArtifactId == null) {
      return false;
    }

    return activeTurn.artifacts.last.id != currentArtifactId;
  }

  String _nextItemEntryId(
    CodexSessionState state,
    CodexActiveTurnState? activeTurn, {
    required String itemId,
  }) {
    final usedIds = <String>{
      ...codexUiBlockIds(state.blocks),
      if (activeTurn != null) ...codexTurnArtifactIds(activeTurn.artifacts),
    };
    final baseId = 'item_$itemId';
    if (!usedIds.contains(baseId)) {
      return baseId;
    }

    var ordinal = 2;
    var candidate = '$baseId-$ordinal';
    while (usedIds.contains(candidate)) {
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

  CodexSessionState? _suppressedLocalUserMessageState(
    CodexSessionState state,
    CodexActiveTurnState? activeTurn,
    CodexSessionActiveItem item,
  ) {
    if (item.itemType != CodexCanonicalItemType.userMessage) {
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

    final text = item.body.trim();
    if (text.isEmpty) {
      return null;
    }

    final pendingMatch = _matchingPendingLocalUserMessage(
      state.blocks,
      state.pendingLocalUserMessageBlockIds,
      text: text,
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

  CodexSessionState _stateAfterSuppressedLocalUserMessage(
    CodexSessionState state, {
    required CodexActiveTurnState? activeTurn,
    required String itemId,
    List<String>? pendingLocalUserMessageBlockIds,
    Map<String, String>? localUserMessageProviderBindings,
  }) {
    return state.copyWith(
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

  CodexUserMessageBlock? _userMessageBlockById(
    List<CodexUiBlock> blocks,
    String blockId,
  ) {
    for (final block in blocks.reversed) {
      if (block is CodexUserMessageBlock && block.id == blockId) {
        return block;
      }
    }
    return null;
  }

  (CodexUserMessageBlock, List<String>)? _matchingPendingLocalUserMessage(
    List<CodexUiBlock> blocks,
    List<String> pendingBlockIds, {
    required String text,
  }) {
    final nextPendingBlockIds = <String>[];

    for (var index = 0; index < pendingBlockIds.length; index += 1) {
      final blockId = pendingBlockIds[index];
      final block = _userMessageBlockById(blocks, blockId);
      if (block == null) {
        continue;
      }
      if (block.text.trim() == text) {
        nextPendingBlockIds.addAll(pendingBlockIds.skip(index + 1));
        return (block, nextPendingBlockIds);
      }
      nextPendingBlockIds.add(blockId);
    }

    return null;
  }

  CodexActiveTurnState? _activeTurnAfterSuppressedLocalUserMessage(
    CodexActiveTurnState? activeTurn, {
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

    final nextItems = <String, CodexSessionActiveItem>{...activeTurn.itemsById}
      ..remove(itemId);
    final nextArtifactIds = <String, String>{...activeTurn.itemArtifactIds}
      ..remove(itemId);

    return activeTurn.copyWith(
      itemsById: nextItems,
      itemArtifactIds: nextArtifactIds,
    );
  }

  CodexActiveTurnState? _nextActiveTurnForLifecycle(
    CodexActiveTurnState? activeTurn,
    CodexSessionActiveItem item, {
    required bool removeAfterUpsert,
  }) {
    if (activeTurn == null || activeTurn.turnId != item.turnId) {
      return activeTurn;
    }

    final nextItems = <String, CodexSessionActiveItem>{
      ...activeTurn.itemsById,
      item.itemId: item,
    };
    if (removeAfterUpsert) {
      nextItems.remove(item.itemId);
    }

    return _turnArtifactBuilder.upsertItem(
      activeTurn.copyWith(itemsById: nextItems),
      item,
    );
  }

  CodexActiveTurnState? _nextActiveTurnForContentDelta(
    CodexActiveTurnState? activeTurn,
    CodexSessionActiveItem item,
  ) {
    if (activeTurn == null || activeTurn.turnId != item.turnId) {
      return activeTurn;
    }

    return _turnArtifactBuilder.upsertItem(
      activeTurn.copyWith(
        itemsById: <String, CodexSessionActiveItem>{
          ...activeTurn.itemsById,
          item.itemId: item,
        },
      ),
      item,
    );
  }

  CodexActiveTurnState? _ensureActiveTurn(
    CodexActiveTurnState? activeTurn, {
    required String? turnId,
    required String? threadId,
    required DateTime createdAt,
  }) {
    if (activeTurn != null || turnId == null) {
      return activeTurn;
    }

    return CodexActiveTurnState(
      turnId: turnId,
      threadId: threadId,
      timer: CodexSessionTurnTimer(
        turnId: turnId,
        startedAt: createdAt,
        activeSegmentStartedMonotonicAt: CodexMonotonicClock.now(),
      ),
    );
  }
}
