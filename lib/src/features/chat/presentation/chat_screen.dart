import 'dart:async';

import 'package:pocket_relay/src/core/models/app_preferences.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/models/codex_remote_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_composer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/conversation_entry_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/empty_state.dart';
import 'package:pocket_relay/src/features/chat/services/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/services/codex_runtime_event_mapper.dart';
import 'package:pocket_relay/src/features/chat/services/codex_session_reducer.dart';
import 'package:pocket_relay/src/features/chat/services/ssh_codex_service.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_sheet.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.profileStore,
    required this.remoteService,
    this.appServerClient,
    this.initialSavedProfile,
    required this.preferences,
    required this.onPreferencesChanged,
  });

  final CodexProfileStore profileStore;
  final SshCodexService remoteService;
  final CodexAppServerClient? appServerClient;
  final SavedProfile? initialSavedProfile;
  final AppPreferences preferences;
  final ValueChanged<AppPreferences> onPreferencesChanged;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const double _autoScrollResumeDistance = 72;

  final _composerController = TextEditingController();
  final _scrollController = ScrollController();
  final _sessionReducer = const CodexSessionReducer();
  final _runtimeEventMapper = CodexRuntimeEventMapper();

  ConnectionProfile _profile = ConnectionProfile.defaults();
  ConnectionSecrets _secrets = const ConnectionSecrets();
  CodexSessionState _sessionState = CodexSessionState.initial();

  bool _isLoading = true;
  bool _shouldFollowTranscript = true;
  CodexAppServerClient? _appServerClient;
  StreamSubscription<CodexRemoteEvent>? _turnSubscription;
  StreamSubscription<CodexAppServerEvent>? _appServerEventSubscription;

  bool get _usesAppServer => _appServerClient != null;

  @override
  void initState() {
    super.initState();
    _appServerClient = widget.appServerClient;
    if (_usesAppServer) {
      _appServerEventSubscription = _appServerClient!.events.listen(
        _handleAppServerEvent,
      );
    }
    final initialSavedProfile = widget.initialSavedProfile;
    if (initialSavedProfile == null) {
      _loadProfile();
      return;
    }

    _profile = initialSavedProfile.profile;
    _secrets = initialSavedProfile.secrets;
    _isLoading = false;
  }

  @override
  void dispose() {
    _turnSubscription?.cancel();
    _appServerEventSubscription?.cancel();
    if (_usesAppServer) {
      unawaited(_appServerClient!.disconnect());
    } else {
      unawaited(widget.remoteService.cancel());
    }
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
    final theme = Theme.of(context);
    final palette = context.pocketPalette;
    final transcriptBlocks = _sessionState.transcriptBlocks;
    final pendingApprovalBlock = _sessionState.primaryPendingApprovalBlock;
    final pendingUserInputBlock = _sessionState.primaryPendingUserInputBlock;
    final hasVisibleConversation =
        transcriptBlocks.isNotEmpty ||
        pendingApprovalBlock != null ||
        pendingUserInputBlock != null;

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
            colors: <Color>[palette.backgroundTop, palette.backgroundBottom],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: !hasVisibleConversation
                        ? EmptyState(
                            isConfigured: _profile.isReady,
                            onConfigure: _openSettingsSheet,
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: _handleTranscriptScrollNotification,
                            child: ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                              itemBuilder: (context, index) {
                                return ConversationEntryCard(
                                  block: transcriptBlocks[index],
                                  onApproveRequest: _approveRequest,
                                  onDenyRequest: _denyRequest,
                                  onSubmitUserInput: _submitUserInput,
                                );
                              },
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 8),
                              itemCount: transcriptBlocks.length,
                            ),
                          ),
                  ),
                  if (pendingApprovalBlock != null ||
                      pendingUserInputBlock != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              if (pendingApprovalBlock != null)
                                ConversationEntryCard(
                                  block: pendingApprovalBlock,
                                  onApproveRequest: _approveRequest,
                                  onDenyRequest: _denyRequest,
                                  onSubmitUserInput: _submitUserInput,
                                ),
                              if (pendingApprovalBlock != null &&
                                  pendingUserInputBlock != null)
                                const SizedBox(height: 8),
                              if (pendingUserInputBlock != null)
                                ConversationEntryCard(
                                  block: pendingUserInputBlock,
                                  onApproveRequest: _approveRequest,
                                  onDenyRequest: _denyRequest,
                                  onSubmitUserInput: _submitUserInput,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
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
          initialPreferences: widget.preferences,
        );
      },
    );

    if (result == null) {
      return;
    }

    final connectionChanged =
        result.profile != _profile || result.secrets != _secrets;
    final preferencesChanged = result.preferences != widget.preferences;

    if (preferencesChanged) {
      await widget.profileStore.savePreferences(result.preferences);
      widget.onPreferencesChanged(result.preferences);
    }

    if (!connectionChanged) {
      return;
    }

    await widget.profileStore.save(result.profile, result.secrets);
    if (_usesAppServer) {
      await _appServerClient!.disconnect();
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _profile = result.profile;
      _secrets = result.secrets;
      _sessionState = _sessionReducer.detachThread(_sessionState);
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
    _requestTranscriptFollow();
    _applySessionState(
      _sessionReducer.addUserMessage(_sessionState, text: prompt),
      scrollToEnd: true,
    );

    if (_usesAppServer) {
      await _sendPromptWithAppServer(prompt);
      return;
    }

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
    if (_usesAppServer) {
      await _stopAppServerTurn();
      return;
    }

    await widget.remoteService.cancel();
    await _turnSubscription?.cancel();
    if (!mounted) {
      return;
    }
    _requestTranscriptFollow();
    _applySessionState(
      _sessionReducer.stopLegacyTurn(
        _sessionState,
        message: 'The active remote Codex turn was cancelled.',
      ),
      scrollToEnd: true,
    );
  }

  void _startFreshConversation() {
    _requestTranscriptFollow();
    _applySessionState(
      _sessionReducer.startFreshThread(
        _sessionState,
        message: _usesAppServer
            ? 'The next prompt will start a fresh remote Codex thread.'
            : 'The next prompt will start a fresh remote Codex session.',
      ),
      scrollToEnd: true,
    );
  }

  void _clearTranscript() {
    _requestTranscriptFollow();
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

      if (!_shouldFollowTranscript) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  bool _handleTranscriptScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) {
      return false;
    }

    final isUserDriven = switch (notification) {
      ScrollUpdateNotification(:final dragDetails) => dragDetails != null,
      OverscrollNotification(:final dragDetails) => dragDetails != null,
      ScrollEndNotification() => true,
      UserScrollNotification() => true,
      _ => false,
    };

    if (!isUserDriven) {
      return false;
    }

    _shouldFollowTranscript = _isNearTranscriptBottom(notification.metrics);
    return false;
  }

  bool _isNearTranscriptBottom([ScrollMetrics? metrics]) {
    final activeMetrics =
        metrics ?? (_scrollController.hasClients ? _scrollController.position : null);
    if (activeMetrics == null) {
      return true;
    }

    return activeMetrics.maxScrollExtent - activeMetrics.pixels <=
        _autoScrollResumeDistance;
  }

  void _requestTranscriptFollow() {
    _shouldFollowTranscript = true;
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleAppServerEvent(CodexAppServerEvent event) {
    if (event is CodexAppServerRequestEvent &&
        _isUnsupportedHostRequest(event.method)) {
      unawaited(_handleUnsupportedHostRequest(event));
      return;
    }

    for (final runtimeEvent in _runtimeEventMapper.mapEvent(event)) {
      _handleRuntimeEvent(runtimeEvent);
    }
  }

  bool _isUnsupportedHostRequest(String method) {
    return method == 'account/chatgptAuthTokens/refresh' ||
        method == 'item/tool/call' ||
        method == 'item/fileRead/requestApproval';
  }

  Future<void> _handleUnsupportedHostRequest(
    CodexAppServerRequestEvent event,
  ) async {
    final payload = _asObject(event.params);
    final threadId = _asString(payload?['threadId']);
    final turnId = _asString(payload?['turnId']);
    final itemId = _asString(payload?['itemId']);
    final toolName = _asString(payload?['tool']) ?? 'dynamic tool';

    final (title, message) = switch (event.method) {
      'account/chatgptAuthTokens/refresh' => (
        'Auth refresh unsupported',
        'Pocket Relay does not manage external ChatGPT tokens, so this app-server auth refresh request was rejected.',
      ),
      'item/tool/call' => (
        'Dynamic tool unsupported',
        'Pocket Relay does not implement the experimental host-side tool "$toolName", so the request was rejected.',
      ),
      'item/fileRead/requestApproval' => (
        'File read approval unsupported',
        'Pocket Relay received a legacy file-read approval request that this client does not implement, so the request was rejected.',
      ),
      _ => (
        'Request unsupported',
        'Pocket Relay rejected an unsupported app-server request.',
      ),
    };

    _applyRuntimeEvent(
      CodexRuntimeStatusEvent(
        createdAt: DateTime.now(),
        threadId: threadId,
        turnId: turnId,
        itemId: itemId,
        requestId: event.requestId,
        rawMethod: event.method,
        rawPayload: event.params,
        title: title,
        message: message,
      ),
      scrollToEnd: true,
    );

    try {
      if (event.method == 'item/tool/call') {
        await _appServerClient!.respondDynamicToolCall(
          requestId: event.requestId,
          success: false,
          contentItems: <Map<String, Object?>>[
            <String, Object?>{'type': 'inputText', 'text': message},
          ],
        );
        return;
      }

      await _appServerClient!.rejectServerRequest(
        requestId: event.requestId,
        message: message,
      );
    } catch (error) {
      _reportAppServerFailure(
        title: 'Request handling failed',
        message: 'Could not reject an unsupported app-server request.',
        error: error,
      );
    }
  }

  void _handleRuntimeEvent(CodexRuntimeEvent event) {
    _applyRuntimeEvent(event, scrollToEnd: true);
  }

  void _applyRuntimeEvent(
    CodexRuntimeEvent event, {
    required bool scrollToEnd,
  }) {
    _applySessionState(
      _sessionReducer.reduceRuntimeEvent(_sessionState, event),
      scrollToEnd: scrollToEnd,
    );
  }

  Future<void> _sendPromptWithAppServer(String prompt) async {
    try {
      final threadId = await _ensureAppServerThread();
      _applySessionState(
        _sessionState.copyWith(
          connectionStatus: CodexRuntimeSessionState.running,
        ),
      );
      final turn = await _appServerClient!.sendUserMessage(
        threadId: threadId,
        text: prompt,
      );
      _applyRuntimeEvent(
        CodexRuntimeTurnStartedEvent(
          createdAt: DateTime.now(),
          threadId: turn.threadId,
          turnId: turn.turnId,
          rawMethod: 'turn/start(response)',
        ),
        scrollToEnd: false,
      );
    } catch (error) {
      _reportAppServerFailure(
        title: 'Send failed',
        message: 'Could not send the prompt to the remote Codex session.',
        error: error,
      );
    }
  }

  Future<String> _ensureAppServerThread() async {
    final client = _appServerClient;
    if (client == null) {
      throw StateError('App-server transport is not available.');
    }

    await _ensureAppServerConnected();

    final resumeThreadId = _profile.ephemeralSession
        ? null
        : _sessionState.threadId;
    if (resumeThreadId != null &&
        resumeThreadId.isNotEmpty &&
        client.threadId == resumeThreadId) {
      return resumeThreadId;
    }

    final session = await client.startSession(resumeThreadId: resumeThreadId);
    _applyRuntimeEvent(
      CodexRuntimeThreadStartedEvent(
        createdAt: DateTime.now(),
        threadId: session.threadId,
        providerThreadId: session.threadId,
        rawMethod: resumeThreadId == null
            ? 'thread/start(response)'
            : 'thread/resume(response)',
      ),
      scrollToEnd: false,
    );
    return session.threadId;
  }

  Future<void> _ensureAppServerConnected() async {
    final client = _appServerClient;
    if (client == null || client.isConnected) {
      return;
    }

    await client.connect(profile: _profile, secrets: _secrets);
  }

  Future<void> _stopAppServerTurn() async {
    final client = _appServerClient;
    if (client == null) {
      return;
    }

    try {
      await client.abortTurn(
        threadId: _sessionState.threadId,
        turnId: _sessionState.turnId,
      );
    } catch (error) {
      _reportAppServerFailure(
        title: 'Stop failed',
        message: 'Could not stop the active Codex turn.',
        error: error,
      );
    }
  }

  Future<void> _approveRequest(String requestId) {
    return _resolveApproval(requestId, approved: true);
  }

  Future<void> _denyRequest(String requestId) {
    return _resolveApproval(requestId, approved: false);
  }

  Future<void> _resolveApproval(
    String requestId, {
    required bool approved,
  }) async {
    if (!_usesAppServer) {
      return;
    }

    try {
      await _appServerClient!.resolveApproval(
        requestId: requestId,
        approved: approved,
      );
    } catch (error) {
      _reportAppServerFailure(
        title: approved ? 'Approval failed' : 'Denial failed',
        message: 'Could not submit the decision for this request.',
        error: error,
      );
    }
  }

  Future<void> _submitUserInput(
    String requestId,
    Map<String, List<String>> answers,
  ) async {
    if (!_usesAppServer) {
      return;
    }

    final pendingRequest = _sessionState.pendingUserInputRequests[requestId];
    if (pendingRequest == null) {
      _showSnackBar('This input request is no longer pending.');
      return;
    }

    try {
      if (pendingRequest.requestType ==
          CodexCanonicalRequestType.mcpServerElicitation) {
        await _appServerClient!.respondToElicitation(
          requestId: requestId,
          action: CodexAppServerElicitationAction.accept,
          content: _elicitationContentFromAnswers(answers),
        );
      } else {
        await _appServerClient!.answerUserInput(
          requestId: requestId,
          answers: answers,
        );
      }
    } catch (error) {
      _reportAppServerFailure(
        title: 'Input failed',
        message: 'Could not submit the requested user input.',
        error: error,
      );
    }
  }

  Object? _elicitationContentFromAnswers(Map<String, List<String>> answers) {
    if (answers.length == 1) {
      final entry = answers.entries.single;
      final values = entry.value;
      if (entry.key == 'response' && values.length == 1) {
        return values.single;
      }
      if (values.length == 1) {
        return <String, Object?>{entry.key: values.single};
      }
    }

    return answers.map<String, Object?>((key, values) {
      if (values.isEmpty) {
        return MapEntry<String, Object?>(key, null);
      }
      if (values.length == 1) {
        return MapEntry<String, Object?>(key, values.single);
      }
      return MapEntry<String, Object?>(key, values);
    });
  }

  void _reportAppServerFailure({
    required String title,
    required String message,
    required Object error,
  }) {
    final now = DateTime.now();
    _applyRuntimeEvent(
      CodexRuntimeSessionStateChangedEvent(
        createdAt: now,
        state: CodexRuntimeSessionState.ready,
        reason: message,
        rawMethod: 'app-server/failure',
      ),
      scrollToEnd: false,
    );
    _applyRuntimeEvent(
      CodexRuntimeErrorEvent(
        createdAt: now,
        message: '$title: $error',
        errorClass: CodexRuntimeErrorClass.transportError,
        rawMethod: 'app-server/failure',
      ),
      scrollToEnd: true,
    );
    _showSnackBar(message);
  }

  static Map<String, dynamic>? _asObject(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static String? _asString(Object? value) {
    return value is String ? value : null;
  }
}

enum _TranscriptAction { newThread, clearTranscript }
