import 'package:pocket_relay/src/core/models/connection_models.dart';

import 'codex_app_server_connection.dart';
import 'codex_app_server_models.dart';

class CodexAppServerRequestApi {
  const CodexAppServerRequestApi();

  Future<CodexAppServerSession> startSession(
    CodexAppServerConnection connection, {
    String? cwd,
    String? model,
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

    Object? response;
    try {
      response = await connection.sendRequest(method, params);
    } on CodexAppServerException catch (error) {
      if (effectiveResumeThreadId == null ||
          !_isRecoverableThreadResumeError(error)) {
        rethrow;
      }

      method = 'thread/start';
      params = <String, Object?>{
        ...baseParams,
        'ephemeral': profile.ephemeralSession,
      };
      response = await connection.sendRequest(method, params);
    }

    final payload = _requireObject(response, '$method response');
    final thread = _requireObject(payload['thread'], '$method thread');
    final threadId =
        _asString(thread['id']) ?? _asString(payload['threadId']) ?? '';

    if (threadId.isEmpty) {
      throw CodexAppServerException(
        '$method response did not include a thread id.',
      );
    }

    connection.setTrackedThread(threadId);

    return CodexAppServerSession(
      threadId: threadId,
      cwd: _asString(payload['cwd']) ?? effectiveCwd,
      model: _asString(payload['model']) ?? '',
      modelProvider: _asString(payload['modelProvider']) ?? '',
      approvalPolicy: payload['approvalPolicy'],
      sandbox: payload['sandbox'],
    );
  }

  Future<CodexAppServerTurn> sendUserMessage(
    CodexAppServerConnection connection, {
    required String threadId,
    required String text,
    String? model,
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

  Future<void> respondAuthTokensRefresh(
    CodexAppServerConnection connection, {
    required String requestId,
    required String accessToken,
    required String chatgptAccountId,
    String? chatgptPlanType,
  }) async {
    final pending = connection.requirePendingServerRequest(requestId);
    if (pending.method != 'account/chatgptAuthTokens/refresh') {
      throw CodexAppServerException(
        'Request $requestId is ${pending.method}, not account/chatgptAuthTokens/refresh.',
      );
    }

    await connection.sendServerResult(
      requestId: requestId,
      result: <String, Object?>{
        'accessToken': accessToken,
        'chatgptAccountId': chatgptAccountId,
        'chatgptPlanType': chatgptPlanType,
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
      'item/fileRead/requestApproval' => approved ? 'accept' : 'decline',
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
    final effectiveThreadId = threadId ?? connection.threadId;
    final effectiveTurnId = turnId ?? connection.activeTurnId;

    if (effectiveThreadId == null || effectiveTurnId == null) {
      return;
    }

    await connection.sendRequest('turn/interrupt', <String, Object?>{
      'threadId': effectiveThreadId,
      'turnId': effectiveTurnId,
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

  static String _approvalPolicyFor(ConnectionProfile profile) {
    return profile.dangerouslyBypassSandbox ? 'never' : 'onRequest';
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

  static bool _isRecoverableThreadResumeError(Object error) {
    final message = error.toString().toLowerCase();
    if (!message.contains('thread/resume')) {
      return false;
    }

    return const <String>[
      'not found',
      'missing thread',
      'no such thread',
      'unknown thread',
      'does not exist',
    ].any(message.contains);
  }
}
