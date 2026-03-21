import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_state_store.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/core/utils/platform_capabilities.dart';
import 'package:pocket_relay/src/core/utils/shell_utils.dart';
import 'package:pocket_relay/src/features/chat/application/chat_conversation_selection_coordinator.dart';
import 'package:pocket_relay/src/features/chat/application/chat_conversation_recovery_policy.dart';
import 'package:pocket_relay/src/features/chat/application/chat_historical_conversation_restorer.dart';
import 'package:pocket_relay/src/features/chat/application/codex_historical_conversation_normalizer.dart';
import 'package:pocket_relay/src/features/chat/application/runtime_event_mapper.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_reducer.dart';
import 'package:pocket_relay/src/features/chat/models/chat_conversation_recovery_state.dart';
import 'package:pocket_relay/src/features/chat/models/chat_historical_conversation_restore_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';

class ChatSessionController extends ChangeNotifier {
  ChatSessionController({
    required this.profileStore,
    CodexConversationStateStore conversationStateStore =
        const DiscardingCodexConversationStateStore(),
    required this.appServerClient,
    SavedProfile? initialSavedProfile,
    SavedConnectionConversationState initialConversationState =
        const SavedConnectionConversationState(),
    TranscriptReducer reducer = const TranscriptReducer(),
    CodexRuntimeEventMapper? runtimeEventMapper,
    CodexHistoricalConversationNormalizer historicalConversationNormalizer =
        const CodexHistoricalConversationNormalizer(),
    ChatHistoricalConversationRestorer? historicalConversationRestorer,
    bool? supportsLocalConnectionMode,
  }) : _sessionReducer = reducer,
       _runtimeEventMapper = runtimeEventMapper ?? CodexRuntimeEventMapper(),
       _historicalConversationNormalizer = historicalConversationNormalizer,
       _historicalConversationRestorer =
           historicalConversationRestorer ??
           ChatHistoricalConversationRestorer(reducer: reducer),
       _conversationSelection = ChatConversationSelectionCoordinator(
         conversationStateStore: conversationStateStore,
         initialConversationState: initialConversationState,
       ),
       _supportsLocalConnectionMode =
           supportsLocalConnectionMode ?? supportsLocalCodexConnection() {
    final initial = initialSavedProfile;
    if (initial != null) {
      _profile = initial.profile;
      _secrets = initial.secrets;
      _isLoading = false;
    }
    _appServerEventSubscription = appServerClient.events.listen(
      _handleAppServerEvent,
    );
  }

  final CodexProfileStore profileStore;
  final CodexAppServerClient appServerClient;

  final TranscriptReducer _sessionReducer;
  final CodexRuntimeEventMapper _runtimeEventMapper;
  final CodexHistoricalConversationNormalizer _historicalConversationNormalizer;
  final ChatHistoricalConversationRestorer _historicalConversationRestorer;
  final ChatConversationSelectionCoordinator _conversationSelection;
  final ChatConversationRecoveryPolicy _conversationRecoveryPolicy =
      const ChatConversationRecoveryPolicy();
  final bool _supportsLocalConnectionMode;
  final _snackBarMessagesController = StreamController<String>.broadcast();

  ConnectionProfile _profile = ConnectionProfile.defaults();
  ConnectionSecrets _secrets = const ConnectionSecrets();
  CodexSessionState _sessionState = CodexSessionState.initial();
  ChatConversationRecoveryState? _conversationRecoveryState;
  ChatHistoricalConversationRestoreState? _historicalConversationRestoreState;

  bool _isLoading = true;
  bool _isDisposed = false;
  bool _isTrackingSshBootstrapFailures = false;
  bool _sawTrackedSshBootstrapFailure = false;
  final Set<String> _threadMetadataHydrationAttempts = <String>{};
  StreamSubscription<CodexAppServerEvent>? _appServerEventSubscription;
  Future<void>? _initializationFuture;

  Stream<String> get snackBarMessages => _snackBarMessagesController.stream;

  ConnectionProfile get profile => _profile;
  ConnectionSecrets get secrets => _secrets;
  CodexSessionState get sessionState => _sessionState;
  ChatConversationRecoveryState? get conversationRecoveryState =>
      _conversationRecoveryState;
  ChatHistoricalConversationRestoreState?
  get historicalConversationRestoreState => _historicalConversationRestoreState;
  bool get isLoading => _isLoading;
  List<CodexUiBlock> get transcriptBlocks => _sessionState.transcriptBlocks;

  Future<void> initialize() {
    return _initializationFuture ??= _initializeOnce();
  }

  Future<void> _initializeOnce() async {
    if (!_isLoading) {
      await _restoreInitialConversationIfNeeded();
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
    await _restoreInitialConversationIfNeeded();
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
        _conversationRecoveryState != null ||
        _historicalConversationRestoreState != null) {
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

    final recoveryState = _conversationRecoveryPolicy.preflightRecoveryState(
      sessionState: _sessionState,
      activeThreadId: _activeConversationThreadId(),
      resumeThreadId: _resumeConversationThreadId(),
      trackedThreadId: _trackedThreadReuseCandidate(),
    );
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
    _clearHistoricalConversationRestoreState();
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
    _clearHistoricalConversationRestoreState();
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
    _clearHistoricalConversationRestoreState();
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

  Future<void> selectConversationForResume(String threadId) async {
    await _conversationSelection.selectConversationForResume(
      threadId,
      ephemeralSession: _profile.ephemeralSession,
      activeThreadId: _activeConversationThreadId(),
    );
    await _restoreConversationTranscript(threadId.trim());
  }

  Future<void> retryHistoricalConversationRestore() async {
    final threadId = _historicalConversationRestoreState?.threadId.trim();
    if (threadId == null || threadId.isEmpty) {
      return;
    }

    await _restoreConversationTranscript(threadId);
  }

  Future<String?> continueFromUserMessage(String blockId) async {
    final normalizedBlockId = blockId.trim();
    if (normalizedBlockId.isEmpty) {
      return null;
    }
    if (_historicalConversationRestoreState != null) {
      _emitSnackBar('Wait for transcript restore before continuing from here.');
      return null;
    }
    if (_sessionState.activeTurn != null || _sessionState.isBusy) {
      _emitSnackBar('Stop the active turn before continuing from here.');
      return null;
    }

    final targetThreadId = _activeConversationThreadId();
    if (targetThreadId == null) {
      _emitSnackBar('This conversation cannot continue from that prompt yet.');
      return null;
    }

    final timeline = _sessionState.timelineForThread(targetThreadId);
    final transcriptBlocks =
        timeline?.transcriptBlocks ?? _sessionState.transcriptBlocks;
    final userMessages = transcriptBlocks
        .whereType<CodexUserMessageBlock>()
        .toList(growable: false);
    final targetIndex = userMessages.indexWhere(
      (block) => block.id == normalizedBlockId,
    );
    if (targetIndex < 0) {
      _emitSnackBar('That prompt is no longer available for continuation.');
      return null;
    }

    final targetBlock = userMessages[targetIndex];
    final numTurns = userMessages.length - targetIndex;
    if (numTurns < 1) {
      return null;
    }

    try {
      await _ensureAppServerConnected();
      final thread = await appServerClient.rollbackThread(
        threadId: targetThreadId,
        numTurns: numTurns,
      );
      if (_isDisposed) {
        return null;
      }

      final nextState = _restoredSessionStateFromHistory(thread);
      _clearConversationRecovery();
      _clearHistoricalConversationRestoreState();
      _rememberContinuationThread(thread.id);
      _applySessionState(nextState);
      return targetBlock.text;
    } catch (error) {
      _reportAppServerFailure(
        title: 'Continue from prompt failed',
        message: 'Could not rewind this conversation to the selected prompt.',
        error: error,
      );
      return null;
    }
  }

  Future<bool> branchSelectedConversation() async {
    if (_historicalConversationRestoreState != null) {
      _emitSnackBar('Wait for transcript restore before branching.');
      return false;
    }
    if (_sessionState.activeTurn != null || _sessionState.isBusy) {
      _emitSnackBar('Stop the active turn before branching this conversation.');
      return false;
    }

    final targetThreadId = _selectedConversationThreadId();
    if (targetThreadId == null) {
      _emitSnackBar('This conversation cannot be branched yet.');
      return false;
    }

    try {
      await _ensureAppServerConnected();
      final forkedSession = await appServerClient.forkThread(
        threadId: targetThreadId,
        persistExtendedHistory: true,
      );
      final forkedThread = await appServerClient.readThreadWithTurns(
        threadId: forkedSession.threadId,
      );
      if (_isDisposed) {
        return false;
      }

      final nextState = _restoredSessionStateFromHistory(forkedThread);
      _clearConversationRecovery();
      _clearHistoricalConversationRestoreState();
      _applySessionState(nextState);
      _rememberContinuationThread(forkedThread.id);
      return true;
    } catch (error) {
      _reportAppServerFailure(
        title: 'Branch conversation failed',
        message: 'Could not branch this conversation from Codex.',
        error: error,
      );
      return false;
    }
  }

  Future<void> prepareSelectedConversationForContinuation() async {
    if (_historicalConversationRestoreState != null) {
      return;
    }

    final targetThreadId =
        _activeConversationThreadId() ?? _resumeConversationThreadId();
    if (targetThreadId == null) {
      return;
    }

    final trackedThreadId = _normalizedThreadId(appServerClient.threadId);
    if (appServerClient.isConnected && trackedThreadId == targetThreadId) {
      return;
    }

    try {
      await _ensureAppServerThread();
      _clearConversationRecovery();
    } catch (error) {
      final recoveryAssessment = _conversationRecoveryPolicy.assessSendFailure(
        error: error,
        sessionState: _sessionState,
        sessionLabel: _sessionLabel(),
        preferredAlternateThreadId: appServerClient.threadId,
      );
      if (recoveryAssessment.recoveryState != null) {
        _setConversationRecovery(recoveryAssessment.recoveryState!);
      }
    }
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
    _conversationSelection.schedulePersistConversationSelection(
      isDisposed: _isDisposed,
      ephemeralSession: _profile.ephemeralSession,
      activeThreadId: _activeConversationThreadId(),
    );
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

  void _setHistoricalConversationRestoreState(
    ChatHistoricalConversationRestoreState nextState,
  ) {
    final currentState = _historicalConversationRestoreState;
    if (currentState?.phase == nextState.phase &&
        currentState?.threadId == nextState.threadId) {
      return;
    }

    _historicalConversationRestoreState = nextState;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _clearHistoricalConversationRestoreState() {
    if (_historicalConversationRestoreState == null) {
      return;
    }

    _historicalConversationRestoreState = null;
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

  Future<void> _restoreInitialConversationIfNeeded() async {
    await _conversationSelection.persistInitialSelectionIfNeeded(
      ephemeralSession: _profile.ephemeralSession,
    );
    final threadId = _resumeConversationThreadId();
    if (threadId == null ||
        _historicalConversationRestoreState != null ||
        _sessionState.rootThreadId != null ||
        _sessionState.transcriptBlocks.isNotEmpty) {
      return;
    }

    await _restoreConversationTranscript(threadId);
  }

  Future<void> _restoreConversationTranscript(String threadId) async {
    _setHistoricalConversationRestoreState(
      ChatHistoricalConversationRestoreState(
        threadId: threadId,
        phase: ChatHistoricalConversationRestorePhase.loading,
      ),
    );
    try {
      await _ensureAppServerConnected();
      final thread = await appServerClient.readThreadWithTurns(
        threadId: threadId,
      );
      if (_isDisposed) {
        return;
      }

      final nextState = _restoredSessionStateFromHistory(thread);

      _clearConversationRecovery();
      _historicalConversationRestoreState = nextState.transcriptBlocks.isEmpty
          ? ChatHistoricalConversationRestoreState(
              threadId: threadId,
              phase: ChatHistoricalConversationRestorePhase.unavailable,
            )
          : null;
      _applySessionState(nextState);
    } catch (error) {
      _setHistoricalConversationRestoreState(
        ChatHistoricalConversationRestoreState(
          threadId: threadId,
          phase: ChatHistoricalConversationRestorePhase.failed,
        ),
      );
      _reportAppServerFailure(
        title: 'Conversation load failed',
        message: 'Could not load the saved conversation transcript.',
        error: error,
      );
    }
  }

  CodexSessionState _restoredSessionStateFromHistory(
    CodexAppServerThreadHistory thread,
  ) {
    final historicalConversation = _historicalConversationNormalizer.normalize(
      thread,
    );
    return _historicalConversationRestorer.restore(historicalConversation);
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
      await _conversationSelection.recordConversationSelection(
        threadId: turn.threadId,
      );
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
      final recoveryAssessment = _conversationRecoveryPolicy.assessSendFailure(
        error: error,
        sessionState: _sessionState,
        sessionLabel: _sessionLabel(),
        preferredAlternateThreadId: appServerClient.threadId,
      );
      if (recoveryAssessment.recoveryState != null) {
        _setConversationRecovery(recoveryAssessment.recoveryState!);
      }
      if (_sessionState.activeTurn == null &&
          _sessionState.pendingLocalUserMessageBlockIds.isNotEmpty) {
        _applySessionState(
          _sessionReducer.clearLocalUserMessageCorrelationState(_sessionState),
        );
      }
      await Future<void>.microtask(() {});
      _reportAppServerFailure(
        title: recoveryAssessment.presentation.title,
        message: recoveryAssessment.presentation.message,
        error: error,
        runtimeErrorMessage:
            recoveryAssessment.presentation.runtimeErrorMessage,
        suppressRuntimeError: _sawTrackedSshBootstrapFailure,
        suppressSnackBar: recoveryAssessment.suppressSnackBar,
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
    final trackedThreadId = _normalizedThreadId(appServerClient.threadId);
    if (activeThreadId != null && trackedThreadId == activeThreadId) {
      _rememberContinuationThread(activeThreadId);
      return activeThreadId;
    }

    final resumeThreadId =
        activeThreadId ??
        _conversationSelection.resumeThreadId(
          ephemeralSession: _profile.ephemeralSession,
        );
    final session = await appServerClient.startSession(
      model: _selectedModelOverride(),
      reasoningEffort: _profile.reasoningEffort,
      resumeThreadId: resumeThreadId,
    );
    _rememberContinuationThread(session.threadId);
    _rememberSessionHeaderMetadata(session);
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

  void _rememberSessionHeaderMetadata(CodexAppServerSession session) {
    final nextMetadata = _sessionState.headerMetadata.copyWith(
      cwd: session.cwd.trim().isEmpty ? null : session.cwd.trim(),
      model: session.model.trim().isEmpty ? null : session.model.trim(),
      modelProvider: session.modelProvider.trim().isEmpty
          ? null
          : session.modelProvider.trim(),
      reasoningEffort:
          session.reasoningEffort == null ||
              session.reasoningEffort!.trim().isEmpty
          ? null
          : session.reasoningEffort!.trim(),
    );
    _applySessionState(_sessionState.copyWith(headerMetadata: nextMetadata));
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

  bool _hasThreadMetadata(CodexAppServerThreadSummary thread) {
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

  String? _selectedConversationThreadId() {
    if (_profile.ephemeralSession) {
      return null;
    }

    return _normalizedThreadId(
      _sessionState.currentThreadId ?? _sessionState.rootThreadId,
    );
  }

  String? _resumeConversationThreadId() {
    return _conversationSelection.resumeThreadId(
      ephemeralSession: _profile.ephemeralSession,
    );
  }

  String? _trackedThreadReuseCandidate() {
    if (_profile.ephemeralSession ||
        _conversationSelection.suppressTrackedThreadReuse ||
        _sessionState.hasMultipleTimelines) {
      return null;
    }

    return _normalizedThreadId(appServerClient.threadId);
  }

  void _rememberContinuationThread(String? threadId) {
    _conversationSelection.rememberContinuationThread(
      threadId,
      isDisposed: _isDisposed,
      ephemeralSession: _profile.ephemeralSession,
      activeThreadId: _activeConversationThreadId(),
    );
  }

  void _clearContinuationThread() {
    _conversationSelection.clearContinuationThread(
      isDisposed: _isDisposed,
      ephemeralSession: _profile.ephemeralSession,
    );
  }

  String? _normalizedThreadId(String? value) {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }
    return normalizedValue;
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
}
