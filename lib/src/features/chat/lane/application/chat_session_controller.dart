import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_state_store.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/core/utils/platform_capabilities.dart';
import 'package:pocket_relay/src/core/utils/shell_utils.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_conversation_selection_coordinator.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_conversation_recovery_policy.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/chat_historical_conversation_restorer.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/codex_historical_conversation_normalizer.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/runtime_event_mapper.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_reducer.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';

part 'chat_session_controller_events.dart';
part 'chat_session_controller_history.dart';
part 'chat_session_controller_init.dart';
part 'chat_session_controller_prompt_flow.dart';
part 'chat_session_controller_recovery.dart';
part 'chat_session_controller_thread_metadata.dart';

class ChatSessionController extends ChangeNotifier {
  ChatSessionController({
    required this.profileStore,
    CodexConversationStateStore conversationStateStore =
        const DiscardingCodexConversationStateStore(),
    required this.appServerClient,
    SavedProfile? initialSavedProfile,
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

  Future<void> _initializeOnce() {
    return _ChatSessionControllerInit(this)._initializeOnce();
  }

  Future<void> saveObservedHostFingerprint(String blockId) {
    return _ChatSessionControllerPromptFlow(
      this,
    ).saveObservedHostFingerprint(blockId);
  }

  Future<bool> sendPrompt(String prompt) {
    return _ChatSessionControllerPromptFlow(this).sendPrompt(prompt);
  }

  Future<void> stopActiveTurn() {
    return _ChatSessionControllerPromptFlow(this).stopActiveTurn();
  }

  void startFreshConversation() {
    _ChatSessionControllerRecovery(this).startFreshConversation();
  }

  void clearTranscript() {
    _ChatSessionControllerRecovery(this).clearTranscript();
  }

  void openConversationRecoveryAlternateSession() {
    _ChatSessionControllerRecovery(
      this,
    ).openConversationRecoveryAlternateSession();
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

  Future<void> selectConversationForResume(String threadId) {
    return _ChatSessionControllerRecovery(
      this,
    ).selectConversationForResume(threadId);
  }

  Future<void> retryHistoricalConversationRestore() {
    return _ChatSessionControllerRecovery(
      this,
    ).retryHistoricalConversationRestore();
  }

  Future<String?> continueFromUserMessage(String blockId) {
    return _ChatSessionControllerRecovery(
      this,
    ).continueFromUserMessage(blockId);
  }

  Future<bool> branchSelectedConversation() {
    return _ChatSessionControllerRecovery(this).branchSelectedConversation();
  }

  Future<void> prepareSelectedConversationForContinuation() {
    return _ChatSessionControllerRecovery(
      this,
    ).prepareSelectedConversationForContinuation();
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
  ) {
    return _ChatSessionControllerPromptFlow(
      this,
    ).submitUserInput(requestId, answers);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _appServerEventSubscription?.cancel();
    unawaited(appServerClient.disconnect());
    unawaited(_snackBarMessagesController.close());
    super.dispose();
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

  CodexSshUnpinnedHostKeyBlock? _findUnpinnedHostKeyBlock(String blockId) {
    for (final block in _sessionState.blocks) {
      if (block is CodexSshUnpinnedHostKeyBlock && block.id == blockId) {
        return block;
      }
    }
    return null;
  }

  void _handleAppServerEvent(CodexAppServerEvent event) {
    _handleChatSessionAppServerEvent(this, event);
  }

  bool _isUnsupportedHostRequest(String method) {
    return method == 'account/chatgptAuthTokens/refresh' ||
        method == 'item/tool/call';
  }

  Future<void> _restoreInitialConversationIfNeeded() async {
    await _restoreInitialConversationIfNeededForController(this);
  }

  Future<void> _restoreConversationTranscript(String threadId) async {
    await _restoreConversationTranscriptForController(this, threadId);
  }

  Future<CodexSessionState?> _performHistoryRestoringThreadTransition({
    required Future<CodexAppServerThreadHistory> Function() operation,
    required String failureTitle,
    required String failureMessage,
    ChatHistoricalConversationRestoreState? loadingRestoreState,
    ChatHistoricalConversationRestoreState? emptyHistoryRestoreState,
    ChatHistoricalConversationRestoreState? failureRestoreState,
    bool rememberContinuationThread = false,
  }) async {
    return _performHistoryRestoringThreadTransitionForController(
      this,
      operation: operation,
      failureTitle: failureTitle,
      failureMessage: failureMessage,
      loadingRestoreState: loadingRestoreState,
      emptyHistoryRestoreState: emptyHistoryRestoreState,
      failureRestoreState: failureRestoreState,
      rememberContinuationThread: rememberContinuationThread,
    );
  }

  Future<bool> _sendPromptWithAppServer(String prompt) async {
    return _sendPromptWithAppServerForController(this, prompt);
  }

  Future<String> _ensureAppServerThread() async {
    return _ensureChatSessionAppServerThread(this);
  }

  String? _selectedModelOverride() {
    final model = _profile.model.trim();
    return model.isEmpty ? null : model;
  }

  Future<void> _stopAppServerTurn() async {
    await _stopChatSessionAppServerTurn(this);
  }

  Future<void> _resolveApproval(
    String requestId, {
    required bool approved,
  }) async {
    await _resolveChatSessionApproval(this, requestId, approved: approved);
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

  void _setConversationRecovery(ChatConversationRecoveryState nextState) {
    _ChatSessionControllerRecovery(this)._setConversationRecovery(nextState);
  }

  void _clearConversationRecovery() {
    _ChatSessionControllerRecovery(this)._clearConversationRecovery();
  }

  void _setHistoricalConversationRestoreState(
    ChatHistoricalConversationRestoreState nextState,
  ) {
    _ChatSessionControllerRecovery(
      this,
    )._setHistoricalConversationRestoreState(nextState);
  }

  String? _activeConversationThreadId() {
    return _ChatSessionControllerRecovery(this)._activeConversationThreadId();
  }

  String? _resumeConversationThreadId() {
    return _ChatSessionControllerRecovery(this)._resumeConversationThreadId();
  }

  String? _trackedThreadReuseCandidate() {
    return _ChatSessionControllerRecovery(this)._trackedThreadReuseCandidate();
  }

  void _rememberContinuationThread(String? threadId) {
    _ChatSessionControllerRecovery(this)._rememberContinuationThread(threadId);
  }

  String? _normalizedThreadId(String? value) {
    return _ChatSessionControllerRecovery(this)._normalizedThreadId(value);
  }

  void _notifyListenersIfMounted() {
    if (!_isDisposed) {
      notifyListeners();
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
}
