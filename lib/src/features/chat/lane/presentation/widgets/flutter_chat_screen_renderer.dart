import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_chrome_menu_action.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/chat_app_chrome.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/chat_screen_shell.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/transcript_list.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';

part 'flutter_chat_screen_renderer_composer.dart';
part 'flutter_chat_screen_renderer_timeline.dart';

class FlutterChatScreenRenderer extends StatelessWidget {
  const FlutterChatScreenRenderer({
    super.key,
    required this.platformBehavior,
    required this.screen,
    required this.appChrome,
    required this.transcriptRegion,
    required this.composerRegion,
    required this.onStopActiveTurn,
    this.laneRestartAction,
    this.onRestartLane,
  });

  final PocketPlatformBehavior platformBehavior;
  final ChatScreenContract screen;
  final PreferredSizeWidget appChrome;
  final Widget transcriptRegion;
  final Widget composerRegion;
  final Future<void> Function() onStopActiveTurn;
  final ChatLaneRestartActionContract? laneRestartAction;
  final Future<void> Function()? onRestartLane;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appChrome,
      body: ChatScreenGradientBackground(
        child: ChatScreenBody(
          platformBehavior: platformBehavior,
          screen: screen,
          transcriptRegion: transcriptRegion,
          composerRegion: composerRegion,
          loadingIndicator: const CircularProgressIndicator(),
          onStopActiveTurn: onStopActiveTurn,
          laneRestartAction: laneRestartAction,
          onRestartLane: onRestartLane,
        ),
      ),
    );
  }
}

class FlutterChatAppChrome extends StatelessWidget
    implements PreferredSizeWidget {
  const FlutterChatAppChrome({
    super.key,
    required this.screen,
    required this.onScreenAction,
    this.supplementalMenuActions = const <ChatChromeMenuAction>[],
  });

  final ChatScreenContract screen;
  final ValueChanged<ChatScreenActionId> onScreenAction;
  final List<ChatChromeMenuAction> supplementalMenuActions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final menuActions = buildChatChromeMenuActions(
      screen: screen,
      onScreenAction: onScreenAction,
      supplementalMenuActions: supplementalMenuActions,
    );

    return AppBar(
      titleSpacing: 18,
      title: ChatAppChromeTitle(header: screen.header),
      actions: [
        ...screen.toolbarActions.map(
          (action) => IconButton(
            tooltip: action.tooltip,
            onPressed: () => onScreenAction(action.id),
            icon: Icon(chatActionIcon(action)),
          ),
        ),
        if (menuActions.isNotEmpty) ...[
          ChatOverflowMenuButton(actions: menuActions),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class FlutterChatTranscriptRegion extends StatelessWidget {
  const FlutterChatTranscriptRegion({
    super.key,
    required this.screen,
    required this.platformBehavior,
    required this.onScreenAction,
    required this.onSelectTimeline,
    required this.onSelectConnectionMode,
    required this.onAutoFollowEligibilityChanged,
    this.surfaceChangeToken,
    this.onOpenChangedFileDiff,
    this.onApproveRequest,
    this.onDenyRequest,
    this.onSubmitUserInput,
    this.onSaveHostFingerprint,
    this.onContinueFromUserMessage,
  });

  final ChatScreenContract screen;
  final PocketPlatformBehavior platformBehavior;
  final ValueChanged<ChatScreenActionId> onScreenAction;
  final ValueChanged<String> onSelectTimeline;
  final ValueChanged<ConnectionMode> onSelectConnectionMode;
  final ValueChanged<bool> onAutoFollowEligibilityChanged;
  final Object? surfaceChangeToken;
  final void Function(ChatChangedFileDiffContract diff)? onOpenChangedFileDiff;
  final Future<void> Function(String requestId)? onApproveRequest;
  final Future<void> Function(String requestId)? onDenyRequest;
  final Future<void> Function(
    String requestId,
    Map<String, List<String>> answers,
  )?
  onSubmitUserInput;
  final Future<void> Function(String blockId)? onSaveHostFingerprint;
  final Future<void> Function(String blockId)? onContinueFromUserMessage;

  @override
  Widget build(BuildContext context) {
    final transcriptList = TranscriptList(
      surface: screen.transcriptSurface,
      followBehavior: screen.transcriptFollow,
      platformBehavior: platformBehavior,
      surfaceChangeToken: surfaceChangeToken,
      onConfigure: () {
        onScreenAction(ChatScreenActionId.openSettings);
      },
      onSelectConnectionMode: onSelectConnectionMode,
      onAutoFollowEligibilityChanged: onAutoFollowEligibilityChanged,
      onApproveRequest: onApproveRequest,
      onDenyRequest: onDenyRequest,
      onOpenChangedFileDiff: onOpenChangedFileDiff,
      onSubmitUserInput: onSubmitUserInput,
      onSaveHostFingerprint: onSaveHostFingerprint,
      onContinueFromUserMessage: onContinueFromUserMessage,
    );
    if (screen.timelineSummaries.length <= 1) {
      return transcriptList;
    }

    return Column(
      children: [
        _TimelineSelector(
          timelines: screen.timelineSummaries,
          onSelectTimeline: onSelectTimeline,
        ),
        Expanded(child: transcriptList),
      ],
    );
  }
}
