import 'package:pocket_relay/src/core/utils/monotonic_clock.dart';
import 'package:pocket_relay/src/features/chat/requests/domain/codex_request_display.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_policy_support.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';

part 'transcript_request_policy_approval.dart';
part 'transcript_request_policy_support_active_turn.dart';
part 'transcript_request_policy_support_resolution.dart';
part 'transcript_request_policy_user_input.dart';

class TranscriptRequestPolicy {
  const TranscriptRequestPolicy({
    TranscriptPolicySupport support = const TranscriptPolicySupport(),
  }) : _support = support;

  final TranscriptPolicySupport _support;

  TranscriptSessionState applyRequestOpened(
    TranscriptSessionState state,
    TranscriptRuntimeRequestOpenedEvent event,
  ) => _applyRequestOpened(this, state, event);

  TranscriptSessionState applyRequestResolved(
    TranscriptSessionState state,
    TranscriptRuntimeRequestResolvedEvent event,
  ) => _applyRequestResolved(this, state, event);

  TranscriptSessionState applyUserInputRequested(
    TranscriptSessionState state,
    TranscriptRuntimeUserInputRequestedEvent event,
  ) => _applyUserInputRequested(this, state, event);

  TranscriptSessionState applyUserInputResolved(
    TranscriptSessionState state,
    TranscriptRuntimeUserInputResolvedEvent event,
  ) => _applyUserInputResolved(this, state, event);
}
