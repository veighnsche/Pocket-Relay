import 'dart:async';

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/application/chat_session_controller.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_effect.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_effect_mapper.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_presenter.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_composer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/transcript_list.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/turn_elapsed_footer.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_sheet.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.profileStore,
    required this.appServerClient,
    this.initialSavedProfile,
  });

  final CodexProfileStore profileStore;
  final CodexAppServerClient appServerClient;
  final SavedProfile? initialSavedProfile;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _composerController = TextEditingController();
  final _transcriptListController = TranscriptListController();
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
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileStore == widget.profileStore &&
        oldWidget.appServerClient == widget.appServerClient &&
        oldWidget.initialSavedProfile == widget.initialSavedProfile) {
      return;
    }

    _screenEffectSubscription?.cancel();
    _sessionController.dispose();
    _sessionController = _buildSessionController();
    _bindScreenEffects();
    unawaited(_sessionController.initialize());
  }

  ChatSessionController _buildSessionController() {
    return ChatSessionController(
      profileStore: widget.profileStore,
      appServerClient: widget.appServerClient,
      initialSavedProfile: widget.initialSavedProfile,
    );
  }

  @override
  void dispose() {
    _screenEffectSubscription?.cancel();
    _sessionController.dispose();
    _transcriptListController.dispose();
    _composerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sessionController,
      builder: (context, _) {
        final screen = _buildScreenContract();
        final theme = Theme.of(context);
        final palette = context.pocketPalette;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 18,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  screen.header.title,
                  style: TextStyle(fontWeight: FontWeight.w800),
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
                  onPressed: () => _handleScreenAction(action.id, screen),
                  icon: Icon(_iconForAction(action)),
                ),
              ),
              PopupMenuButton<ChatScreenActionId>(
                onSelected: (action) {
                  _handleScreenAction(action, screen);
                },
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
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  palette.backgroundTop,
                  palette.backgroundBottom,
                ],
              ),
            ),
            child: screen.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        child: TranscriptList(
                          controller: _transcriptListController,
                          surface: screen.transcriptSurface,
                          onConfigure: () => _requestConnectionSettings(screen),
                          onApproveRequest: _sessionController.approveRequest,
                          onDenyRequest: _sessionController.denyRequest,
                          onSubmitUserInput: _sessionController.submitUserInput,
                        ),
                      ),
                      if (screen.turnIndicator case final turnIndicator?)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                          child: TurnElapsedFooter(turnTimer: turnIndicator.timer),
                        ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                          child: ChatComposer(
                            controller: _composerController,
                            contract: screen.composer,
                            onSend: _sendPrompt,
                            onStop: _stopActiveTurn,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
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
    );
  }

  Future<void> _openSettingsSheet(
    ChatConnectionSettingsLaunchContract connectionSettings,
  ) async {
    final result = await showModalBottomSheet<ConnectionSheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ConnectionSheet(
          initialProfile: connectionSettings.initialProfile,
          initialSecrets: connectionSettings.initialSecrets,
        );
      },
    );

    if (result == null) {
      return;
    }

    final connectionChanged =
        result.profile != _sessionController.profile ||
        result.secrets != _sessionController.secrets;

    if (!connectionChanged) {
      return;
    }

    await _sessionController.applyConnectionSettings(
      profile: result.profile,
      secrets: result.secrets,
    );
  }

  void _requestConnectionSettings(ChatScreenContract screen) {
    final effect = _effectMapper.mapAction(
      action: ChatScreenActionId.openSettings,
      screen: screen,
    );
    if (effect == null) {
      return;
    }
    _handleScreenEffect(effect);
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
    _transcriptListController.requestFollow();
    final sent = await _sessionController.sendPrompt(_composerController.text);
    if (sent) {
      _composerController.clear();
    }
  }

  Future<void> _stopActiveTurn() async {
    await _sessionController.stopActiveTurn();
  }

  void _startFreshConversation() {
    _transcriptListController.requestFollow();
    _sessionController.startFreshConversation();
  }

  void _clearTranscript() {
    _transcriptListController.requestFollow();
    _sessionController.clearTranscript();
  }

  void _handleScreenEffect(ChatScreenEffect effect) {
    switch (effect) {
      case ChatShowSnackBarEffect(:final message):
        _showSnackBar(message);
      case ChatOpenConnectionSettingsEffect(:final payload):
        unawaited(_openSettingsSheet(payload));
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

IconData _iconForAction(ChatScreenActionContract action) {
  return switch (action.icon) {
    ChatScreenActionIcon.settings => Icons.tune,
    null => Icons.more_horiz,
  };
}
