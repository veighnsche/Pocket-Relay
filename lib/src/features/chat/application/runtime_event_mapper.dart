import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_json_rpc_codec.dart';

part 'runtime_event_mapper_notification_mapper.dart';
part 'runtime_event_mapper_request_mapper.dart';
part 'runtime_event_mapper_support.dart';

class CodexRuntimeEventMapper {
  final _pendingRequests = <String, _PendingRequestInfo>{};

  List<CodexRuntimeEvent> mapEvent(CodexAppServerEvent event) {
    final now = DateTime.now();

    switch (event) {
      case CodexAppServerConnectedEvent(:final userAgent):
        _pendingRequests.clear();
        return <CodexRuntimeEvent>[
          CodexRuntimeSessionStateChangedEvent(
            createdAt: now,
            state: CodexRuntimeSessionState.ready,
            reason: userAgent == null
                ? 'App-server connected.'
                : 'App-server connected as $userAgent.',
            rawMethod: 'transport/connected',
          ),
        ];
      case CodexAppServerDisconnectedEvent(:final exitCode):
        _pendingRequests.clear();
        return <CodexRuntimeEvent>[
          CodexRuntimeSessionExitedEvent(
            createdAt: now,
            exitKind: exitCode == null || exitCode == 0
                ? CodexRuntimeSessionExitKind.graceful
                : CodexRuntimeSessionExitKind.error,
            exitCode: exitCode,
            reason: exitCode == null
                ? 'App-server disconnected.'
                : 'App-server exited with code $exitCode.',
            rawMethod: 'transport/disconnected',
          ),
        ];
      case CodexAppServerDiagnosticEvent(:final message, :final isError):
        return <CodexRuntimeEvent>[
          isError
              ? CodexRuntimeErrorEvent(
                  createdAt: now,
                  message: message,
                  errorClass: CodexRuntimeErrorClass.transportError,
                  rawMethod: 'transport/diagnostic',
                )
              : CodexRuntimeWarningEvent(
                  createdAt: now,
                  summary: message,
                  rawMethod: 'transport/diagnostic',
                ),
        ];
      case CodexAppServerUnpinnedHostKeyEvent(
        :final host,
        :final port,
        :final keyType,
        :final fingerprint,
      ):
        return <CodexRuntimeEvent>[
          CodexRuntimeUnpinnedHostKeyEvent(
            createdAt: now,
            host: host,
            port: port,
            keyType: keyType,
            fingerprint: fingerprint,
            rawMethod: 'transport/hostKey/unpinned',
          ),
        ];
      case CodexAppServerSshConnectFailedEvent(
        :final host,
        :final port,
        :final message,
        :final detail,
      ):
        return _mapSshConnectFailedRuntimeEvents(
          now,
          host: host,
          port: port,
          message: message,
          detail: detail,
        );
      case CodexAppServerSshHostKeyMismatchEvent(
        :final host,
        :final port,
        :final keyType,
        :final expectedFingerprint,
        :final actualFingerprint,
      ):
        return _mapSshHostKeyMismatchRuntimeEvents(
          now,
          host: host,
          port: port,
          keyType: keyType,
          expectedFingerprint: expectedFingerprint,
          actualFingerprint: actualFingerprint,
        );
      case CodexAppServerSshAuthenticationFailedEvent(
        :final host,
        :final port,
        :final username,
        :final authMode,
        :final message,
        :final detail,
      ):
        return _mapSshAuthenticationFailedRuntimeEvents(
          now,
          host: host,
          port: port,
          username: username,
          authMode: authMode,
          message: message,
          detail: detail,
        );
      case CodexAppServerSshAuthenticatedEvent(
        :final host,
        :final port,
        :final username,
        :final authMode,
      ):
        return <CodexRuntimeEvent>[
          CodexRuntimeSshAuthenticatedEvent(
            createdAt: now,
            host: host,
            port: port,
            username: username,
            authMode: authMode,
            rawMethod: 'transport/ssh/authenticated',
          ),
        ];
      case CodexAppServerSshRemoteLaunchFailedEvent(
        :final host,
        :final port,
        :final username,
        :final command,
        :final message,
        :final detail,
      ):
        return _mapSshRemoteLaunchFailedRuntimeEvents(
          now,
          host: host,
          port: port,
          username: username,
          command: command,
          message: message,
          detail: detail,
        );
      case CodexAppServerSshRemoteProcessStartedEvent(
        :final host,
        :final port,
        :final username,
        :final command,
      ):
        return <CodexRuntimeEvent>[
          CodexRuntimeSshRemoteProcessStartedEvent(
            createdAt: now,
            host: host,
            port: port,
            username: username,
            command: command,
            rawMethod: 'transport/ssh/remoteProcessStarted',
          ),
        ];
      case CodexAppServerRequestEvent():
        return _mapRuntimeRequestEvent(
          event,
          now,
          pendingRequests: _pendingRequests,
        );
      case CodexAppServerNotificationEvent():
        return _mapRuntimeNotificationEvent(
          event,
          now,
          pendingRequests: _pendingRequests,
        );
    }
  }
}

class _PendingRequestInfo {
  const _PendingRequestInfo({
    required this.requestType,
    this.threadId,
    this.turnId,
    this.itemId,
  });

  final CodexCanonicalRequestType requestType;
  final String? threadId;
  final String? turnId;
  final String? itemId;
}

List<CodexRuntimeEvent> _mapSshConnectFailedRuntimeEvents(
  DateTime createdAt, {
  required String host,
  required int port,
  required String message,
  Object? detail,
}) {
  return <CodexRuntimeEvent>[
    CodexRuntimeSshConnectFailedEvent(
      createdAt: createdAt,
      host: host,
      port: port,
      message: message,
      detail: detail,
      rawMethod: 'transport/ssh/connectFailed',
    ),
    CodexRuntimeErrorEvent(
      createdAt: createdAt,
      message: _combineRuntimeErrorMessage(
        'Could not connect to $host:$port.',
        message,
      ),
      errorClass: CodexRuntimeErrorClass.transportError,
      detail: detail,
      rawMethod: 'transport/ssh/connectFailed',
    ),
  ];
}

List<CodexRuntimeEvent> _mapSshHostKeyMismatchRuntimeEvents(
  DateTime createdAt, {
  required String host,
  required int port,
  required String keyType,
  required String expectedFingerprint,
  required String actualFingerprint,
}) {
  final message =
      'Host key mismatch for $host:$port. Expected $expectedFingerprint, got '
      '$actualFingerprint.';
  return <CodexRuntimeEvent>[
    CodexRuntimeSshHostKeyMismatchEvent(
      createdAt: createdAt,
      host: host,
      port: port,
      keyType: keyType,
      expectedFingerprint: expectedFingerprint,
      actualFingerprint: actualFingerprint,
      rawMethod: 'transport/ssh/hostKeyMismatch',
    ),
    CodexRuntimeErrorEvent(
      createdAt: createdAt,
      message: message,
      errorClass: CodexRuntimeErrorClass.transportError,
      rawMethod: 'transport/ssh/hostKeyMismatch',
    ),
  ];
}

List<CodexRuntimeEvent> _mapSshAuthenticationFailedRuntimeEvents(
  DateTime createdAt, {
  required String host,
  required int port,
  required String username,
  required AuthMode authMode,
  required String message,
  Object? detail,
}) {
  return <CodexRuntimeEvent>[
    CodexRuntimeSshAuthenticationFailedEvent(
      createdAt: createdAt,
      host: host,
      port: port,
      username: username,
      authMode: authMode,
      message: message,
      detail: detail,
      rawMethod: 'transport/ssh/authFailed',
    ),
    CodexRuntimeErrorEvent(
      createdAt: createdAt,
      message: _combineRuntimeErrorMessage(
        'SSH authentication failed for $username@$host:$port.',
        message,
      ),
      errorClass: CodexRuntimeErrorClass.transportError,
      detail: detail,
      rawMethod: 'transport/ssh/authFailed',
    ),
  ];
}

List<CodexRuntimeEvent> _mapSshRemoteLaunchFailedRuntimeEvents(
  DateTime createdAt, {
  required String host,
  required int port,
  required String username,
  required String command,
  required String message,
  Object? detail,
}) {
  return <CodexRuntimeEvent>[
    CodexRuntimeSshRemoteLaunchFailedEvent(
      createdAt: createdAt,
      host: host,
      port: port,
      username: username,
      command: command,
      message: message,
      detail: detail,
      rawMethod: 'transport/ssh/remoteLaunchFailed',
    ),
    CodexRuntimeErrorEvent(
      createdAt: createdAt,
      message: _combineRuntimeErrorMessage(
        'Could not launch the remote Codex app-server command.',
        message,
      ),
      errorClass: CodexRuntimeErrorClass.transportError,
      detail: detail,
      rawMethod: 'transport/ssh/remoteLaunchFailed',
    ),
  ];
}

String _combineRuntimeErrorMessage(String summary, String detail) {
  final trimmedDetail = detail.trim();
  if (trimmedDetail.isEmpty) {
    return summary;
  }
  return '$summary\n\n$trimmedDetail';
}
