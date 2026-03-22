part of 'codex_app_server_request_api.dart';

Future<CodexAppServerSession> _startSession(
  CodexAppServerRequestApi api,
  CodexAppServerConnection connection, {
  String? cwd,
  String? model,
  CodexReasoningEffort? reasoningEffort,
  String? resumeThreadId,
}) async {
  final profile = connection.requireProfile();
  connection.requireConnected();

  final effectiveCwd = (cwd ?? profile.workspaceDir).trim().isEmpty
      ? profile.workspaceDir.trim()
      : (cwd ?? profile.workspaceDir).trim();
  final normalizedResumeThreadId = resumeThreadId?.trim();
  final effectiveResumeThreadId =
      profile.ephemeralSession ||
          normalizedResumeThreadId == null ||
          normalizedResumeThreadId.isEmpty
      ? null
      : normalizedResumeThreadId;
  final baseParams = <String, Object?>{
    'cwd': effectiveCwd,
    'approvalPolicy': _approvalPolicyFor(profile),
    'sandbox': _sandboxFor(profile),
    if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
    if (reasoningEffort != null) 'reasoning_effort': reasoningEffort.name,
  };
  final method = effectiveResumeThreadId != null
      ? 'thread/resume'
      : 'thread/start';
  final resumeThreadParam = effectiveResumeThreadId == null
      ? null
      : <String, Object?>{'threadId': effectiveResumeThreadId};
  final params = <String, Object?>{
    ...baseParams,
    if (method == 'thread/start') 'ephemeral': profile.ephemeralSession,
    ...?resumeThreadParam,
  };

  final response = await connection.sendRequest(method, params);

  final payload = _requireObject(response, '$method response');
  final thread = _requireThreadSummary(payload['thread'], '$method response');
  final threadId = thread.id;

  if (effectiveResumeThreadId != null && threadId != effectiveResumeThreadId) {
    throw CodexAppServerException(
      'thread/resume returned a different thread id than requested.',
      data: <String, Object?>{
        'expectedThreadId': effectiveResumeThreadId,
        'actualThreadId': threadId,
      },
    );
  }

  connection.setTrackedThread(threadId);
  return _sessionFromPayload(
    payload,
    thread: thread,
    threadId: threadId,
    fallbackCwd: effectiveCwd,
  );
}

Future<CodexAppServerThreadSummary> _readThread(
  CodexAppServerRequestApi api,
  CodexAppServerConnection connection, {
  required String threadId,
}) async {
  connection.requireConnected();
  final effectiveThreadId = _requireThreadId(threadId);
  return _sendThreadRead(
    api,
    connection,
    threadId: effectiveThreadId,
    includeTurns: false,
  );
}

Future<CodexAppServerThreadHistory> _readThreadWithTurns(
  CodexAppServerRequestApi api,
  CodexAppServerConnection connection, {
  required String threadId,
}) async {
  connection.requireConnected();
  final effectiveThreadId = _requireThreadId(threadId);
  return _sendThreadReadWithTurns(api, connection, threadId: effectiveThreadId);
}

Future<CodexAppServerThreadHistory> _rollbackThread(
  CodexAppServerRequestApi api,
  CodexAppServerConnection connection, {
  required String threadId,
  required int numTurns,
}) async {
  connection.requireConnected();
  final effectiveThreadId = _requireThreadId(threadId);
  if (numTurns < 1) {
    throw const CodexAppServerException('numTurns must be >= 1.');
  }

  final response = await connection.sendRequest(
    'thread/rollback',
    <String, Object?>{'threadId': effectiveThreadId, 'numTurns': numTurns},
  );
  return api._threadReadDecoder.decodeHistoryResponse(
    response,
    fallbackThreadId: effectiveThreadId,
  );
}

Future<CodexAppServerSession> _forkThread(
  CodexAppServerRequestApi api,
  CodexAppServerConnection connection, {
  required String threadId,
  String? path,
  String? cwd,
  String? model,
  String? modelProvider,
  bool? ephemeral,
  bool persistExtendedHistory = false,
}) async {
  final profile = connection.requireProfile();
  connection.requireConnected();
  final effectiveThreadId = _requireThreadId(threadId);

  final normalizedPath = path?.trim();
  final normalizedCwd = cwd?.trim();
  final params = <String, Object?>{
    'threadId': effectiveThreadId,
    if (normalizedPath != null && normalizedPath.isNotEmpty)
      'path': normalizedPath,
    if (normalizedCwd != null && normalizedCwd.isNotEmpty) 'cwd': normalizedCwd,
    if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
    if (modelProvider != null && modelProvider.trim().isNotEmpty)
      'modelProvider': modelProvider.trim(),
    'approvalPolicy': _approvalPolicyFor(profile),
    'sandbox': _sandboxFor(profile),
    'ephemeral': ephemeral ?? profile.ephemeralSession,
    'persistExtendedHistory': persistExtendedHistory,
  };

  final response = await connection.sendRequest('thread/fork', params);
  final payload = _requireObject(response, 'thread/fork response');
  final thread = api._threadReadDecoder.decodeSummaryResponse(
    payload,
    fallbackThreadId: effectiveThreadId,
  );
  final forkedThreadId = thread.id;
  connection.setTrackedThread(forkedThreadId);
  return _sessionFromPayload(
    payload,
    thread: thread,
    threadId: forkedThreadId,
    fallbackCwd: normalizedCwd ?? profile.workspaceDir,
    fallbackModel: model?.trim() ?? '',
    fallbackModelProvider: modelProvider?.trim() ?? thread.modelProvider,
  );
}

Future<CodexAppServerThreadListPage> _listThreads(
  CodexAppServerRequestApi api,
  CodexAppServerConnection connection, {
  String? cursor,
  int? limit,
}) async {
  connection.requireConnected();
  final normalizedCursor = cursor?.trim();
  final params = <String, Object?>{};
  if (normalizedCursor != null && normalizedCursor.isNotEmpty) {
    params['cursor'] = normalizedCursor;
  }
  if (limit != null) {
    params['limit'] = limit;
  }

  final response = await connection.sendRequest('thread/list', params);
  final payload = _requireObject(response, 'thread/list response');
  final data = payload['data'];
  if (data is! List) {
    throw const CodexAppServerException(
      'thread/list response did not include a thread list.',
    );
  }

  return CodexAppServerThreadListPage(
    threads: data
        .map(_asThreadSummary)
        .whereType<CodexAppServerThreadSummary>()
        .toList(growable: false),
    nextCursor: _asString(payload['nextCursor']),
  );
}

Future<CodexAppServerModelListPage> _listModels(
  CodexAppServerRequestApi api,
  CodexAppServerConnection connection, {
  String? cursor,
  int? limit,
}) async {
  connection.requireConnected();
  final normalizedCursor = cursor?.trim();
  final params = <String, Object?>{};
  if (normalizedCursor != null && normalizedCursor.isNotEmpty) {
    params['cursor'] = normalizedCursor;
  }
  if (limit != null) {
    params['limit'] = limit;
  }

  final response = await connection.sendRequest('model/list', params);
  final payload = _requireObject(response, 'model/list response');
  final data = payload['data'];
  if (data is! List) {
    throw const CodexAppServerException(
      'model/list response did not include a model list.',
    );
  }

  return CodexAppServerModelListPage(
    models: data
        .map(_asModelDescription)
        .whereType<CodexAppServerModelDescription>()
        .toList(growable: false),
    nextCursor: _asString(payload['nextCursor']),
  );
}

Future<CodexAppServerThreadSummary> _sendThreadRead(
  CodexAppServerRequestApi api,
  CodexAppServerConnection connection, {
  required String threadId,
  required bool includeTurns,
}) async {
  final response = await connection.sendRequest(
    'thread/read',
    <String, Object?>{'threadId': threadId, 'includeTurns': includeTurns},
  );
  return api._threadReadDecoder.decodeSummaryResponse(
    response,
    fallbackThreadId: threadId,
  );
}

Future<CodexAppServerThreadHistory> _sendThreadReadWithTurns(
  CodexAppServerRequestApi api,
  CodexAppServerConnection connection, {
  required String threadId,
}) async {
  final response = await connection.sendRequest(
    'thread/read',
    <String, Object?>{'threadId': threadId, 'includeTurns': true},
  );
  return api._threadReadDecoder.decodeHistoryResponse(
    response,
    fallbackThreadId: threadId,
  );
}
