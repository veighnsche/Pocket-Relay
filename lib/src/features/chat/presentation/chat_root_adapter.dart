import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/features/chat/application/chat_session_controller.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_composer_draft_host.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_overlay_delegate.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_renderer_delegate.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_region_policy.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_effect.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_effect_mapper.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_presenter.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_follow_host.dart';

class ChatRootAdapter extends StatefulWidget {
  const ChatRootAdapter({
    super.key,
    required this.profileStore,
    required this.appServerClient,
    this.initialSavedProfile,
    this.platformPolicy = const ChatRootPlatformPolicy.allFlutter(),
    this.regionPolicy,
    this.overlayDelegate = const FlutterChatRootOverlayDelegate(),
    this.rendererDelegate = const FlutterChatRootRendererDelegate(),
  });

  final CodexProfileStore profileStore;
  final CodexAppServerClient appServerClient;
  final SavedProfile? initialSavedProfile;
  final ChatRootPlatformPolicy platformPolicy;
  final ChatRootRegionPolicy? regionPolicy;
  final ChatRootOverlayDelegate overlayDelegate;
  final ChatRootRendererDelegate rendererDelegate;

  @override
  State<ChatRootAdapter> createState() => _ChatRootAdapterState();
}

class _ChatRootAdapterState extends State<ChatRootAdapter> {
  final _composerDraftHost = ChatComposerDraftHost();
  final _transcriptFollowHost = ChatTranscriptFollowHost();
  final _effectMapper = const ChatScreenEffectMapper();
  final _screenPresenter = const ChatScreenPresenter();
  late ChatSessionController _sessionController;
  StreamSubscription<ChatScreenEffect>? _screenEffectSubscription;

  @override
  void initState() {
    super.initState();
    _sessionController = _buildSessionController();
    _bindScreenEffects();
    unawaited(_sessionController.initialize());
  }

  @override
  void didUpdateWidget(covariant ChatRootAdapter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileStore == widget.profileStore &&
        oldWidget.appServerClient == widget.appServerClient &&
        oldWidget.initialSavedProfile == widget.initialSavedProfile) {
      return;
    }

    _screenEffectSubscription?.cancel();
    _sessionController.dispose();
    _sessionController = _buildSessionController();
    _composerDraftHost.reset();
    _transcriptFollowHost.reset();
    _bindScreenEffects();
    unawaited(_sessionController.initialize());
  }

  @override
  void dispose() {
    _screenEffectSubscription?.cancel();
    _sessionController.dispose();
    _transcriptFollowHost.dispose();
    _composerDraftHost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _sessionController,
        _composerDraftHost,
        _transcriptFollowHost,
      ]),
      builder: (context, _) {
        final screen = _buildScreenContract();
        final regionPolicy = _resolvedRegionPolicy(context);
        return widget.rendererDelegate.buildScreenShell(
          renderer: regionPolicy.screenShell,
          screen: screen,
          appChrome: _buildAppChrome(screen, regionPolicy),
          transcriptRegion: _buildTranscriptRegion(screen, regionPolicy),
          composerRegion: _buildComposerRegion(screen, regionPolicy),
        );
      },
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
    );
  }

  Widget _buildTranscriptRegion(
    ChatScreenContract screen,
    ChatRootRegionPolicy regionPolicy,
  ) {
    return widget.rendererDelegate.buildTranscriptRegion(
      renderer: regionPolicy.rendererFor(ChatRootRegion.transcript),
      screen: screen,
      surfaceChangeToken: _sessionController.sessionState,
      onScreenAction: (action) => _handleScreenAction(action, screen),
      onAutoFollowEligibilityChanged: (isNearBottom) {
        _transcriptFollowHost.updateAutoFollowEligibility(
          isNearBottom: isNearBottom,
        );
      },
      onApproveRequest: _sessionController.approveRequest,
      onDenyRequest: _sessionController.denyRequest,
      onOpenChangedFileDiff: _requestChangedFileDiff,
      onSubmitUserInput: _sessionController.submitUserInput,
    );
  }

  Widget _buildComposerRegion(
    ChatScreenContract screen,
    ChatRootRegionPolicy regionPolicy,
  ) {
    return widget.rendererDelegate.buildComposerRegion(
      renderer: regionPolicy.rendererFor(ChatRootRegion.composer),
      composer: screen.composer,
      onComposerDraftChanged: _composerDraftHost.updateText,
      onSendPrompt: _sendPrompt,
      onStopActiveTurn: _stopActiveTurn,
    );
  }

  ChatSessionController _buildSessionController() {
    return ChatSessionController(
      profileStore: widget.profileStore,
      appServerClient: widget.appServerClient,
      initialSavedProfile: widget.initialSavedProfile,
    );
  }

  void _bindScreenEffects() {
    _screenEffectSubscription = _sessionController.snackBarMessages
        .map(_effectMapper.mapSnackBarMessage)
        .listen(_handleScreenEffect);
  }

  ChatScreenContract _buildScreenContract() {
    return _screenPresenter.present(
      isLoading: _sessionController.isLoading,
      profile: _sessionController.profile,
      secrets: _sessionController.secrets,
      sessionState: _sessionController.sessionState,
      composerDraft: _composerDraftHost.draft,
      transcriptFollow: _transcriptFollowHost.contract,
    );
  }

  ChatRootRegionPolicy _resolvedRegionPolicy(BuildContext context) {
    return widget.regionPolicy ??
        widget.platformPolicy.policyFor(Theme.of(context).platform);
  }

  Future<void> _openConnectionSettings(
    ChatConnectionSettingsLaunchContract connectionSettings,
  ) async {
    if (!mounted) {
      return;
    }

    final controller = _sessionController;
    final overlayDelegate = widget.overlayDelegate;
    final settingsRenderer = _resolvedRegionPolicy(
      context,
    ).rendererFor(ChatRootRegion.settingsOverlay);

    final result = switch (settingsRenderer) {
      ChatRootRegionRenderer.cupertino || ChatRootRegionRenderer.flutter =>
        await overlayDelegate.openConnectionSettings(
          context: context,
          connectionSettings: connectionSettings,
        ),
    };

    if (!mounted ||
        controller != _sessionController ||
        overlayDelegate != widget.overlayDelegate ||
        settingsRenderer !=
            _resolvedRegionPolicy(
              context,
            ).rendererFor(ChatRootRegion.settingsOverlay) ||
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
    final controller = _sessionController;
    final sent = await controller.sendPrompt(_composerDraftHost.draft.text);
    if (!mounted || controller != _sessionController || !sent) {
      return;
    }

    if (sent) {
      _transcriptFollowHost.requestFollow(
        source: ChatTranscriptFollowRequestSource.sendPrompt,
      );
      _composerDraftHost.clear();
    }
  }

  Future<void> _stopActiveTurn() async {
    await _sessionController.stopActiveTurn();
  }

  void _startFreshConversation() {
    _transcriptFollowHost.requestFollow(
      source: ChatTranscriptFollowRequestSource.newThread,
    );
    _sessionController.startFreshConversation();
  }

  void _clearTranscript() {
    _transcriptFollowHost.requestFollow(
      source: ChatTranscriptFollowRequestSource.clearTranscript,
    );
    _sessionController.clearTranscript();
  }

  void _handleScreenEffect(ChatScreenEffect effect) {
    switch (effect) {
      case ChatShowSnackBarEffect(:final message):
        _showSnackBar(message);
      case ChatOpenConnectionSettingsEffect(:final payload):
        unawaited(_openConnectionSettings(payload));
      case ChatOpenChangedFileDiffEffect(:final payload):
        unawaited(_openChangedFileDiff(payload));
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    widget.overlayDelegate.showSnackBar(context: context, message: message);
  }
}
