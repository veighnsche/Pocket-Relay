import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_app_chrome.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_composer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/empty_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_screen_shell.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/transcript_list.dart';

class FlutterChatScreenRenderer extends StatelessWidget {
  const FlutterChatScreenRenderer({
    super.key,
    required this.screen,
    required this.appChrome,
    required this.transcriptRegion,
    required this.composerRegion,
  });

  final ChatScreenContract screen;
  final PreferredSizeWidget appChrome;
  final Widget transcriptRegion;
  final Widget composerRegion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appChrome,
      body: ChatScreenGradientBackground(
        child: ChatScreenBody(
          screen: screen,
          transcriptRegion: transcriptRegion,
          composerRegion: composerRegion,
          loadingIndicator: const CircularProgressIndicator(),
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
  });

  final ChatScreenContract screen;
  final ValueChanged<ChatScreenActionId> onScreenAction;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 18,
      title: ChatAppChromeTitle(
        header: screen.header,
        style: ChatAppChromeStyle.material,
      ),
      actions: [
        ...screen.toolbarActions.map(
          (action) => IconButton(
            tooltip: action.tooltip,
            onPressed: () => onScreenAction(action.id),
            icon: Icon(
              chatActionIcon(action, style: ChatAppChromeStyle.material),
            ),
          ),
        ),
        if (screen.menuActions.isNotEmpty) ...[
          ChatOverflowMenuButton(
            actions: screen.menuActions,
            onSelected: onScreenAction,
            style: ChatAppChromeStyle.material,
          ),
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
    required this.onScreenAction,
    required this.onSelectConnectionMode,
    required this.onAutoFollowEligibilityChanged,
    this.emptyStateRenderer = ChatEmptyStateRenderer.flutter,
    this.surfaceChangeToken,
    this.onOpenChangedFileDiff,
    this.onApproveRequest,
    this.onDenyRequest,
    this.onSubmitUserInput,
    this.onSaveHostFingerprint,
  });

  final ChatScreenContract screen;
  final ValueChanged<ChatScreenActionId> onScreenAction;
  final ValueChanged<ConnectionMode> onSelectConnectionMode;
  final ValueChanged<bool> onAutoFollowEligibilityChanged;
  final ChatEmptyStateRenderer emptyStateRenderer;
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

  @override
  Widget build(BuildContext context) {
    return TranscriptList(
      surface: screen.transcriptSurface,
      followBehavior: screen.transcriptFollow,
      surfaceChangeToken: surfaceChangeToken,
      onConfigure: () {
        onScreenAction(ChatScreenActionId.openSettings);
      },
      onSelectConnectionMode: onSelectConnectionMode,
      onAutoFollowEligibilityChanged: onAutoFollowEligibilityChanged,
      emptyStateRenderer: emptyStateRenderer,
      onApproveRequest: onApproveRequest,
      onDenyRequest: onDenyRequest,
      onOpenChangedFileDiff: onOpenChangedFileDiff,
      onSubmitUserInput: onSubmitUserInput,
      onSaveHostFingerprint: onSaveHostFingerprint,
    );
  }
}

class FlutterChatComposerRegion extends StatelessWidget {
  const FlutterChatComposerRegion({
    super.key,
    required this.composer,
    required this.onComposerDraftChanged,
    required this.onSendPrompt,
    required this.onStopActiveTurn,
  });

  final ChatComposerContract composer;
  final ValueChanged<String> onComposerDraftChanged;
  final Future<void> Function() onSendPrompt;
  final Future<void> Function() onStopActiveTurn;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: ChatComposer(
          contract: composer,
          onChanged: onComposerDraftChanged,
          onSend: onSendPrompt,
          onStop: onStopActiveTurn,
        ),
      ),
    );
  }
}
