import 'package:pocket_relay/src/core/models/connection_models.dart';

import 'codex_app_server_connection.dart';
import 'codex_app_server_models.dart';
import 'codex_app_server_thread_read_decoder.dart';

class CodexAppServerRequestApi {
  const CodexAppServerRequestApi({
    CodexAppServerThreadReadDecoder threadReadDecoder =
        const CodexAppServerThreadReadDecoder(),
  }) : _threadReadDecoder = threadReadDecoder;

  final CodexAppServerThreadReadDecoder _threadReadDecoder;

  Future<CodexAppServerSession> startSession(
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
    var method = effectiveResumeThreadId != null
        ? 'thread/resume'
        : 'thread/start';
    final resumeThreadParam = effectiveResumeThreadId == null
        ? null
        : <String, Object?>{'threadId': effectiveResumeThreadId};
    var params = <String, Object?>{
      ...baseParams,
      if (method == 'thread/start') 'ephemeral': profile.ephemeralSession,
      ...?resumeThreadParam,
    };

    final response = await connection.sendRequest(method, params);

    final payload = _requireObject(response, '$method response');
    final thread = _requireThread(payload['thread'], '$method response');
    final threadId = thread.id;

    if (effectiveResumeThreadId != null &&
        threadId != effectiveResumeThreadId) {
      throw CodexAppServerException(
        'thread/resume returned a different thread id than requested.',
        data: <String, Object?>{
          'expectedThreadId': effectiveResumeThreadId,
          'actualThreadId': threadId,
        },
      );
    }

    connection.setTrackedThread(threadId);

    return CodexAppServerSession(
      threadId: threadId,
      cwd: _asString(payload['cwd']) ?? effectiveCwd,
      model: _asString(payload['model']) ?? '',
      modelProvider: _asString(payload['modelProvider']) ?? '',
      reasoningEffort:
          _asString(payload['reasoningEffort']) ??
          _asString(payload['reasoning_effort']) ??
          _asString(payload['effort']),
      thread: thread,
      approvalPolicy: payload['approvalPolicy'],
      sandbox: payload['sandbox'],
    );
  }

  Future<CodexAppServerThread> readThread(
    CodexAppServerConnection connection, {
    required String threadId,
    bool includeTurns = false,
  }) async {
    connection.requireConnected();

    final effectiveThreadId = threadId.trim();
    if (effectiveThreadId.isEmpty) {
      throw const CodexAppServerException('Thread id cannot be empty.');
    }

    final response = await connection.sendRequest(
      'thread/read',
      <String, Object?>{
        'threadId': effectiveThreadId,
        'includeTurns': includeTurns,
      },
    );
    return _threadReadDecoder.decodeResponse(
      response,
      fallbackThreadId: effectiveThreadId,
    );
  }

  Future<CodexAppServerThreadListPage> listThreads(
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
          .map(_asThread)
          .whereType<CodexAppServerThread>()
          .toList(growable: false),
      nextCursor: _asString(payload['nextCursor']),
    );
  }

  Future<CodexAppServerTurn> sendUserMessage(
    CodexAppServerConnection connection, {
    required String threadId,
    required String text,
    String? model,
    CodexReasoningEffort? effort,
  }) async {
    connection.requireConnected();

    final effectiveThreadId = threadId.trim();
    final trimmedText = text.trim();
    if (effectiveThreadId.isEmpty) {
      throw const CodexAppServerException('Thread id cannot be empty.');
    }
    if (trimmedText.isEmpty) {
      throw const CodexAppServerException('Turn input cannot be empty.');
    }

    final params = <String, Object?>{
      'threadId': effectiveThreadId,
      'input': <Object>[
        <String, Object?>{
          'type': 'text',
          'text': trimmedText,
          'text_elements': const <Object>[],
        },
      ],
      if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
      if (effort != null) 'effort': effort.name,
    };

    final response = await connection.sendRequest('turn/start', params);
    final payload = _requireObject(response, 'turn/start response');
    final turn = _requireObject(payload['turn'], 'turn/start turn');
    final turnId = _asString(turn['id']) ?? '';

    if (turnId.isEmpty) {
      throw const CodexAppServerException(
        'turn/start response did not include a turn id.',
      );
    }

    connection.setTrackedTurn(threadId: effectiveThreadId, turnId: turnId);
    return CodexAppServerTurn(threadId: effectiveThreadId, turnId: turnId);
  }

  Future<void> answerUserInput(
    CodexAppServerConnection connection, {
    required String requestId,
    required Map<String, List<String>> answers,
  }) async {
    final pending = connection.requirePendingServerRequest(requestId);
    if (pending.method != 'item/tool/requestUserInput' &&
        pending.method != 'tool/requestUserInput') {
      throw CodexAppServerException(
        'Request $requestId is ${pending.method}, not tool/requestUserInput.',
      );
    }

    await connection.sendServerResult(
      requestId: requestId,
      result: <String, Object?>{
        'answers': answers.map(
          (key, value) => MapEntry<String, Object?>(key, <String, Object?>{
            'answers': value,
          }),
        ),
      },
    );
  }

  Future<void> respondDynamicToolCall(
    CodexAppServerConnection connection, {
    required String requestId,
    required bool success,
    List<Map<String, Object?>> contentItems = const <Map<String, Object?>>[],
  }) async {
    final pending = connection.requirePendingServerRequest(requestId);
    if (pending.method != 'item/tool/call') {
      throw CodexAppServerException(
        'Request $requestId is ${pending.method}, not item/tool/call.',
      );
    }

    await connection.sendServerResult(
      requestId: requestId,
      result: <String, Object?>{
        'contentItems': contentItems,
        'success': success,
      },
    );
  }

  Future<void> resolveApproval(
    CodexAppServerConnection connection, {
    required String requestId,
    required bool approved,
  }) async {
    final pending = connection.requirePendingServerRequest(requestId);
    if (pending.method == 'item/permissions/requestApproval') {
      await resolvePermissionsRequest(
        connection,
        requestId: requestId,
        approved: approved,
      );
      return;
    }

    final decision = switch (pending.method) {
      'item/commandExecution/requestApproval' =>
        approved ? 'accept' : 'decline',
      'item/fileChange/requestApproval' => approved ? 'accept' : 'decline',
      'applyPatchApproval' => approved ? 'approved' : 'denied',
      'execCommandApproval' => approved ? 'approved' : 'denied',
      _ => throw CodexAppServerException(
        'Boolean approval is not supported for ${pending.method}.',
      ),
    };

    await connection.sendServerResult(
      requestId: requestId,
      result: <String, Object?>{'decision': decision},
    );
  }

  Future<void> resolvePermissionsRequest(
    CodexAppServerConnection connection, {
    required String requestId,
    required bool approved,
    String scope = 'turn',
  }) async {
    if (scope != 'turn' && scope != 'session') {
      throw CodexAppServerException('Unsupported permission scope: $scope');
    }

    final pending = connection.requirePendingServerRequest(requestId);
    if (pending.method != 'item/permissions/requestApproval') {
      throw CodexAppServerException(
        'Request $requestId is ${pending.method}, not item/permissions/requestApproval.',
      );
    }

    final payload = _asObject(pending.params);
    final requestedPermissions = _asObject(payload?['permissions']);
    await connection.sendServerResult(
      requestId: requestId,
      result: <String, Object?>{
        'permissions': approved
            ? _grantedPermissionsFromRequest(requestedPermissions)
            : const <String, Object?>{},
        'scope': scope,
      },
    );
  }

  Future<void> respondToElicitation(
    CodexAppServerConnection connection, {
    required String requestId,
    required CodexAppServerElicitationAction action,
    Object? content,
    Object? metadata,
  }) async {
    final pending = connection.requirePendingServerRequest(requestId);
    if (pending.method != 'mcpServer/elicitation/request') {
      throw CodexAppServerException(
        'Request $requestId is ${pending.method}, not mcpServer/elicitation/request.',
      );
    }

    if (action != CodexAppServerElicitationAction.accept && content != null) {
      throw const CodexAppServerException(
        'Only accepted elicitation responses may include content.',
      );
    }

    final result = <String, Object?>{'action': action.name};
    if (content != null) {
      result['content'] = content;
    }
    if (metadata != null) {
      result['_meta'] = metadata;
    }

    await connection.sendServerResult(requestId: requestId, result: result);
  }

  Future<void> abortTurn(
    CodexAppServerConnection connection, {
    String? threadId,
    String? turnId,
  }) async {
    if (threadId == null || turnId == null) {
      return;
    }

    await connection.sendRequest('turn/interrupt', <String, Object?>{
      'threadId': threadId,
      'turnId': turnId,
    });
  }

  static Map<String, dynamic>? _asObject(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static Map<String, dynamic> _requireObject(Object? value, String label) {
    final object = _asObject(value);
    if (object == null) {
      throw CodexAppServerException('$label was not an object.');
    }
    return object;
  }

  static String? _asString(Object? value) {
    return value is String ? value : null;
  }

  static List<Map<String, dynamic>>? _asObjectList(Object? value) {
    if (value is! List) {
      return null;
    }

    final objects = value
        .map(_asObject)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    return objects.isEmpty ? null : objects;
  }

  static CodexAppServerThread _requireThread(Object? value, String label) {
    final thread = _asThread(value);
    if (thread == null) {
      throw CodexAppServerException('$label did not include a thread object.');
    }
    return thread;
  }

  static CodexAppServerThread? _asThread(
    Object? value, {
    Object? fallbackThreadId,
  }) {
    final thread = _asObject(value);
    final threadId =
        _asString(thread?['id']) ?? _asString(fallbackThreadId) ?? '';
    if (threadId.isEmpty) {
      return null;
    }

    return CodexAppServerThread(
      id: threadId,
      preview: _asString(thread?['preview']) ?? '',
      ephemeral: thread?['ephemeral'] as bool? ?? false,
      modelProvider: _asString(thread?['modelProvider']) ?? '',
      createdAt: _parseUnixTimestamp(thread?['createdAt']),
      updatedAt: _parseUnixTimestamp(thread?['updatedAt']),
      path: _asString(thread?['path']),
      cwd: _asString(thread?['cwd']),
      promptCount:
          _asInt(thread?['promptCount']) ??
          _countUserPromptItems(thread?['turns']),
      name: _asString(thread?['name']),
      sourceKind: _sourceKind(thread?['source']),
      agentNickname: _asString(thread?['agentNickname']),
      agentRole: _asString(thread?['agentRole']),
      turns: _asObjectList(thread?['turns']) ?? const <Map<String, dynamic>>[],
    );
  }

  static String? _sourceKind(Object? raw) {
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }

    final object = _asObject(raw);
    return _asString(object?['kind']) ?? _asString(object?['type']);
  }

  static DateTime? _parseUnixTimestamp(Object? raw) {
    if (raw is! num) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(
      raw.toInt() * 1000,
      isUtc: true,
    ).toLocal();
  }

  static int? _countUserPromptItems(Object? rawTurns) {
    if (rawTurns is! List) {
      return null;
    }

    var count = 0;
    for (final turn in rawTurns.whereType<Map>()) {
      final items = turn['items'];
      if (items is! List) {
        continue;
      }
      for (final item in items.whereType<Map>()) {
        if (_asString(item['type']) == 'userMessage') {
          count += 1;
        }
      }
    }
    return count;
  }

  static int? _asInt(Object? value) {
    return value is num ? value.toInt() : null;
  }

  static String _approvalPolicyFor(ConnectionProfile profile) {
    return profile.dangerouslyBypassSandbox ? 'never' : 'on-request';
  }

  static String _sandboxFor(ConnectionProfile profile) {
    return profile.dangerouslyBypassSandbox
        ? 'danger-full-access'
        : 'workspace-write';
  }

  static Map<String, Object?> _grantedPermissionsFromRequest(
    Map<String, dynamic>? requested,
  ) {
    if (requested == null) {
      return const <String, Object?>{};
    }

    return <String, Object?>{
      if (requested['network'] != null) 'network': requested['network'],
      if (requested['fileSystem'] != null)
        'fileSystem': requested['fileSystem'],
      if (requested['macos'] != null) 'macos': requested['macos'],
    };
  }
}
