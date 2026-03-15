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
          CodexRuntimeSessionStartedEvent(
            createdAt: now,
            rawMethod: 'transport/connected',
            userAgent: userAgent,
          ),
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
