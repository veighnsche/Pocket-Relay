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
    this.screenPresenter = const ChatScreenPresenter(),
    this.overlayDelegate = const FlutterChatRootOverlayDelegate(),
    this.supplementalMenuActions = const <ChatChromeMenuAction>[],
    this.laneRestartAction,
    this.onRestartLane,
  });

  final ConnectionLaneBinding laneBinding;
  final PocketPlatformPolicy platformPolicy;
  final Future<void> Function(ChatConnectionSettingsLaunchContract payload)
  onConnectionSettingsRequested;
  final ChatScreenPresenter screenPresenter;
  final ChatRootOverlayDelegate overlayDelegate;
  final List<ChatChromeMenuAction> supplementalMenuActions;
  final ChatLaneRestartActionContract? laneRestartAction;
  final Future<void> Function()? onRestartLane;

  @override
  State<ChatRootAdapter> createState() => _ChatRootAdapterState();
}

class _ChatRootAdapterState extends State<ChatRootAdapter> {
  final _effectMapper = const ChatScreenEffectMapper();
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
      animation: laneBinding.sessionController,
      builder: (context, _) {
        final sessionScreen = _buildSessionScreenContract();
        final screen = sessionScreen.compose(
          transcriptFollow: laneBinding.transcriptFollowHost.contract,
          composerDraft: laneBinding.composerDraftHost.draft,
        );
        return FlutterChatScreenRenderer(
          screen: screen,
          appChrome: _buildAppChrome(screen),
          transcriptRegion: _ChatTranscriptRegionHost(
            sessionScreen: sessionScreen,
            laneBinding: laneBinding,
            platformPolicy: widget.platformPolicy,
            onScreenAction: _handleScreenAction,
            onSelectConnectionMode: _selectConnectionMode,
            onRequestChangedFileDiff: _requestChangedFileDiff,
            onContinueFromUserMessage: _continueFromUserMessage,
          ),
          composerRegion: _ChatComposerRegionHost(
            sessionScreen: sessionScreen,
            laneBinding: laneBinding,
            platformPolicy: widget.platformPolicy,
            onSendPrompt: _sendPrompt,
            onConversationRecoveryAction: _handleConversationRecoveryAction,
            onHistoricalConversationRestoreAction:
                _handleHistoricalConversationRestoreAction,
          ),
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

  ChatScreenSessionContract _buildSessionScreenContract() {
    final laneBinding = widget.laneBinding;
    final sessionController = laneBinding.sessionController;

    return widget.screenPresenter.presentSession(
      isLoading: sessionController.isLoading,
      profile: sessionController.profile,
      secrets: sessionController.secrets,
      sessionState: sessionController.sessionState,
      conversationRecoveryState: sessionController.conversationRecoveryState,
      historicalConversationRestoreState:
          sessionController.historicalConversationRestoreState,
      effectiveModelSupportsImages:
          sessionController.currentModelSupportsImageInput,
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

class _ChatTranscriptRegionHost extends StatelessWidget {
  const _ChatTranscriptRegionHost({
    required this.sessionScreen,
    required this.laneBinding,
    required this.platformPolicy,
    required this.onScreenAction,
    required this.onSelectConnectionMode,
    required this.onRequestChangedFileDiff,
    required this.onContinueFromUserMessage,
  });

  final ChatScreenSessionContract sessionScreen;
  final ConnectionLaneBinding laneBinding;
  final PocketPlatformPolicy platformPolicy;
  final void Function(ChatScreenActionId action, ChatScreenContract screen)
  onScreenAction;
  final ValueChanged<ConnectionMode> onSelectConnectionMode;
  final void Function(ChatChangedFileDiffContract diff)
  onRequestChangedFileDiff;
  final Future<void> Function(String blockId) onContinueFromUserMessage;

  @override
  Widget build(BuildContext context) {
    final sessionController = laneBinding.sessionController;

    return AnimatedBuilder(
      animation: laneBinding.transcriptFollowHost,
      builder: (context, _) {
        final screen = sessionScreen.compose(
          transcriptFollow: laneBinding.transcriptFollowHost.contract,
          composerDraft: laneBinding.composerDraftHost.draft,
        );
        return FlutterChatTranscriptRegion(
          screen: screen,
          surfaceChangeToken: sessionController.sessionState,
          platformBehavior: platformPolicy.behavior,
          onScreenAction: (action) => onScreenAction(action, screen),
          onSelectTimeline: sessionController.selectTimeline,
          onSelectConnectionMode: onSelectConnectionMode,
          onAutoFollowEligibilityChanged: (isNearBottom) {
            laneBinding.transcriptFollowHost.updateAutoFollowEligibility(
              isNearBottom: isNearBottom,
            );
          },
          onApproveRequest: sessionController.approveRequest,
          onDenyRequest: sessionController.denyRequest,
          onOpenChangedFileDiff: onRequestChangedFileDiff,
          onSubmitUserInput: sessionController.submitUserInput,
          onSaveHostFingerprint: sessionController.saveObservedHostFingerprint,
          onContinueFromUserMessage: onContinueFromUserMessage,
        );
      },
    );
  }
}

class _ChatComposerRegionHost extends StatelessWidget {
  const _ChatComposerRegionHost({
    required this.sessionScreen,
    required this.laneBinding,
    required this.platformPolicy,
    required this.onSendPrompt,
    required this.onConversationRecoveryAction,
    required this.onHistoricalConversationRestoreAction,
  });

  final ChatScreenSessionContract sessionScreen;
  final ConnectionLaneBinding laneBinding;
  final PocketPlatformPolicy platformPolicy;
  final Future<void> Function() onSendPrompt;
  final void Function(ChatConversationRecoveryActionId action)
  onConversationRecoveryAction;
  final void Function(ChatHistoricalConversationRestoreActionId action)
  onHistoricalConversationRestoreAction;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: laneBinding.composerDraftHost,
      builder: (context, _) {
        final screen = sessionScreen.compose(
          transcriptFollow: laneBinding.transcriptFollowHost.contract,
          composerDraft: laneBinding.composerDraftHost.draft,
        );
        return FlutterChatComposerRegion(
          platformBehavior: platformPolicy.behavior,
          conversationRecoveryNotice: screen.conversationRecoveryNotice,
          historicalConversationRestoreNotice:
              screen.historicalConversationRestoreNotice,
          composer: screen.composer,
          onComposerDraftChanged: laneBinding.composerDraftHost.updateDraft,
          onSendPrompt: onSendPrompt,
          onConversationRecoveryAction: onConversationRecoveryAction,
          onHistoricalConversationRestoreAction:
              onHistoricalConversationRestoreAction,
        );
      },
    );
  }
}
