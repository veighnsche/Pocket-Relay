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

part 'chat_root_adapter_actions.dart';
part 'chat_root_adapter_effects.dart';

class ChatRootAdapter extends StatefulWidget {
  const ChatRootAdapter({
    super.key,
    required this.laneBinding,
    required this.platformPolicy,
    required this.onConnectionSettingsRequested,
    this.overlayDelegate = const FlutterChatRootOverlayDelegate(),
    this.supplementalMenuActions = const <ChatChromeMenuAction>[],
    this.laneRestartAction,
    this.onRestartLane,
  });

  final ConnectionLaneBinding laneBinding;
  final PocketPlatformPolicy platformPolicy;
  final Future<void> Function(ChatConnectionSettingsLaunchContract payload)
  onConnectionSettingsRequested;
  final ChatRootOverlayDelegate overlayDelegate;
  final List<ChatChromeMenuAction> supplementalMenuActions;
  final ChatLaneRestartActionContract? laneRestartAction;
  final Future<void> Function()? onRestartLane;

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
          laneRestartAction: widget.laneRestartAction,
          onRestartLane: widget.onRestartLane,
        );
      },
    );
  }

  void _bindScreenEffects() => _bindChatRootScreenEffects(this);

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
      onComposerDraftChanged: widget.laneBinding.composerDraftHost.updateDraft,
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
      effectiveModelSupportsImages:
          sessionController.currentModelSupportsImageInput,
      transcriptFollow: laneBinding.transcriptFollowHost.contract,
      preferredConnectionMode: _preferredEmptyStateConnectionMode,
    );
  }

  Future<void> _requestConnectionSettings(
    ChatConnectionSettingsLaunchContract connectionSettings,
  ) => _requestChatConnectionSettings(this, connectionSettings);

  Future<void> _openChangedFileDiff(ChatChangedFileDiffContract diff) =>
      _openChatChangedFileDiff(this, diff);

  void _requestChangedFileDiff(ChatChangedFileDiffContract diff) =>
      _requestChatChangedFileDiff(this, diff);

  void _handleScreenAction(
    ChatScreenActionId action,
    ChatScreenContract screen,
  ) => _handleChatScreenAction(this, action, screen);

  Future<void> _sendPrompt() => _sendChatPrompt(this);

  Future<void> _stopActiveTurn() async {
    await widget.laneBinding.sessionController.stopActiveTurn();
  }

  Future<void> _continueFromUserMessage(String blockId) =>
      _continueChatFromUserMessage(this, blockId);

  void _startFreshConversation() => _startFreshChatConversation(this);

  Future<void> _branchConversation() => _branchChatConversation(this);

  void _clearTranscript() => _clearChatTranscript(this);

  void _handleConversationRecoveryAction(
    ChatConversationRecoveryActionId action,
  ) => _handleChatConversationRecoveryAction(this, action);

  void _handleHistoricalConversationRestoreAction(
    ChatHistoricalConversationRestoreActionId action,
  ) => _handleChatHistoricalConversationRestoreAction(this, action);

  void _selectConnectionMode(ConnectionMode mode) {
    if (_preferredEmptyStateConnectionMode == mode) {
      return;
    }

    setState(() {
      _preferredEmptyStateConnectionMode = mode;
    });
  }

  void _handleScreenEffect(ChatScreenEffect effect) =>
      _handleChatScreenEffect(this, effect);

  void _showTransientFeedback(String message) =>
      _showChatTransientFeedback(this, message);
}
