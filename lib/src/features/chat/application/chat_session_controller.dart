import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/core/utils/shell_utils.dart';
import 'package:pocket_relay/src/features/chat/application/runtime_event_mapper.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_reducer.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';

class ChatSessionController extends ChangeNotifier {
  ChatSessionController({
    required this.profileStore,
    required this.appServerClient,
    SavedProfile? initialSavedProfile,
    TranscriptReducer reducer = const TranscriptReducer(),
    CodexRuntimeEventMapper? runtimeEventMapper,
  }) : _sessionReducer = reducer,
       _runtimeEventMapper = runtimeEventMapper ?? CodexRuntimeEventMapper() {
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
  final _snackBarMessagesController = StreamController<String>.broadcast();

  ConnectionProfile _profile = ConnectionProfile.defaults();
  ConnectionSecrets _secrets = const ConnectionSecrets();
  CodexSessionState _sessionState = CodexSessionState.initial();

  bool _isLoading = true;
  bool _didInitialize = false;
  bool _isDisposed = false;
  bool _isTrackingSshBootstrapFailures = false;
  bool _sawTrackedSshBootstrapFailure = false;
  StreamSubscription<CodexAppServerEvent>? _appServerEventSubscription;

  Stream<String> get snackBarMessages => _snackBarMessagesController.stream;

  ConnectionProfile get profile => _profile;
  ConnectionSecrets get secrets => _secrets;
  CodexSessionState get sessionState => _sessionState;
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

  Future<void> applyConnectionSettings({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    if (profile == _profile && secrets == _secrets) {
      return;
    }

    await profileStore.save(profile, secrets);
    await appServerClient.disconnect();
    if (_isDisposed) {
      return;
    }

    _profile = profile;
    _secrets = secrets;
    _applySessionState(_sessionReducer.detachThread(_sessionState));
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
    if (normalizedPrompt.isEmpty || _sessionState.isBusy) {
      return false;
    }

    final validationMessage = _validateProfileForSend();
    if (validationMessage != null) {
      _emitSnackBar(validationMessage);
      return false;
    }

    final rootThreadId = _sessionState.effectiveRootThreadId;
    if (rootThreadId != null &&
        _sessionState.effectiveSelectedThreadId != rootThreadId) {
      selectTimeline(rootThreadId);
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
    _applySessionState(
      _sessionReducer.startFreshThread(
        _sessionState,
        message: 'The next prompt will start a fresh remote Codex thread.',
      ),
    );
  }

  void clearTranscript() {
    _applySessionState(_sessionReducer.clearTranscript(_sessionState));
  }

  void selectTimeline(String threadId) {
    final normalizedThreadId = threadId.trim();
    if (normalizedThreadId.isEmpty ||
        _sessionState.effectiveSelectedThreadId == normalizedThreadId) {
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
      return 'Fill in the remote connection details first.';
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
  }

  Future<bool> _sendPromptWithAppServer(String prompt) async {
    _isTrackingSshBootstrapFailures = true;
    _sawTrackedSshBootstrapFailure = false;
    try {
      final threadId = await _ensureAppServerThread();
      _applySessionState(
        _sessionState.copyWith(
          connectionStatus: CodexRuntimeSessionState.running,
        ),
      );
      final turn = await appServerClient.sendUserMessage(
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
      );
      return true;
    } catch (error) {
      if (_sessionState.activeTurn == null &&
          _sessionState.pendingLocalUserMessageBlockIds.isNotEmpty) {
        _applySessionState(
          _sessionReducer.clearLocalUserMessageCorrelationState(_sessionState),
        );
      }
      await Future<void>.microtask(() {});
      _reportAppServerFailure(
        title: 'Send failed',
        message: 'Could not send the prompt to the remote Codex session.',
        error: error,
        suppressRuntimeError: _sawTrackedSshBootstrapFailure,
      );
      return false;
    } finally {
      _isTrackingSshBootstrapFailures = false;
      _sawTrackedSshBootstrapFailure = false;
    }
  }

  Future<String> _ensureAppServerThread() async {
    await _ensureAppServerConnected();

    final resumeThreadId = _profile.ephemeralSession
        ? null
        : _sessionState.effectiveRootThreadId;
    if (resumeThreadId != null && resumeThreadId.isNotEmpty) {
      return resumeThreadId;
    }

    final session = await appServerClient.startSession(
      resumeThreadId: resumeThreadId,
    );
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

  Future<void> _stopAppServerTurn() async {
    try {
      final targetTimeline =
          _sessionState.selectedTimeline ?? _sessionState.rootTimeline;
      await appServerClient.abortTurn(
        threadId: targetTimeline?.threadId,
        turnId: targetTimeline?.activeTurn?.turnId,
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

    for (final timeline in _sessionState.effectiveTimelinesByThreadId.values) {
      if (timeline.pendingApprovalRequests.containsKey(requestId) ||
          timeline.pendingUserInputRequests.containsKey(requestId)) {
        return timeline;
      }
    }

    return null;
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
    bool suppressRuntimeError = false,
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
          message: '$title: $error',
          errorClass: CodexRuntimeErrorClass.transportError,
          rawMethod: 'app-server/failure',
        ),
      );
    }
    _emitSnackBar(message);
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
