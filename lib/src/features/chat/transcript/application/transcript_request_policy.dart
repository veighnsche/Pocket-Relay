import 'package:pocket_relay/src/core/utils/monotonic_clock.dart';
import 'package:pocket_relay/src/features/chat/requests/domain/codex_request_display.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_policy_support.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';

part 'transcript_request_policy_approval.dart';
part 'transcript_request_policy_support.dart';
part 'transcript_request_policy_user_input.dart';

class TranscriptRequestPolicy {
  const TranscriptRequestPolicy({
    TranscriptPolicySupport support = const TranscriptPolicySupport(),
  }) : _support = support;

  final TranscriptPolicySupport _support;

  CodexSessionState applyRequestOpened(
    CodexSessionState state,
    CodexRuntimeRequestOpenedEvent event,
  ) => _applyRequestOpened(this, state, event);

  CodexSessionState applyRequestResolved(
    CodexSessionState state,
    CodexRuntimeRequestResolvedEvent event,
  ) => _applyRequestResolved(this, state, event);

  CodexSessionState applyUserInputRequested(
    CodexSessionState state,
    CodexRuntimeUserInputRequestedEvent event,
  ) => _applyUserInputRequested(this, state, event);

  CodexSessionState applyUserInputResolved(
    CodexSessionState state,
    CodexRuntimeUserInputResolvedEvent event,
  ) => _applyUserInputResolved(this, state, event);
}
