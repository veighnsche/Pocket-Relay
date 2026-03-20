import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_history_store.dart';
import 'package:pocket_relay/src/core/storage/codex_conversation_handoff_store.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/core/utils/platform_capabilities.dart';
import 'package:pocket_relay/src/core/utils/shell_utils.dart';
import 'package:pocket_relay/src/features/chat/application/runtime_event_mapper.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_reducer.dart';
import 'package:pocket_relay/src/features/chat/models/chat_conversation_recovery_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';

class ChatSessionController extends ChangeNotifier {
  ChatSessionController({
    required this.profileStore,
    this.conversationHandoffStore =
        const DiscardingCodexConversationHandoffStore(),
    this.conversationHistoryStore =
        const DiscardingCodexConversationHistoryStore(),
    this.conversationStateStore = const DiscardingCodexConversationStateStore(),
    required this.appServerClient,
    SavedProfile? initialSavedProfile,
    SavedConversationHandoff initialSavedConversationHandoff =
        const SavedConversationHandoff(),
    TranscriptReducer reducer = const TranscriptReducer(),
    CodexRuntimeEventMapper? runtimeEventMapper,
    bool? supportsLocalConnectionMode,
  }) : _sessionReducer = reducer,
       _runtimeEventMapper = runtimeEventMapper ?? CodexRuntimeEventMapper(),
       _supportsLocalConnectionMode =
           supportsLocalConnectionMode ?? supportsLocalCodexConnection() {
    final initial = initialSavedProfile;
    if (initial != null) {
      _profile = initial.profile;
      _secrets = initial.secrets;
      _isLoading = false;
    }
    _resumeThreadId = initialSavedConversationHandoff.normalizedResumeThreadId;
    _appServerEventSubscription = appServerClient.events.listen(
      _handleAppServerEvent,
    );
  }

  final CodexProfileStore profileStore;
  final CodexConversationHandoffStore conversationHandoffStore;
  final CodexConversationHistoryStore conversationHistoryStore;
  final CodexConversationStateStore conversationStateStore;
  final CodexAppServerClient appServerClient;

  final TranscriptReducer _sessionReducer;
  final CodexRuntimeEventMapper _runtimeEventMapper;
  final bool _supportsLocalConnectionMode;
  final _snackBarMessagesController = StreamController<String>.broadcast();

  ConnectionProfile _profile = ConnectionProfile.defaults();
  ConnectionSecrets _secrets = const ConnectionSecrets();
  CodexSessionState _sessionState = CodexSessionState.initial();
  ChatConversationRecoveryState? _conversationRecoveryState;

  bool _isLoading = true;
  bool _didInitialize = false;
  bool _isDisposed = false;
  bool _isTrackingSshBootstrapFailures = false;
  bool _sawTrackedSshBootstrapFailure = false;
  bool _suppressTrackedThreadReuse = false;
  String? _resumeThreadId;
  final Set<String> _threadMetadataHydrationAttempts = <String>{};
  StreamSubscription<CodexAppServerEvent>? _appServerEventSubscription;

  Stream<String> get snackBarMessages => _snackBarMessagesController.stream;

  ConnectionProfile get profile => _profile;
  ConnectionSecrets get secrets => _secrets;
  CodexSessionState get sessionState => _sessionState;
  ChatConversationRecoveryState? get conversationRecoveryState =>
      _conversationRecoveryState;
  bool get isLoading => _isLoading;
  List<CodexUiBlock> get transcriptBlocks => _sessionState.transcriptBlocks;

  Future<void> initialize() async {
    if (_didInitialize) {
      return;
    }
    _didInitialize = true;

    if (!_isLoading) {
      return;
    }

    final savedProfile = await profileStore.load();
    if (_isDisposed) {
      return;
    }

    _profile = savedProfile.profile;
    _secrets = savedProfile.secrets;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveObservedHostFingerprint(String blockId) async {
    final block = _findUnpinnedHostKeyBlock(blockId);
    if (block == null) {
      _emitSnackBar('This host fingerprint prompt is no longer available.');
      return;
    }
    if (block.isSaved) {
      return;
    }

    final currentFingerprint = _profile.hostFingerprint.trim();
    if (currentFingerprint.isNotEmpty) {
      if (normalizeFingerprint(currentFingerprint) ==
          normalizeFingerprint(block.fingerprint)) {
        _applySessionState(
          _sessionReducer.markUnpinnedHostKeySaved(
            _sessionState,
            blockId: blockId,
          ),
        );
        return;
      }

      _emitSnackBar(
        'This profile already has a different pinned host fingerprint. Review the connection settings before replacing it.',
      );
      return;
    }

    final nextProfile = _profile.copyWith(hostFingerprint: block.fingerprint);

    try {
      await profileStore.save(nextProfile, _secrets);
    } catch (_) {
      _emitSnackBar('Could not save the host fingerprint to this profile.');
      return;
    }
    if (_isDisposed) {
      return;
    }

    _profile = nextProfile;
    _applySessionState(
      _sessionReducer.markUnpinnedHostKeySaved(_sessionState, blockId: blockId),
    );
  }

  Future<bool> sendPrompt(String prompt) async {
    final normalizedPrompt = prompt.trim();
    if (normalizedPrompt.isEmpty ||
        _sessionState.isBusy ||
        _conversationRecoveryState != null) {
      return false;
    }

    final validationMessage = _validateProfileForSend();
    if (validationMessage != null) {
      _emitSnackBar(validationMessage);
      return false;
    }

    final rootThreadId = _sessionState.rootThreadId;
    if (rootThreadId != null && _sessionState.currentThreadId != rootThreadId) {
      selectTimeline(rootThreadId);
    }

    final recoveryState = _preflightConversationRecoveryState();
    if (recoveryState != null) {
      _setConversationRecovery(recoveryState);
      return false;
    }

    _applySessionState(
      _sessionReducer.addUserMessage(_sessionState, text: normalizedPrompt),
    );
    return _sendPromptWithAppServer(normalizedPrompt);
  }

  Future<void> stopActiveTurn() async {
    await _stopAppServerTurn();
  }

  void startFreshConversation() {
    _clearConversationRecovery();
    _clearContinuationThread();
    _applySessionState(
      _sessionReducer.startFreshThread(
        _sessionState,
        message: 'The next prompt will start a fresh Codex thread.',
      ),
    );
  }

  void clearTranscript() {
    _clearConversationRecovery();
    _clearContinuationThread();
    _applySessionState(_sessionReducer.clearTranscript(_sessionState));
  }

  void openConversationRecoveryAlternateSession() {
    final alternateThreadId = _conversationRecoveryState?.alternateThreadId
        ?.trim();
    if (alternateThreadId == null || alternateThreadId.isEmpty) {
      return;
    }

    final timeline = _sessionState.timelineForThread(alternateThreadId);
    if (timeline == null) {
      _emitSnackBar('That active session is no longer available locally.');
      return;
    }

    final nextRegistry = <String, CodexThreadRegistryEntry>{
      for (final entry in _sessionState.threadRegistry.entries)
        entry.key: entry.value.copyWith(
          isPrimary: entry.key == alternateThreadId,
        ),
    };

    _rememberContinuationThread(alternateThreadId);
    _clearConversationRecovery();
    _applySessionState(
      _sessionState.copyWith(
        rootThreadId: alternateThreadId,
        selectedThreadId: alternateThreadId,
        threadRegistry: nextRegistry,
      ),
    );
  }

  void selectTimeline(String threadId) {
    final normalizedThreadId = threadId.trim();
    if (normalizedThreadId.isEmpty ||
        _sessionState.currentThreadId == normalizedThreadId) {
      return;
    }

    final timeline = _sessionState.timelineForThread(normalizedThreadId);
    if (timeline == null) {
      return;
    }

    final nextTimelines = <String, CodexTimelineState>{
      for (final entry in _sessionState.timelinesByThreadId.entries)
        entry.key: entry.key == normalizedThreadId
            ? entry.value.copyWith(hasUnreadActivity: false)
            : entry.value,
    };
    _applySessionState(
      _sessionState.copyWith(
        selectedThreadId: normalizedThreadId,
        timelinesByThreadId: nextTimelines,
      ),
    );
  }

  Future<void> approveRequest(String requestId) {
    return _resolveApproval(requestId, approved: true);
  }

  Future<void> denyRequest(String requestId) {
    return _resolveApproval(requestId, approved: false);
  }

  Future<void> submitUserInput(
    String requestId,
    Map<String, List<String>> answers,
  ) async {
    final pendingRequest = _findPendingUserInputRequest(requestId);
    if (pendingRequest == null) {
      _emitSnackBar('This input request is no longer pending.');
      return;
    }

    try {
      if (pendingRequest.requestType ==
          CodexCanonicalRequestType.mcpServerElicitation) {
        await appServerClient.respondToElicitation(
          requestId: requestId,
          action: CodexAppServerElicitationAction.accept,
          content: _elicitationContentFromAnswers(answers),
        );
      } else {
        await appServerClient.answerUserInput(
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

  @override
  void dispose() {
    _isDisposed = true;
    _appServerEventSubscription?.cancel();
    unawaited(appServerClient.disconnect());
    unawaited(_snackBarMessagesController.close());
    super.dispose();
  }

  String? _validateProfileForSend() {
    if (!_profile.isReady) {
      return switch (_profile.connectionMode) {
        ConnectionMode.remote => 'Fill in the remote connection details first.',
        ConnectionMode.local => 'Fill in the local Codex settings first.',
      };
    }
    if (_profile.connectionMode == ConnectionMode.local) {
      if (!_supportsLocalConnectionMode) {
        return 'Local Codex is only available on desktop.';
      }
      return null;
    }
    if (_profile.authMode == AuthMode.password && !_secrets.hasPassword) {
      return 'This profile needs an SSH password.';
    }
    if (_profile.authMode == AuthMode.privateKey && !_secrets.hasPrivateKey) {
      return 'This profile needs a private key.';
    }
    return null;
  }

  void _applySessionState(CodexSessionState nextState) {
    if (_isDisposed) {
      return;
    }

    _sessionState = nextState;
    _schedulePersistConversationHandoff();
    notifyListeners();
  }

  void _setConversationRecovery(ChatConversationRecoveryState nextState) {
    final currentState = _conversationRecoveryState;
    if (currentState?.reason == nextState.reason &&
        currentState?.alternateThreadId == nextState.alternateThreadId &&
        currentState?.expectedThreadId == nextState.expectedThreadId &&
        currentState?.actualThreadId == nextState.actualThreadId) {
      return;
    }

    _conversationRecoveryState = nextState;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _clearConversationRecovery() {
    if (_conversationRecoveryState == null) {
      return;
    }

    _conversationRecoveryState = null;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  CodexSshUnpinnedHostKeyBlock? _findUnpinnedHostKeyBlock(String blockId) {
    for (final block in _sessionState.blocks) {
      if (block is CodexSshUnpinnedHostKeyBlock && block.id == blockId) {
        return block;
      }
    }
    return null;
  }

  void _handleAppServerEvent(CodexAppServerEvent event) {
    if (event is CodexAppServerRequestEvent &&
        _isUnsupportedHostRequest(event.method)) {
      unawaited(_handleUnsupportedHostRequest(event));
      return;
    }

    final runtimeEvents = _runtimeEventMapper.mapEvent(event);
    if (_isTrackingSshBootstrapFailures &&
        runtimeEvents.any(_isSshBootstrapFailureRuntimeEvent)) {
      _sawTrackedSshBootstrapFailure = true;
    }

    for (final runtimeEvent in runtimeEvents) {
      _applyRuntimeEvent(runtimeEvent);
    }
  }

  bool _isUnsupportedHostRequest(String method) {
    return method == 'account/chatgptAuthTokens/refresh' ||
        method == 'item/tool/call';
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
    );

    try {
      if (event.method == 'item/tool/call') {
        await appServerClient.respondDynamicToolCall(
          requestId: event.requestId,
          success: false,
          contentItems: <Map<String, Object?>>[
            <String, Object?>{'type': 'inputText', 'text': message},
          ],
        );
        return;
      }

      await appServerClient.rejectServerRequest(
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

  void _applyRuntimeEvent(CodexRuntimeEvent event) {
    _applySessionState(
      _sessionReducer.reduceRuntimeEvent(_sessionState, event),
    );
    if (event is CodexRuntimeThreadStartedEvent) {
      unawaited(_hydrateThreadMetadataIfNeeded(event));
    }
  }

  Future<bool> _sendPromptWithAppServer(String prompt) async {
    _isTrackingSshBootstrapFailures = true;
    _sawTrackedSshBootstrapFailure = false;
    try {
      final threadId = await _ensureAppServerThread();
      _clearConversationRecovery();
      _applySessionState(
        _sessionState.copyWith(
          connectionStatus: CodexRuntimeSessionState.running,
        ),
      );
      final turn = await appServerClient.sendUserMessage(
        threadId: threadId,
        text: prompt,
        model: _selectedModelOverride(),
        effort: _profile.reasoningEffort,
      );
      await _recordConversationHistory(threadId: turn.threadId, prompt: prompt);
      _rememberContinuationThread(turn.threadId);
      _applyRuntimeEvent(
        CodexRuntimeTurnStartedEvent(
          createdAt: DateTime.now(),
          threadId: turn.threadId,
          turnId: turn.turnId,
          rawMethod: 'turn/start(response)',
        ),
      );
      return true;
    } catch (error) {
      final unexpectedConversationThread = _unexpectedConversationThread(error);
      final isMissingConversation = _isMissingConversationThreadError(error);
      if (unexpectedConversationThread case (
        expectedThreadId: final expectedThreadId,
        actualThreadId: final actualThreadId,
      )) {
        _setConversationRecovery(
          ChatConversationRecoveryState(
            reason: ChatConversationRecoveryReason.unexpectedRemoteConversation,
            alternateThreadId: _alternateRecoveryThreadId(
              preferredThreadId: actualThreadId,
            ),
            expectedThreadId: expectedThreadId,
            actualThreadId: actualThreadId,
          ),
        );
      }
      if (isMissingConversation) {
        _setConversationRecovery(
          ChatConversationRecoveryState(
            reason: ChatConversationRecoveryReason.missingRemoteConversation,
            alternateThreadId: _alternateRecoveryThreadId(
              preferredThreadId: appServerClient.threadId,
            ),
          ),
        );
      }
      final failure = _sendFailurePresentation(error);
      if (_sessionState.activeTurn == null &&
          _sessionState.pendingLocalUserMessageBlockIds.isNotEmpty) {
        _applySessionState(
          _sessionReducer.clearLocalUserMessageCorrelationState(_sessionState),
        );
      }
      await Future<void>.microtask(() {});
      _reportAppServerFailure(
        title: failure.title,
        message: failure.message,
        error: error,
        runtimeErrorMessage: failure.runtimeErrorMessage,
        suppressRuntimeError: _sawTrackedSshBootstrapFailure,
        suppressSnackBar:
            isMissingConversation || unexpectedConversationThread != null,
      );
      return false;
    } finally {
      _isTrackingSshBootstrapFailures = false;
      _sawTrackedSshBootstrapFailure = false;
    }
  }

  Future<String> _ensureAppServerThread() async {
    await _ensureAppServerConnected();

    final activeThreadId = _activeConversationThreadId();
    if (activeThreadId != null) {
      _rememberContinuationThread(activeThreadId);
      return activeThreadId;
    }

    final resumeThreadId = _resumeConversationThreadId();
    final session = await appServerClient.startSession(
      model: _selectedModelOverride(),
      reasoningEffort: _profile.reasoningEffort,
      resumeThreadId: resumeThreadId,
    );
    _rememberContinuationThread(session.threadId);
    _applyRuntimeEvent(
      CodexRuntimeThreadStartedEvent(
        createdAt: DateTime.now(),
        threadId: session.threadId,
        providerThreadId: session.threadId,
        rawMethod: resumeThreadId == null
            ? 'thread/start(response)'
            : 'thread/resume(response)',
        threadName: session.thread?.name,
        sourceKind: session.thread?.sourceKind,
        agentNickname: session.thread?.agentNickname,
        agentRole: session.thread?.agentRole,
      ),
    );
    return session.threadId;
  }

  Future<void> _ensureAppServerConnected() async {
    if (appServerClient.isConnected) {
      return;
    }

    await appServerClient.connect(profile: _profile, secrets: _secrets);
  }

  String? _selectedModelOverride() {
    final model = _profile.model.trim();
    return model.isEmpty ? null : model;
  }

  Future<void> _stopAppServerTurn() async {
    try {
      final targetTimeline =
          _sessionState.selectedTimeline ?? _sessionState.rootTimeline;
      final turnId = targetTimeline?.activeTurn?.turnId;
      if (targetTimeline == null || turnId == null) {
        return;
      }
      await appServerClient.abortTurn(
        threadId: targetTimeline.threadId,
        turnId: turnId,
      );
    } catch (error) {
      _reportAppServerFailure(
        title: 'Stop failed',
        message: 'Could not stop the active Codex turn.',
        error: error,
      );
    }
  }

  Future<void> _resolveApproval(
    String requestId, {
    required bool approved,
  }) async {
    final pendingRequest = _findPendingApprovalRequest(requestId);
    if (pendingRequest == null) {
      _emitSnackBar('This approval request is no longer pending.');
      return;
    }

    try {
      await appServerClient.resolveApproval(
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

  CodexSessionPendingRequest? _findPendingApprovalRequest(String requestId) {
    final ownerTimeline = _ownerTimelineForRequest(requestId);
    if (ownerTimeline != null) {
      return ownerTimeline.pendingApprovalRequests[requestId];
    }

    return _sessionState.pendingApprovalRequests[requestId];
  }

  CodexSessionPendingUserInputRequest? _findPendingUserInputRequest(
    String requestId,
  ) {
    final ownerTimeline = _ownerTimelineForRequest(requestId);
    if (ownerTimeline != null) {
      return ownerTimeline.pendingUserInputRequests[requestId];
    }

    return _sessionState.pendingUserInputRequests[requestId];
  }

  CodexTimelineState? _ownerTimelineForRequest(String requestId) {
    final ownerThreadId = _sessionState.requestOwnerById[requestId];
    if (ownerThreadId != null && ownerThreadId.isNotEmpty) {
      final ownerTimeline = _sessionState.timelineForThread(ownerThreadId);
      if (ownerTimeline != null) {
        return ownerTimeline;
      }
    }

    for (final timeline in _sessionState.timelinesByThreadId.values) {
      if (timeline.pendingApprovalRequests.containsKey(requestId) ||
          timeline.pendingUserInputRequests.containsKey(requestId)) {
        return timeline;
      }
    }

    return null;
  }

  Future<void> _hydrateThreadMetadataIfNeeded(
    CodexRuntimeThreadStartedEvent event,
  ) async {
    final threadId = event.providerThreadId.trim();
    if (!_shouldHydrateThreadMetadata(threadId, event)) {
      return;
    }

    _threadMetadataHydrationAttempts.add(threadId);
    try {
      final thread = await appServerClient.readThread(threadId: threadId);
      if (_isDisposed || !_hasThreadMetadata(thread)) {
        return;
      }

      _applyRuntimeEvent(
        CodexRuntimeThreadStartedEvent(
          createdAt: DateTime.now(),
          threadId: thread.id,
          providerThreadId: thread.id,
          rawMethod: 'thread/read(response)',
          threadName: thread.name,
          sourceKind: thread.sourceKind,
          agentNickname: thread.agentNickname,
          agentRole: thread.agentRole,
        ),
      );
    } catch (_) {
      // Thread metadata hydration is best-effort only.
    }
  }

  bool _shouldHydrateThreadMetadata(
    String threadId,
    CodexRuntimeThreadStartedEvent event,
  ) {
    if (threadId.isEmpty ||
        event.rawMethod == 'thread/read(response)' ||
        _threadMetadataHydrationAttempts.contains(threadId)) {
      return false;
    }

    final existingEntry = _sessionState.threadRegistry[threadId];
    return !_hasThreadDisplayMetadataValues(
      threadName: existingEntry?.threadName ?? event.threadName,
      agentNickname: existingEntry?.agentNickname ?? event.agentNickname,
      agentRole: existingEntry?.agentRole ?? event.agentRole,
    );
  }

  bool _hasThreadMetadata(CodexAppServerThread thread) {
    return _hasThreadMetadataValues(
      threadName: thread.name,
      agentNickname: thread.agentNickname,
      agentRole: thread.agentRole,
      sourceKind: thread.sourceKind,
    );
  }

  bool _hasThreadMetadataValues({
    String? threadName,
    String? agentNickname,
    String? agentRole,
    String? sourceKind,
  }) {
    return _hasNonEmptyValue(threadName) ||
        _hasNonEmptyValue(agentNickname) ||
        _hasNonEmptyValue(agentRole) ||
        _hasNonEmptyValue(sourceKind);
  }

  bool _hasThreadDisplayMetadataValues({
    String? threadName,
    String? agentNickname,
    String? agentRole,
  }) {
    return _hasNonEmptyValue(threadName) ||
        _hasNonEmptyValue(agentNickname) ||
        _hasNonEmptyValue(agentRole);
  }

  bool _hasNonEmptyValue(String? value) {
    return value != null && value.trim().isNotEmpty;
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
    String? runtimeErrorMessage,
    bool suppressRuntimeError = false,
    bool suppressSnackBar = false,
  }) {
    final now = DateTime.now();
    _applyRuntimeEvent(
      CodexRuntimeSessionStateChangedEvent(
        createdAt: now,
        state: CodexRuntimeSessionState.ready,
        reason: message,
        rawMethod: 'app-server/failure',
      ),
    );
    if (!suppressRuntimeError) {
      _applyRuntimeEvent(
        CodexRuntimeErrorEvent(
          createdAt: now,
          message: runtimeErrorMessage ?? '$title: $error',
          errorClass: CodexRuntimeErrorClass.transportError,
          rawMethod: 'app-server/failure',
        ),
      );
    }
    if (!suppressSnackBar) {
      _emitSnackBar(message);
    }
  }

  ({String title, String message, String? runtimeErrorMessage})
  _sendFailurePresentation(Object error) {
    if (_unexpectedConversationThread(error) case (
      expectedThreadId: final expectedThreadId,
      actualThreadId: final actualThreadId,
    )) {
      final message =
          'Pocket Relay expected remote conversation "$expectedThreadId", '
          'but the remote session returned "$actualThreadId". Sending is '
          'blocked to avoid attaching your draft to a different conversation.';
      return (
        title: 'Conversation changed',
        message: message,
        runtimeErrorMessage: message,
      );
    }

    if (_isMissingConversationThreadError(error)) {
      const message =
          'Could not continue this conversation because the remote conversation was not found. Start a fresh conversation to continue.';
      return (
        title: 'Conversation unavailable',
        message: message,
        runtimeErrorMessage: message,
      );
    }

    return (
      title: 'Send failed',
      message: 'Could not send the prompt to the ${_sessionLabel()} session.',
      runtimeErrorMessage: null,
    );
  }

  bool _isSshBootstrapFailureRuntimeEvent(CodexRuntimeEvent event) {
    return switch (event) {
      CodexRuntimeSshConnectFailedEvent() ||
      CodexRuntimeSshHostKeyMismatchEvent() ||
      CodexRuntimeSshAuthenticationFailedEvent() ||
      CodexRuntimeSshRemoteLaunchFailedEvent() => true,
      _ => false,
    };
  }

  void _emitSnackBar(String message) {
    if (_isDisposed || _snackBarMessagesController.isClosed) {
      return;
    }
    _snackBarMessagesController.add(message);
  }

  String? _activeConversationThreadId() {
    if (_profile.ephemeralSession) {
      return null;
    }

    return _normalizedThreadId(_sessionState.rootThreadId);
  }

  String? _resumeConversationThreadId() {
    if (_profile.ephemeralSession) {
      return null;
    }

    return _normalizedThreadId(_resumeThreadId);
  }

  String? _trackedThreadReuseCandidate() {
    if (_profile.ephemeralSession ||
        _suppressTrackedThreadReuse ||
        _sessionState.hasMultipleTimelines) {
      return null;
    }

    return _normalizedThreadId(appServerClient.threadId);
  }

  ChatConversationRecoveryState? _preflightConversationRecoveryState() {
    if (_activeConversationThreadId() != null ||
        _resumeConversationThreadId() != null) {
      return null;
    }

    final trackedThreadId = _trackedThreadReuseCandidate();
    if (trackedThreadId == null || !_hasConversationHistory()) {
      return null;
    }

    return ChatConversationRecoveryState(
      reason: ChatConversationRecoveryReason.detachedTranscript,
      alternateThreadId: _alternateRecoveryThreadId(
        preferredThreadId: trackedThreadId,
      ),
    );
  }

  String? _alternateRecoveryThreadId({String? preferredThreadId}) {
    final normalizedPreferred = _normalizedThreadId(preferredThreadId);
    final currentRootThreadId = _normalizedThreadId(_sessionState.rootThreadId);
    if (normalizedPreferred != null &&
        normalizedPreferred != currentRootThreadId &&
        _sessionState.timelineForThread(normalizedPreferred) != null) {
      return normalizedPreferred;
    }
    return null;
  }

  bool _hasConversationHistory() {
    return _sessionState.transcriptBlocks.any((block) {
      return switch (block.kind) {
        CodexUiBlockKind.userMessage ||
        CodexUiBlockKind.assistantMessage ||
        CodexUiBlockKind.reasoning ||
        CodexUiBlockKind.plan ||
        CodexUiBlockKind.proposedPlan ||
        CodexUiBlockKind.workLogEntry ||
        CodexUiBlockKind.workLogGroup ||
        CodexUiBlockKind.changedFiles ||
        CodexUiBlockKind.approvalRequest ||
        CodexUiBlockKind.userInputRequest ||
        CodexUiBlockKind.usage ||
        CodexUiBlockKind.turnBoundary => true,
        CodexUiBlockKind.status || CodexUiBlockKind.error => false,
      };
    });
  }

  void _rememberContinuationThread(String? threadId) {
    final normalizedThreadId = _normalizedThreadId(threadId);
    if (normalizedThreadId == null) {
      return;
    }

    _resumeThreadId = normalizedThreadId;
    _suppressTrackedThreadReuse = false;
    _schedulePersistConversationHandoff();
  }

  void _clearContinuationThread() {
    _resumeThreadId = null;
    _suppressTrackedThreadReuse = true;
    _schedulePersistConversationHandoff();
  }

  String? _normalizedThreadId(String? value) {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }
    return normalizedValue;
  }

  bool _isMissingConversationThreadError(Object error) {
    final normalizedMessage = error.toString().toLowerCase();
    if (!normalizedMessage.contains('thread')) {
      return false;
    }

    return const <String>[
      'thread not found',
      'missing thread',
      'no such thread',
      'unknown thread',
      'does not exist',
    ].any(normalizedMessage.contains);
  }

  ({String expectedThreadId, String actualThreadId})?
  _unexpectedConversationThread(Object error) {
    if (error is! CodexAppServerException) {
      return null;
    }

    final payload = _asObject(error.data);
    final expectedThreadId = _normalizedThreadId(
      _asString(payload?['expectedThreadId']),
    );
    final actualThreadId = _normalizedThreadId(
      _asString(payload?['actualThreadId']),
    );
    if (expectedThreadId == null || actualThreadId == null) {
      return null;
    }

    return (expectedThreadId: expectedThreadId, actualThreadId: actualThreadId);
  }

  void _schedulePersistConversationHandoff() {
    if (_isDisposed) {
      return;
    }

    final handoff = SavedConversationHandoff(
      resumeThreadId:
          _activeConversationThreadId() ?? _resumeConversationThreadId(),
    );
    unawaited(_persistConversationHandoff(handoff));
  }

  Future<void> _persistConversationHandoff(
    SavedConversationHandoff handoff,
  ) async {
    try {
      final currentState = await conversationStateStore.loadState();
      await conversationStateStore.saveState(
        currentState.copyWith(
          selectedThreadId: handoff.normalizedResumeThreadId,
          clearSelectedThreadId: handoff.normalizedResumeThreadId == null,
        ),
      );
      await conversationHandoffStore.save(handoff);
    } catch (_) {
      // Conversation handoff persistence must not break the active session.
    }
  }

  String _sessionLabel() {
    return switch (_profile.connectionMode) {
      ConnectionMode.remote => 'remote Codex',
      ConnectionMode.local => 'local Codex',
    };
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

  Future<void> _recordConversationHistory({
    required String threadId,
    required String prompt,
  }) async {
    final normalizedThreadId = _normalizedThreadId(threadId);
    if (normalizedThreadId == null) {
      return;
    }

    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty) {
      return;
    }

    final now = DateTime.now();
    try {
      final currentState = await conversationStateStore.loadState();
      final currentHistory = currentState.conversations;
      final updatedHistory = <SavedResumableConversation>[];
      SavedResumableConversation? matchingEntry;
      for (final entry in currentHistory) {
        if (entry.normalizedThreadId == normalizedThreadId) {
          matchingEntry = entry;
          continue;
        }
        updatedHistory.add(entry);
      }

      final nextEntry =
          matchingEntry?.copyWith(
            preview: matchingEntry.preview.trim().isEmpty
                ? trimmedPrompt
                : matchingEntry.preview,
            messageCount: matchingEntry.messageCount + 1,
            firstPromptAt: matchingEntry.firstPromptAt ?? now,
            lastActivityAt: now,
          ) ??
          SavedResumableConversation(
            threadId: normalizedThreadId,
            preview: trimmedPrompt,
            messageCount: 1,
            firstPromptAt: now,
            lastActivityAt: now,
          );
      updatedHistory.insert(0, nextEntry);
      await conversationStateStore.saveState(
        currentState.copyWith(
          selectedThreadId: normalizedThreadId,
          conversations: updatedHistory,
        ),
      );
      await conversationHistoryStore.save(updatedHistory);
    } catch (_) {
      // Conversation history persistence must not break the active session.
    }
  }
}
