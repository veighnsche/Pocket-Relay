import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft_host.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_pending_request_placement_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_pending_request_placement_projector.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_contract.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_projector.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_effect.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_effect_mapper.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_presenter.dart';
import 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_host.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_projector.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_surface_projector.dart';
import 'package:pocket_relay/src/features/chat/worklog/domain/chat_work_log_contract.dart';

export 'package:flutter_test/flutter_test.dart';
export 'package:pocket_relay/src/core/models/connection_models.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
export 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
export 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';
export 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft_host.dart';
export 'package:pocket_relay/src/features/chat/transcript/presentation/chat_pending_request_placement_contract.dart';
export 'package:pocket_relay/src/features/chat/transcript/presentation/chat_pending_request_placement_projector.dart';
export 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_contract.dart';
export 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_projector.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_effect.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_effect_mapper.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_presenter.dart';
export 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_contract.dart';
export 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_host.dart';
export 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
export 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_projector.dart';
export 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_surface_projector.dart';
export 'package:pocket_relay/src/features/chat/worklog/domain/chat_work_log_contract.dart';

const defaultTranscriptFollowContract = ChatTranscriptFollowContract(
  isAutoFollowEnabled: true,
  resumeDistance: ChatTranscriptFollowHost.defaultResumeDistance,
);

ConnectionProfile configuredProfile() {
  return ConnectionProfile.defaults().copyWith(
    label: 'Dev Box',
    host: 'devbox.local',
    username: 'vince',
    workspaceDir: '/workspace',
    codexPath: 'codex',
  );
}

class FakePendingRequestPlacementProjector
    extends ChatPendingRequestPlacementProjector {
  const FakePendingRequestPlacementProjector({required this.placement});

  final ChatPendingRequestPlacementContract placement;

  @override
  ChatPendingRequestPlacementContract project({
    required Map<String, CodexSessionPendingRequest> pendingApprovalRequests,
    required Map<String, CodexSessionPendingUserInputRequest>
    pendingUserInputRequests,
  }) {
    return placement;
  }
}
