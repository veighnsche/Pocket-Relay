import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_chrome_menu_action.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_root_overlay_delegate.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_effect.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_effect_mapper.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_presenter.dart';
import 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/flutter_chat_screen_renderer.dart';

class ChatRootAdapter extends StatefulWidget {
  const ChatRootAdapter({
    super.key,
    required this.laneBinding,
    required this.platformPolicy,
    required this.onConnectionSettingsRequested,
    this.overlayDelegate = const FlutterChatRootOverlayDelegate(),
    this.supplementalMenuActions = const <ChatChromeMenuAction>[],
  });

  final ConnectionLaneBinding laneBinding;
  final PocketPlatformPolicy platformPolicy;
  final Future<void> Function(ChatConnectionSettingsLaunchContract payload)
  onConnectionSettingsRequested;
  final ChatRootOverlayDelegate overlayDelegate;
  final List<ChatChromeMenuAction> supplementalMenuActions;

  @override
  State<ChatRootAdapter> createState() => _ChatRootAdapterState();
}

class _ChatRootAdapterState extends State<ChatRootAdapter> {
  final _effectMapper = const ChatScreenEffectMapper();
  final _screenPresenter = const ChatScreenPresenter();
  StreamSubscription<ChatScreenEffect>? _screenEffectSubscription;
  ConnectionMode? _preferredEmptyStateConnectionMode;

  @override
  void initState() {
    super.initState();
    _bindScreenEffects();
  }

  @override
  void didUpdateWidget(covariant ChatRootAdapter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.laneBinding == widget.laneBinding) {
      return;
    }

    _screenEffectSubscription?.cancel();
    _preferredEmptyStateConnectionMode = null;
    _bindScreenEffects();
  }

  @override
  void dispose() {
    _screenEffectSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final laneBinding = widget.laneBinding;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        laneBinding.sessionController,
        laneBinding.composerDraftHost,
        laneBinding.transcriptFollowHost,
      ]),
      builder: (context, _) {
        final screen = _buildScreenContract();
        return FlutterChatScreenRenderer(
          screen: screen,
          appChrome: _buildAppChrome(screen),
          transcriptRegion: _buildTranscriptRegion(screen),
          composerRegion: _buildComposerRegion(screen),
          onStopActiveTurn: _stopActiveTurn,
        );
      },
    );
  }

  void _bindScreenEffects() {
    _screenEffectSubscription = widget.laneBinding.screenEffects.listen(
      _handleScreenEffect,
    );
  }

  PreferredSizeWidget _buildAppChrome(ChatScreenContract screen) {
    return FlutterChatAppChrome(
      screen: screen,
      onScreenAction: (action) => _handleScreenAction(action, screen),
      supplementalMenuActions: widget.supplementalMenuActions,
    );
  }

  Widget _buildTranscriptRegion(ChatScreenContract screen) {
    final laneBinding = widget.laneBinding;
    final sessionController = laneBinding.sessionController;

    return FlutterChatTranscriptRegion(
      screen: screen,
      surfaceChangeToken: sessionController.sessionState,
      platformBehavior: widget.platformPolicy.behavior,
      onScreenAction: (action) => _handleScreenAction(action, screen),
      onSelectTimeline: sessionController.selectTimeline,
      onSelectConnectionMode: _selectConnectionMode,
      onAutoFollowEligibilityChanged: (isNearBottom) {
        laneBinding.transcriptFollowHost.updateAutoFollowEligibility(
          isNearBottom: isNearBottom,
        );
      },
      onApproveRequest: sessionController.approveRequest,
      onDenyRequest: sessionController.denyRequest,
      onOpenChangedFileDiff: _requestChangedFileDiff,
      onSubmitUserInput: sessionController.submitUserInput,
      onSaveHostFingerprint: sessionController.saveObservedHostFingerprint,
      onContinueFromUserMessage: _continueFromUserMessage,
    );
  }

  Widget _buildComposerRegion(ChatScreenContract screen) {
    return FlutterChatComposerRegion(
      platformBehavior: widget.platformPolicy.behavior,
      conversationRecoveryNotice: screen.conversationRecoveryNotice,
      historicalConversationRestoreNotice:
          screen.historicalConversationRestoreNotice,
      composer: screen.composer,
      onComposerDraftChanged: widget.laneBinding.composerDraftHost.updateText,
      onSendPrompt: _sendPrompt,
      onConversationRecoveryAction: _handleConversationRecoveryAction,
      onHistoricalConversationRestoreAction:
          _handleHistoricalConversationRestoreAction,
    );
  }

  ChatScreenContract _buildScreenContract() {
    final laneBinding = widget.laneBinding;
    final sessionController = laneBinding.sessionController;

    return _screenPresenter.present(
      isLoading: sessionController.isLoading,
      profile: sessionController.profile,
      secrets: sessionController.secrets,
      sessionState: sessionController.sessionState,
      conversationRecoveryState: sessionController.conversationRecoveryState,
      historicalConversationRestoreState:
          sessionController.historicalConversationRestoreState,
      composerDraft: laneBinding.composerDraftHost.draft,
      transcriptFollow: laneBinding.transcriptFollowHost.contract,
      preferredConnectionMode: _preferredEmptyStateConnectionMode,
    );
  }

  Future<void> _requestConnectionSettings(
    ChatConnectionSettingsLaunchContract connectionSettings,
  ) async {
    await widget.onConnectionSettingsRequested(connectionSettings);
  }

  Future<void> _openChangedFileDiff(ChatChangedFileDiffContract diff) async {
    if (!mounted) {
      return;
    }

    await widget.overlayDelegate.openChangedFileDiff(
      context: context,
      diff: diff,
    );
  }

  void _requestChangedFileDiff(ChatChangedFileDiffContract diff) {
    _handleScreenEffect(ChatOpenChangedFileDiffEffect(payload: diff));
  }

  void _handleScreenAction(
    ChatScreenActionId action,
    ChatScreenContract screen,
  ) {
    final effect = _effectMapper.mapAction(action: action, screen: screen);
    if (effect != null) {
      _handleScreenEffect(effect);
      return;
    }

    switch (action) {
      case ChatScreenActionId.newThread:
        _startFreshConversation();
      case ChatScreenActionId.branchConversation:
        unawaited(_branchConversation());
      case ChatScreenActionId.clearTranscript:
        _clearTranscript();
      case ChatScreenActionId.openSettings:
        return;
    }
  }

  Future<void> _sendPrompt() async {
    final laneBinding = widget.laneBinding;
    final controller = laneBinding.sessionController;
    final sent = await controller.sendPrompt(
      laneBinding.composerDraftHost.draft.text,
    );
    if (!mounted || laneBinding != widget.laneBinding || !sent) {
      return;
    }

    laneBinding.transcriptFollowHost.requestFollow(
      source: ChatTranscriptFollowRequestSource.sendPrompt,
    );
    laneBinding.composerDraftHost.clear();
  }

  Future<void> _stopActiveTurn() async {
    await widget.laneBinding.sessionController.stopActiveTurn();
  }

  Future<void> _continueFromUserMessage(String blockId) async {
    if (!mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Continue From Here'),
          content: const Text(
            'This will discard newer conversation turns in this thread, '
            'reload the selected prompt into the composer, and keep any local '
            'file changes exactly as they are. Local file changes are not '
            'reverted automatically.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final laneBinding = widget.laneBinding;
    final draftText = await laneBinding.sessionController
        .continueFromUserMessage(blockId);
    if (!mounted || laneBinding != widget.laneBinding || draftText == null) {
      return;
    }

    laneBinding.composerDraftHost.updateText(draftText);
    laneBinding.transcriptFollowHost.requestFollow(
      source: ChatTranscriptFollowRequestSource.clearTranscript,
    );
  }

  void _startFreshConversation() {
    widget.laneBinding.transcriptFollowHost.requestFollow(
      source: ChatTranscriptFollowRequestSource.newThread,
    );
    widget.laneBinding.sessionController.startFreshConversation();
  }

  Future<void> _branchConversation() async {
    final branched = await widget.laneBinding.sessionController
        .branchSelectedConversation();
    if (!branched) {
      return;
    }
    widget.laneBinding.transcriptFollowHost.reset();
  }

  void _clearTranscript() {
    widget.laneBinding.transcriptFollowHost.requestFollow(
      source: ChatTranscriptFollowRequestSource.clearTranscript,
    );
    widget.laneBinding.sessionController.clearTranscript();
  }

  void _handleConversationRecoveryAction(
    ChatConversationRecoveryActionId action,
  ) {
    switch (action) {
      case ChatConversationRecoveryActionId.startFreshConversation:
        _startFreshConversation();
      case ChatConversationRecoveryActionId.openAlternateSession:
        widget.laneBinding.sessionController
            .openConversationRecoveryAlternateSession();
    }
  }

  void _handleHistoricalConversationRestoreAction(
    ChatHistoricalConversationRestoreActionId action,
  ) {
    switch (action) {
      case ChatHistoricalConversationRestoreActionId.retryRestore:
        unawaited(
          widget.laneBinding.sessionController
              .retryHistoricalConversationRestore(),
        );
      case ChatHistoricalConversationRestoreActionId.startFreshConversation:
        _startFreshConversation();
    }
  }

  void _selectConnectionMode(ConnectionMode mode) {
    if (_preferredEmptyStateConnectionMode == mode) {
      return;
    }

    setState(() {
      _preferredEmptyStateConnectionMode = mode;
    });
  }

  void _handleScreenEffect(ChatScreenEffect effect) {
    switch (effect) {
      case ChatShowSnackBarEffect(:final message):
        _showTransientFeedback(message);
      case ChatOpenConnectionSettingsEffect(:final payload):
        unawaited(_requestConnectionSettings(payload));
      case ChatOpenChangedFileDiffEffect(:final payload):
        unawaited(_openChangedFileDiff(payload));
    }
  }

  void _showTransientFeedback(String message) {
    if (!mounted) {
      return;
    }

    widget.overlayDelegate.showTransientFeedback(
      context: context,
      message: message,
    );
  }
}
