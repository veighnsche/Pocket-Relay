import 'dart:async';

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/features/chat/models/codex_remote_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_composer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/connection_banner.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/conversation_entry_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/empty_state.dart';
import 'package:pocket_relay/src/features/chat/services/codex_session_reducer.dart';
import 'package:pocket_relay/src/features/chat/services/ssh_codex_service.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_sheet.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.profileStore,
    required this.remoteService,
  });

  final CodexProfileStore profileStore;
  final SshCodexService remoteService;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _composerController = TextEditingController();
  final _scrollController = ScrollController();
  final _sessionReducer = const CodexSessionReducer();

  ConnectionProfile _profile = ConnectionProfile.defaults();
  ConnectionSecrets _secrets = const ConnectionSecrets();
  CodexSessionState _sessionState = CodexSessionState.initial();

  bool _isLoading = true;
  StreamSubscription<CodexRemoteEvent>? _turnSubscription;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _turnSubscription?.cancel();
    unawaited(widget.remoteService.cancel());
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final savedProfile = await widget.profileStore.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _profile = savedProfile.profile;
      _secrets = savedProfile.secrets;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
              _profile.isReady
                  ? '${_profile.label} · ${_profile.host}'
                  : 'Configure a remote box',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black.withValues(alpha: 0.64),
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4EFE5), Color(0xFFECE4D4)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                    child: ConnectionBanner(
                      profile: _profile,
                      threadId: _sessionState.threadId,
                      isBusy: _sessionState.isBusy,
                      onConfigure: _openSettingsSheet,
                    ),
                  ),
                  Expanded(
                    child: _sessionState.blocks.isEmpty
                        ? EmptyState(
                            isConfigured: _profile.isReady,
                            onConfigure: _openSettingsSheet,
                          )
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                            itemBuilder: (context, index) {
                              return ConversationEntryCard(
                                block: _sessionState.blocks[index],
                              );
                            },
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemCount: _sessionState.blocks.length,
                          ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: ChatComposer(
                        controller: _composerController,
                        enabled: _profile.isReady && !_isLoading,
                        isBusy: _sessionState.isBusy,
                        onSend: _sendPrompt,
                        onStop: _stopActiveTurn,
                      ),
                    ),
                  ),
                ],
              ),
      ),
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
          initialProfile: _profile,
          initialSecrets: _secrets,
        );
      },
    );

    if (result == null) {
      return;
    }

    await widget.profileStore.save(result.profile, result.secrets);
    if (!mounted) {
      return;
    }

    setState(() {
      _profile = result.profile;
      _secrets = result.secrets;
      if (_profile.ephemeralSession) {
        _sessionState = _sessionReducer.detachThread(_sessionState);
      }
    });
  }

  Future<void> _sendPrompt() async {
    final prompt = _composerController.text.trim();
    if (prompt.isEmpty || _sessionState.isBusy) {
      return;
    }

    if (!_profile.isReady) {
      _showSnackBar('Fill in the remote connection details first.');
      return;
    }

    if (_profile.authMode == AuthMode.password && !_secrets.hasPassword) {
      _showSnackBar('This profile needs an SSH password.');
      return;
    }

    if (_profile.authMode == AuthMode.privateKey && !_secrets.hasPrivateKey) {
      _showSnackBar('This profile needs a private key.');
      return;
    }

    _composerController.clear();
    _applySessionState(
      _sessionReducer.addUserMessage(_sessionState, text: prompt),
      scrollToEnd: true,
    );

    await _turnSubscription?.cancel();
    _applySessionState(_sessionReducer.startLegacyTurn(_sessionState));
    _turnSubscription = widget.remoteService
        .runTurn(
          profile: _profile,
          secrets: _secrets,
          prompt: prompt,
          threadId: _profile.ephemeralSession ? null : _sessionState.threadId,
        )
        .listen(
          (event) => _applySessionState(
            _sessionReducer.reduceLegacyRemoteEvent(
              _sessionState,
              event,
              ephemeralSession: _profile.ephemeralSession,
            ),
            scrollToEnd: true,
          ),
          onDone: () {
            _applySessionState(
              _sessionReducer.finishLegacyStream(_sessionState),
            );
          },
        );
  }

  Future<void> _stopActiveTurn() async {
    await widget.remoteService.cancel();
    await _turnSubscription?.cancel();
    if (!mounted) {
      return;
    }
    _applySessionState(
      _sessionReducer.stopLegacyTurn(
        _sessionState,
        message: 'The active remote Codex turn was cancelled.',
      ),
      scrollToEnd: true,
    );
  }

  void _startFreshConversation() {
    _applySessionState(
      _sessionReducer.startFreshThread(
        _sessionState,
        message: 'The next prompt will start a fresh remote Codex session.',
      ),
      scrollToEnd: true,
    );
  }

  void _clearTranscript() {
    _applySessionState(_sessionReducer.clearTranscript(_sessionState));
  }

  void _applySessionState(
    CodexSessionState nextState, {
    bool scrollToEnd = false,
  }) {
    if (!mounted) {
      return;
    }

    setState(() {
      _sessionState = nextState;
    });

    if (scrollToEnd) {
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _TranscriptAction { newThread, clearTranscript }
