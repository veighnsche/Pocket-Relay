import 'dart:async';

import 'package:pocket_relay/src/core/models/app_preferences.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/application/chat_session_controller.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_composer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/transcript_list.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_sheet.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.profileStore,
    required this.appServerClient,
    this.initialSavedProfile,
    required this.preferences,
    required this.onPreferencesChanged,
  });

  final CodexProfileStore profileStore;
  final CodexAppServerClient appServerClient;
  final SavedProfile? initialSavedProfile;
  final AppPreferences preferences;
  final ValueChanged<AppPreferences> onPreferencesChanged;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _composerController = TextEditingController();
  final _transcriptListController = TranscriptListController();
  late final ChatSessionController _sessionController;
  StreamSubscription<String>? _snackBarSubscription;

  @override
  void initState() {
    super.initState();
    _sessionController = ChatSessionController(
      profileStore: widget.profileStore,
      appServerClient: widget.appServerClient,
      initialSavedProfile: widget.initialSavedProfile,
    );
    _snackBarSubscription = _sessionController.snackBarMessages.listen(
      _showSnackBar,
    );
    unawaited(_sessionController.initialize());
  }

  @override
  void dispose() {
    _snackBarSubscription?.cancel();
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
        final theme = Theme.of(context);
        final palette = context.pocketPalette;
        final profile = _sessionController.profile;
        final sessionState = _sessionController.sessionState;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 18,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pocket Relay',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  profile.isReady
                      ? '${profile.label} · ${profile.host}'
                      : 'Configure a remote box',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Connection settings',
                onPressed: _openSettingsSheet,
                icon: const Icon(Icons.tune),
              ),
              PopupMenuButton<_TranscriptAction>(
                onSelected: (action) {
                  switch (action) {
                    case _TranscriptAction.newThread:
                      _startFreshConversation();
                    case _TranscriptAction.clearTranscript:
                      _clearTranscript();
                  }
                },
                itemBuilder: (context) {
                  return const [
                    PopupMenuItem(
                      value: _TranscriptAction.newThread,
                      child: Text('New thread'),
                    ),
                    PopupMenuItem(
                      value: _TranscriptAction.clearTranscript,
                      child: Text('Clear transcript'),
                    ),
                  ];
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
            child: _sessionController.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        child: TranscriptList(
                          controller: _transcriptListController,
                          isConfigured: profile.isReady,
                          transcriptBlocks: _sessionController.transcriptBlocks,
                          pendingApprovalBlock:
                              _sessionController.pendingApprovalBlock,
                          pendingUserInputBlock:
                              _sessionController.pendingUserInputBlock,
                          onConfigure: _openSettingsSheet,
                          onApproveRequest: _sessionController.approveRequest,
                          onDenyRequest: _sessionController.denyRequest,
                          onSubmitUserInput: _sessionController.submitUserInput,
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: ChatComposer(
                            controller: _composerController,
                            enabled:
                                profile.isReady &&
                                !_sessionController.isLoading,
                            isBusy: sessionState.isBusy,
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

  Future<void> _openSettingsSheet() async {
    final result = await showModalBottomSheet<ConnectionSheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ConnectionSheet(
          initialProfile: _sessionController.profile,
          initialSecrets: _sessionController.secrets,
          initialPreferences: widget.preferences,
        );
      },
    );

    if (result == null) {
      return;
    }

    final connectionChanged =
        result.profile != _sessionController.profile ||
        result.secrets != _sessionController.secrets;
    final preferencesChanged = result.preferences != widget.preferences;

    if (preferencesChanged) {
      await widget.profileStore.savePreferences(result.preferences);
      widget.onPreferencesChanged(result.preferences);
    }

    if (!connectionChanged) {
      return;
    }

    await _sessionController.applyConnectionSettings(
      profile: result.profile,
      secrets: result.secrets,
    );
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

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _TranscriptAction { newThread, clearTranscript }
