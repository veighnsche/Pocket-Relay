import 'package:pocket_relay/src/agent_adapters/agent_adapter_capabilities.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_registry.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/core/utils/platform_capabilities.dart';
import 'package:pocket_relay/src/core/utils/shell_utils.dart';
import 'package:pocket_relay/src/features/chat/composer/domain/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_conversation_recovery_policy.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_errors.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_guardrail_errors.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/chat_historical_conversation_restorer.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/codex_historical_conversation_normalizer.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/agent_adapter_runtime_event_bridge.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/host_adapter_runtime_event_mapper.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/runtime_event_mapper.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_reducer.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/agent_adapter_runtime_event_mapper.dart';
import 'package:pocket_relay/src/features/chat/runtime/domain/agent_adapter_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_client.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_work_log_terminal_contract.dart';

part 'chat_session_controller_events.dart';
part 'chat_session_controller_history.dart';
part 'chat_session_controller_init.dart';
part 'chat_session_controller_model_capabilities.dart';
part 'chat_session_controller_prompt_flow.dart';
part 'chat_session_controller_recovery.dart';
part 'chat_session_controller_support.dart';
part 'chat_session_controller_thread_metadata.dart';
part 'chat_session_controller_work_log_terminal.dart';

class ChatSessionController extends ChangeNotifier {
  ChatSessionController({
    required this.profileStore,
    AgentAdapterClient? injectedAgentAdapterClient,
    @Deprecated('Use agentAdapterClient instead.')
    AgentAdapterClient? appServerClient,
    SavedProfile? initialSavedProfile,
    TranscriptReducer reducer = const TranscriptReducer(),
    AgentAdapterRuntimeEventMapper? runtimeEventMapper,
    CodexHistoricalConversationNormalizer historicalConversationNormalizer =
        const CodexHistoricalConversationNormalizer(),
    ChatHistoricalConversationRestorer? historicalConversationRestorer,
    bool? supportsLocalConnectionMode,
  }) : assert(
         injectedAgentAdapterClient != null || appServerClient != null,
         'An agent adapter client is required.',
       ),
       agentAdapterClient = injectedAgentAdapterClient ?? appServerClient!,
       _sessionReducer = reducer,
       _runtimeEventMapper =
           runtimeEventMapper ??
           createAgentAdapterRuntimeEventMapper(
             initialSavedProfile?.profile.agentAdapter ??
                 ConnectionProfile.defaults().agentAdapter,
           ),
       _historicalConversationNormalizer = historicalConversationNormalizer,
       _historicalConversationRestorer =
           historicalConversationRestorer ??
           ChatHistoricalConversationRestorer(reducer: reducer),
       _supportsLocalConnectionMode =
           supportsLocalConnectionMode ??
           supportsLocalAgentAdapterConnection() {
    final initial = initialSavedProfile;
    if (initial != null) {
      _profile = initial.profile;
      _secrets = initial.secrets;
      _isLoading = false;
    }
    _appServerEventSubscription = this.agentAdapterClient.events.listen(
      _handleAppServerEvent,
    );
  }

  final CodexProfileStore profileStore;
  final AgentAdapterClient agentAdapterClient;
  @Deprecated('Use agentAdapterClient instead.')
  AgentAdapterClient get appServerClient => agentAdapterClient;

  final TranscriptReducer _sessionReducer;
  final AgentAdapterRuntimeEventMapper _runtimeEventMapper;
  final CodexHistoricalConversationNormalizer _historicalConversationNormalizer;
  final ChatHistoricalConversationRestorer _historicalConversationRestorer;
  final ChatConversationRecoveryPolicy _conversationRecoveryPolicy =
      const ChatConversationRecoveryPolicy();
  final bool _supportsLocalConnectionMode;
  final _snackBarMessagesController = StreamController<String>.broadcast();

  ConnectionProfile _profile = ConnectionProfile.defaults();
  ConnectionSecrets _secrets = const ConnectionSecrets();
  TranscriptSessionState _sessionState = TranscriptSessionState.initial();
  ChatConversationRecoveryState? _conversationRecoveryState;
  ChatHistoricalConversationRestoreState? _historicalConversationRestoreState;
  List<AgentAdapterModel>? _modelCatalog;

  bool _isLoading = true;
  bool _isDisposed = false;
  bool _isTrackingSshBootstrapFailures = false;
  bool _sawTrackedSshBootstrapFailure = false;
  bool _sawTrackedUnpinnedHostKeyFailure = false;
  bool _suppressTrackedThreadReuse = false;
  bool _isBufferingRuntimeEvents = false;
  bool _didAttemptModelCatalogHydration = false;
  int _historicalConversationRestoreGeneration = 0;
  final Set<String> _threadMetadataHydrationAttempts = <String>{};
  final List<TranscriptRuntimeEvent> _bufferedRuntimeEvents =
      <TranscriptRuntimeEvent>[];
  StreamSubscription<AgentAdapterEvent>? _appServerEventSubscription;
  Future<void>? _initializationFuture;
  Future<void>? _modelCatalogHydrationFuture;

  Stream<String> get snackBarMessages => _snackBarMessagesController.stream;

  ConnectionProfile get profile => _profile;
  ConnectionSecrets get secrets => _secrets;
  AgentAdapterCapabilities get agentAdapterCapabilities =>
      agentAdapterCapabilitiesFor(_profile.agentAdapter);
  TranscriptSessionState get sessionState => _sessionState;
  ChatConversationRecoveryState? get conversationRecoveryState =>
      _conversationRecoveryState;
  ChatHistoricalConversationRestoreState?
  get historicalConversationRestoreState => _historicalConversationRestoreState;
  bool get isLoading => _isLoading;
  bool get currentModelSupportsImageInput => _currentModelSupportsImageInput();
  List<TranscriptUiBlock> get transcriptBlocks =>
      _sessionState.transcriptBlocks;

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

  Future<bool> sendDraft(ChatComposerDraft draft) {
    return _ChatSessionControllerPromptFlow(this).sendDraft(draft);
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

    final nextTimelines = <String, TranscriptTimelineState>{
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

  Future<void> reattachConversation(String threadId) {
    return _ChatSessionControllerRecovery(this).reattachConversation(threadId);
  }

  Future<void> retryHistoricalConversationRestore() {
    return _ChatSessionControllerRecovery(
      this,
    ).retryHistoricalConversationRestore();
  }

  Future<ChatComposerDraft?> continueFromUserMessage(String blockId) {
    return _ChatSessionControllerRecovery(
      this,
    ).continueFromUserMessage(blockId);
  }

  Future<ChatWorkLogTerminalContract> hydrateWorkLogTerminal(
    ChatWorkLogTerminalContract terminal,
  ) {
    return _hydrateChatWorkLogTerminal(this, terminal);
  }

  Future<bool> branchSelectedConversation() {
    return _ChatSessionControllerRecovery(this).branchSelectedConversation();
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
    unawaited(agentAdapterClient.disconnect());
    unawaited(_snackBarMessagesController.close());
    super.dispose();
  }

  void _applySessionState(TranscriptSessionState nextState) {
    if (_isDisposed) {
      return;
    }

    _sessionState = nextState;
    notifyListeners();
  }

  TranscriptSshUnpinnedHostKeyBlock? _findUnpinnedHostKeyBlock(String blockId) {
    for (final block in _sessionState.blocks) {
      if (block is TranscriptSshUnpinnedHostKeyBlock && block.id == blockId) {
        return block;
      }
    }
    return null;
  }

  void _handleAppServerEvent(AgentAdapterEvent event) {
    _handleChatSessionAppServerEvent(this, event);
  }

  bool _isUnsupportedHostRequest(String method) {
    return method == 'account/chatgptAuthTokens/refresh' ||
        method == 'item/tool/call';
  }

  Future<void> _restoreConversationTranscript(String threadId) async {
    await _restoreConversationTranscriptForController(this, threadId);
  }

  Future<TranscriptSessionState?> _performHistoryRestoringThreadTransition({
    required Future<AgentAdapterThreadHistory> Function() operation,
    required PocketUserFacingError userFacingError,
    ChatHistoricalConversationRestoreState? loadingRestoreState,
    ChatHistoricalConversationRestoreState? emptyHistoryRestoreState,
    ChatHistoricalConversationRestoreState? failureRestoreState,
  }) async {
    return _performHistoryRestoringThreadTransitionForController(
      this,
      operation: operation,
      userFacingError: userFacingError,
      loadingRestoreState: loadingRestoreState,
      emptyHistoryRestoreState: emptyHistoryRestoreState,
      failureRestoreState: failureRestoreState,
    );
  }

  Future<bool> _sendPromptWithAppServer(String prompt) async {
    return _sendPromptWithAppServerForController(this, prompt);
  }

  Future<bool> _sendDraftWithAppServer(ChatComposerDraft draft) async {
    return _sendDraftWithAppServerForController(this, draft);
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

  void _notifyListenersIfMounted() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  int _beginHistoricalConversationRestore({
    ChatHistoricalConversationRestoreState? loadingState,
  }) {
    final generation = ++_historicalConversationRestoreGeneration;
    if (loadingState != null) {
      _setHistoricalConversationRestoreState(loadingState);
    }
    return generation;
  }

  void _invalidateHistoricalConversationRestore() {
    _historicalConversationRestoreGeneration += 1;
  }

  bool _isCurrentHistoricalConversationRestore(int generation) {
    return _historicalConversationRestoreGeneration == generation;
  }
}
