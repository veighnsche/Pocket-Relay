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
    TranscriptTurnSegmenter turnSegmenter = const TranscriptTurnSegmenter(),
  }) : _support = support,
       _blockFactory = blockFactory,
       _itemSupport = itemSupport,
       _turnSegmenter = turnSegmenter;

  final TranscriptPolicySupport _support;
  final TranscriptItemBlockFactory _blockFactory;
  final TranscriptItemSupport _itemSupport;
  final TranscriptTurnSegmenter _turnSegmenter;

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
    final existing =
        activeTurn?.itemsById[event.itemId!] ??
        state.activeItems[event.itemId!];
    final nextItem = _activeItemFromLifecycle(event, existing: existing);
    final shouldSuppress = _shouldSuppressItemSegment(state, nextItem);
    return state.copyWith(
      activeTurn: shouldSuppress
          ? _nextActiveTurnForSuppressedLifecycle(
              activeTurn,
              nextItem,
              removeAfterUpsert: removeAfterUpsert,
            )
          : _nextActiveTurnForLifecycle(
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
    final existing =
        activeTurn?.itemsById[itemId] ?? _activeItemFromContentDelta(event);
    final updatedItem = existing.copyWith(
      body: '${existing.body}${event.delta}',
      isRunning: true,
    );

    return state.copyWith(
      activeTurn: _nextActiveTurnForContentDelta(activeTurn, updatedItem),
    );
  }

  CodexSessionActiveItem _activeItemFromLifecycle(
    CodexRuntimeItemLifecycleEvent event, {
    CodexSessionActiveItem? existing,
  }) {
    final blockKind = _blockFactory.blockKindForItemType(event.itemType);
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
    final itemType = _itemSupport.itemTypeFromStreamKind(event.streamKind);
    return CodexSessionActiveItem(
      itemId: event.itemId!,
      threadId: event.threadId!,
      turnId: event.turnId!,
      itemType: itemType,
      entryId: 'item_${event.itemId}',
      blockKind: _blockFactory.blockKindForItemType(itemType),
      createdAt: event.createdAt,
      title: _blockFactory.defaultItemTitle(itemType),
      body: '',
      isRunning: true,
      snapshot: null,
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

  bool _shouldSuppressItemSegment(
    CodexSessionState state,
    CodexSessionActiveItem item,
  ) {
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

  CodexActiveTurnState? _nextActiveTurnForSuppressedLifecycle(
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

    return activeTurn.copyWith(itemsById: nextItems);
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

    return _turnSegmenter.upsertItem(
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

    return _turnSegmenter.upsertItem(
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
