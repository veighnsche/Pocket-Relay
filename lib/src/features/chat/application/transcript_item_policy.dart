import 'package:pocket_relay/src/features/chat/application/transcript_item_block_factory.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_item_support.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_policy_support.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

class TranscriptItemPolicy {
  const TranscriptItemPolicy({
    TranscriptPolicySupport support = const TranscriptPolicySupport(),
    TranscriptItemBlockFactory blockFactory =
        const TranscriptItemBlockFactory(),
    TranscriptItemSupport itemSupport = const TranscriptItemSupport(),
  }) : _support = support,
       _blockFactory = blockFactory,
       _itemSupport = itemSupport;

  final TranscriptPolicySupport _support;
  final TranscriptItemBlockFactory _blockFactory;
  final TranscriptItemSupport _itemSupport;

  CodexSessionState applyItemLifecycle(
    CodexSessionState state,
    CodexRuntimeItemLifecycleEvent event, {
    required bool removeAfterUpsert,
  }) {
    final existing = state.activeItems[event.itemId!];
    final nextItem = _activeItemFromLifecycle(event, existing: existing);
    final nextBlock = _blockFactory.blockFromActiveItem(nextItem);
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

    return _support.upsertBlock(nextState, nextBlock);
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

    final existing =
        state.activeItems[itemId] ?? _activeItemFromContentDelta(event);
    final updatedItem = existing.copyWith(
      body: '${existing.body}${event.delta}',
      isRunning: true,
    );

    return _support.upsertBlock(
      state.copyWith(
        activeItems: <String, CodexSessionActiveItem>{
          ...state.activeItems,
          itemId: updatedItem,
        },
      ),
      _blockFactory.blockFromActiveItem(updatedItem),
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

  int? _extractExitCode(Map<String, dynamic>? snapshot) {
    final value = snapshot?['exitCode'] ?? snapshot?['exit_code'];
    return value is num ? value.toInt() : null;
  }
}
