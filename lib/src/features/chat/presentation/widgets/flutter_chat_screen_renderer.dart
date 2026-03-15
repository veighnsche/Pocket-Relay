import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_composer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/empty_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/turn_elapsed_footer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/transcript_list.dart';

class FlutterChatScreenRenderer extends StatelessWidget {
  const FlutterChatScreenRenderer({
    super.key,
    required this.screen,
    this.onScreenAction,
    this.onAutoFollowEligibilityChanged,
    this.onComposerDraftChanged,
    this.onSendPrompt,
    this.onStopActiveTurn,
    this.surfaceChangeToken,
    this.onOpenChangedFileDiff,
    this.onApproveRequest,
    this.onDenyRequest,
    this.onSubmitUserInput,
    this.appChrome,
    this.transcriptRegion,
    this.composerRegion,
  }) : assert(
         appChrome != null || onScreenAction != null,
         'onScreenAction is required when no appChrome region is provided.',
       ),
       assert(
         transcriptRegion != null ||
             (onScreenAction != null && onAutoFollowEligibilityChanged != null),
         'Transcript callbacks are required when no transcriptRegion is provided.',
       ),
       assert(
         composerRegion != null ||
             (onComposerDraftChanged != null &&
                 onSendPrompt != null &&
                 onStopActiveTurn != null),
         'Composer callbacks are required when no composerRegion is provided.',
       );

  final ChatScreenContract screen;
  final ValueChanged<ChatScreenActionId>? onScreenAction;
  final ValueChanged<bool>? onAutoFollowEligibilityChanged;
  final ValueChanged<String>? onComposerDraftChanged;
  final Future<void> Function()? onSendPrompt;
  final Future<void> Function()? onStopActiveTurn;
  final Object? surfaceChangeToken;
  final void Function(ChatChangedFileDiffContract diff)? onOpenChangedFileDiff;
  final Future<void> Function(String requestId)? onApproveRequest;
  final Future<void> Function(String requestId)? onDenyRequest;
  final Future<void> Function(
    String requestId,
    Map<String, List<String>> answers,
  )?
  onSubmitUserInput;
  final PreferredSizeWidget? appChrome;
  final Widget? transcriptRegion;
  final Widget? composerRegion;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;
    final resolvedAppChrome =
        appChrome ??
        FlutterChatAppChrome(screen: screen, onScreenAction: onScreenAction!);
    final resolvedTranscriptRegion =
        transcriptRegion ??
        FlutterChatTranscriptRegion(
          screen: screen,
          surfaceChangeToken: surfaceChangeToken,
          onScreenAction: onScreenAction!,
          onAutoFollowEligibilityChanged: onAutoFollowEligibilityChanged!,
          onApproveRequest: onApproveRequest,
          onDenyRequest: onDenyRequest,
          onOpenChangedFileDiff: onOpenChangedFileDiff,
          onSubmitUserInput: onSubmitUserInput,
        );
    final resolvedComposerRegion =
        composerRegion ??
        FlutterChatComposerRegion(
          composer: screen.composer,
          onComposerDraftChanged: onComposerDraftChanged!,
          onSendPrompt: onSendPrompt!,
          onStopActiveTurn: onStopActiveTurn!,
        );

    return Scaffold(
      appBar: resolvedAppChrome,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[palette.backgroundTop, palette.backgroundBottom],
          ),
        ),
        child: screen.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(child: resolvedTranscriptRegion),
                  if (screen.turnIndicator case final turnIndicator?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                      child: TurnElapsedFooter(turnTimer: turnIndicator.timer),
                    ),
                  resolvedComposerRegion,
                ],
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
    final theme = Theme.of(context);

    return AppBar(
      titleSpacing: 18,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            screen.header.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            screen.header.subtitle,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        ...screen.toolbarActions.map(
          (action) => IconButton(
            tooltip: action.tooltip,
            onPressed: () => onScreenAction(action.id),
            icon: Icon(_iconForAction(action)),
          ),
        ),
        PopupMenuButton<ChatScreenActionId>(
          onSelected: onScreenAction,
          itemBuilder: (context) {
            return screen.menuActions
                .map(
                  (action) => PopupMenuItem<ChatScreenActionId>(
                    value: action.id,
                    child: Text(action.label),
                  ),
                )
                .toList(growable: false);
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class FlutterChatTranscriptRegion extends StatelessWidget {
  const FlutterChatTranscriptRegion({
    super.key,
    required this.screen,
    required this.onScreenAction,
    required this.onAutoFollowEligibilityChanged,
    this.emptyStateRenderer = ChatEmptyStateRenderer.flutter,
    this.surfaceChangeToken,
    this.onOpenChangedFileDiff,
    this.onApproveRequest,
    this.onDenyRequest,
    this.onSubmitUserInput,
  });

  final ChatScreenContract screen;
  final ValueChanged<ChatScreenActionId> onScreenAction;
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

  @override
  Widget build(BuildContext context) {
    return TranscriptList(
      surface: screen.transcriptSurface,
      followBehavior: screen.transcriptFollow,
      surfaceChangeToken: surfaceChangeToken,
      onConfigure: () {
        onScreenAction(ChatScreenActionId.openSettings);
      },
      onAutoFollowEligibilityChanged: onAutoFollowEligibilityChanged,
      emptyStateRenderer: emptyStateRenderer,
      onApproveRequest: onApproveRequest,
      onDenyRequest: onDenyRequest,
      onOpenChangedFileDiff: onOpenChangedFileDiff,
      onSubmitUserInput: onSubmitUserInput,
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

IconData _iconForAction(ChatScreenActionContract action) {
  return switch (action.icon) {
    ChatScreenActionIcon.settings => Icons.tune,
    null => Icons.more_horiz,
  };
}
