import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_pending_request_placement_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_chrome_menu_action.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/flutter_chat_screen_renderer.dart';

export 'package:flutter/material.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:pocket_relay/src/core/models/connection_models.dart';
export 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
export 'package:pocket_relay/src/core/theme/pocket_theme.dart';
export 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
export 'package:pocket_relay/src/features/chat/transcript/presentation/chat_pending_request_placement_contract.dart';
export 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
export 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_contract.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/chat_chrome_menu_action.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/widgets/flutter_chat_screen_renderer.dart';

ChatScreenContract screenContract({
  bool isConfigured = true,
  ChatEmptyStateContract? emptyState,
  List<ChatTranscriptItemContract> mainItems =
      const <ChatTranscriptItemContract>[],
  List<ChatTranscriptItemContract> pinnedItems =
      const <ChatTranscriptItemContract>[],
  List<ChatTimelineSummaryContract> timelineSummaries =
      const <ChatTimelineSummaryContract>[],
  ChatTurnIndicatorContract? turnIndicator,
}) {
  return ChatScreenContract(
    isLoading: false,
    header: const ChatHeaderContract(
      title: 'Pocket Relay',
      subtitle: 'Dev Box · devbox.local',
    ),
    actions: const <ChatScreenActionContract>[
      ChatScreenActionContract(
        id: ChatScreenActionId.openSettings,
        label: 'Connection settings',
        placement: ChatScreenActionPlacement.toolbar,
        tooltip: 'Connection settings',
        icon: ChatScreenActionIcon.settings,
      ),
      ChatScreenActionContract(
        id: ChatScreenActionId.newThread,
        label: 'New thread',
        placement: ChatScreenActionPlacement.menu,
      ),
      ChatScreenActionContract(
        id: ChatScreenActionId.branchConversation,
        label: 'Branch conversation',
        placement: ChatScreenActionPlacement.menu,
      ),
    ],
    timelineSummaries: timelineSummaries,
    transcriptSurface: ChatTranscriptSurfaceContract(
      isConfigured: isConfigured,
      mainItems: mainItems,
      pinnedItems: pinnedItems,
      pendingRequestPlacement: ChatPendingRequestPlacementContract(
        visibleApprovalRequest: null,
        visibleUserInputRequest: null,
      ),
      activePendingUserInputRequestIds: const <String>{},
      emptyState: emptyState,
    ),
    transcriptFollow: const ChatTranscriptFollowContract(
      isAutoFollowEnabled: true,
      resumeDistance: 80,
    ),
    composer: const ChatComposerContract(
      draft: ChatComposerDraft(),
      isSendActionEnabled: true,
      placeholder: 'Message Codex',
    ),
    connectionSettings: ChatConnectionSettingsLaunchContract(
      initialProfile: ConnectionProfile.defaults(),
      initialSecrets: const ConnectionSecrets(),
    ),
    turnIndicator: turnIndicator,
  );
}

class TestAppChrome extends StatelessWidget implements PreferredSizeWidget {
  const TestAppChrome();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('Injected chrome'));
  }
}
