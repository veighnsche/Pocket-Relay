import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_chrome_menu_action.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_overlay_delegate.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_renderer_delegate.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_region_policy.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_effect.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_effect_mapper.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_presenter.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/empty_state.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_renderer.dart';

class ChatRootAdapter extends StatefulWidget {
  const ChatRootAdapter({
    super.key,
    required this.laneBinding,
    required this.platformPolicy,
    this.overlayDelegate = const FlutterChatRootOverlayDelegate(),
    this.rendererDelegate = const FlutterChatRootRendererDelegate(),
    this.supplementalMenuActions = const <ChatChromeMenuAction>[],
  });

  final ConnectionLaneBinding laneBinding;
  final PocketPlatformPolicy platformPolicy;
  final ChatRootOverlayDelegate overlayDelegate;
  final ChatRootRendererDelegate rendererDelegate;
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
        final regionPolicy = widget.platformPolicy.regionPolicy;
        return widget.rendererDelegate.buildScreenShell(
          renderer: regionPolicy.screenShell,
          screen: screen,
          appChrome: _buildAppChrome(screen, regionPolicy),
          transcriptRegion: _buildTranscriptRegion(screen, regionPolicy),
          composerRegion: _buildComposerRegion(screen, regionPolicy),
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

  PreferredSizeWidget _buildAppChrome(
    ChatScreenContract screen,
    ChatRootRegionPolicy regionPolicy,
  ) {
    return widget.rendererDelegate.buildAppChrome(
      renderer: regionPolicy.rendererFor(ChatRootRegion.appChrome),
      screen: screen,
      onScreenAction: (action) => _handleScreenAction(action, screen),
      supplementalMenuActions: widget.supplementalMenuActions,
    );
  }

  Widget _buildTranscriptRegion(
    ChatScreenContract screen,
    ChatRootRegionPolicy regionPolicy,
  ) {
    final laneBinding = widget.laneBinding;
    final sessionController = laneBinding.sessionController;

    return widget.rendererDelegate.buildTranscriptRegion(
      renderer: regionPolicy.rendererFor(ChatRootRegion.transcript),
      emptyStateRenderer: _emptyStateRendererFor(regionPolicy),
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
    );
  }

  Widget _buildComposerRegion(
    ChatScreenContract screen,
    ChatRootRegionPolicy regionPolicy,
  ) {
    return widget.rendererDelegate.buildComposerRegion(
      renderer: regionPolicy.rendererFor(ChatRootRegion.composer),
      platformBehavior: widget.platformPolicy.behavior,
      conversationRecoveryNotice: screen.conversationRecoveryNotice,
      composer: screen.composer,
      onComposerDraftChanged: widget.laneBinding.composerDraftHost.updateText,
      onSendPrompt: _sendPrompt,
      onConversationRecoveryAction: _handleConversationRecoveryAction,
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
      composerDraft: laneBinding.composerDraftHost.draft,
      transcriptFollow: laneBinding.transcriptFollowHost.contract,
      preferredConnectionMode: _preferredEmptyStateConnectionMode,
    );
  }

  Future<void> _openConnectionSettings(
    ChatConnectionSettingsLaunchContract connectionSettings,
  ) async {
    if (!mounted) {
      return;
    }

    final laneBinding = widget.laneBinding;
    final controller = laneBinding.sessionController;
    final overlayDelegate = widget.overlayDelegate;
    final settingsRenderer = widget.platformPolicy.regionPolicy.rendererFor(
      ChatRootRegion.settingsOverlay,
    );

    final openSettingsResult = switch (settingsRenderer) {
      ChatRootRegionRenderer.cupertino =>
        overlayDelegate.openConnectionSettings(
          context: context,
          connectionSettings: connectionSettings,
          platformBehavior: widget.platformPolicy.behavior,
          renderer: ConnectionSettingsRenderer.cupertino,
        ),
      ChatRootRegionRenderer.flutter => overlayDelegate.openConnectionSettings(
        context: context,
        connectionSettings: connectionSettings,
        platformBehavior: widget.platformPolicy.behavior,
        renderer: ConnectionSettingsRenderer.material,
      ),
    };
    final result = await openSettingsResult;

    if (!mounted ||
        laneBinding != widget.laneBinding ||
        overlayDelegate != widget.overlayDelegate ||
        settingsRenderer !=
            widget.platformPolicy.regionPolicy.rendererFor(
              ChatRootRegion.settingsOverlay,
            ) ||
        result == null) {
      return;
    }

    final connectionChanged =
        result.profile != controller.profile ||
        result.secrets != controller.secrets;
    if (!connectionChanged) {
      return;
    }

    await controller.applyConnectionSettings(
      profile: result.profile,
      secrets: result.secrets,
    );
    if (mounted && laneBinding == widget.laneBinding) {
      setState(() {
        _preferredEmptyStateConnectionMode = null;
      });
    }
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

  void _startFreshConversation() {
    widget.laneBinding.transcriptFollowHost.requestFollow(
      source: ChatTranscriptFollowRequestSource.newThread,
    );
    widget.laneBinding.sessionController.startFreshConversation();
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
        unawaited(_openConnectionSettings(payload));
      case ChatOpenChangedFileDiffEffect(:final payload):
        unawaited(_openChangedFileDiff(payload));
    }
  }

  ChatEmptyStateRenderer _emptyStateRendererFor(
    ChatRootRegionPolicy regionPolicy,
  ) {
    return switch (regionPolicy.rendererFor(ChatRootRegion.emptyState)) {
      ChatRootRegionRenderer.flutter => ChatEmptyStateRenderer.flutter,
      ChatRootRegionRenderer.cupertino => ChatEmptyStateRenderer.cupertino,
    };
  }

  ChatTransientFeedbackRenderer _feedbackRendererFor(
    ChatRootRegionPolicy regionPolicy,
  ) {
    return switch (regionPolicy.rendererFor(ChatRootRegion.feedbackOverlay)) {
      ChatRootRegionRenderer.flutter => ChatTransientFeedbackRenderer.material,
      ChatRootRegionRenderer.cupertino =>
        ChatTransientFeedbackRenderer.cupertino,
    };
  }

  void _showTransientFeedback(String message) {
    if (!mounted) {
      return;
    }

    widget.overlayDelegate.showTransientFeedback(
      context: context,
      message: message,
      renderer: _feedbackRendererFor(widget.platformPolicy.regionPolicy),
    );
  }
}
