import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_item_block_factory.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_item_support.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_policy_support.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_turn_segmenter.dart';
import 'package:pocket_relay/src/features/chat/composer/domain/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';

part 'transcript_item_policy_delta.dart';
part 'transcript_item_policy_lifecycle.dart';
part 'transcript_item_policy_support.dart';

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

  TranscriptSessionState applyItemLifecycle(
    TranscriptSessionState state,
    TranscriptRuntimeItemLifecycleEvent event, {
    required bool removeAfterUpsert,
  }) => _applyItemLifecycle(
    this,
    state,
    event,
    removeAfterUpsert: removeAfterUpsert,
  );

  TranscriptSessionState applyContentDelta(
    TranscriptSessionState state,
    TranscriptRuntimeContentDeltaEvent event,
  ) => _applyContentDelta(this, state, event);
}
