part of 'codex_app_server_request_api.dart';

Future<CodexAppServerTurn> _sendUserMessage(
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

Future<void> _answerUserInput(
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
        (key, value) =>
            MapEntry<String, Object?>(key, <String, Object?>{'answers': value}),
      ),
    },
  );
}

Future<void> _respondDynamicToolCall(
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
    result: <String, Object?>{'contentItems': contentItems, 'success': success},
  );
}

Future<void> _resolveApproval(
  CodexAppServerConnection connection, {
  required String requestId,
  required bool approved,
}) async {
  final pending = connection.requirePendingServerRequest(requestId);
  if (pending.method == 'item/permissions/requestApproval') {
    await _resolvePermissionsRequest(
      connection,
      requestId: requestId,
      approved: approved,
    );
    return;
  }

  final decision = switch (pending.method) {
    'item/commandExecution/requestApproval' => approved ? 'accept' : 'decline',
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

Future<void> _resolvePermissionsRequest(
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

Future<void> _respondToElicitation(
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

Future<void> _abortTurn(
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
