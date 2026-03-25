part of 'runtime_event_mapper.dart';

List<CodexRuntimeEvent>? _mapTransportRuntimeEvent(
  CodexAppServerEvent event,
  DateTime now,
) {
  switch (event) {
    case CodexAppServerConnectedEvent(:final userAgent):
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
      return <CodexRuntimeEvent>[
        CodexRuntimeSshConnectFailedEvent(
          createdAt: now,
          host: host,
          port: port,
          message: message,
          detail: detail,
          rawMethod: 'transport/ssh/connectFailed',
        ),
      ];
    case CodexAppServerSshHostKeyMismatchEvent(
      :final host,
      :final port,
      :final keyType,
      :final expectedFingerprint,
      :final actualFingerprint,
    ):
      return <CodexRuntimeEvent>[
        CodexRuntimeSshHostKeyMismatchEvent(
          createdAt: now,
          host: host,
          port: port,
          keyType: keyType,
          expectedFingerprint: expectedFingerprint,
          actualFingerprint: actualFingerprint,
          rawMethod: 'transport/ssh/hostKeyMismatch',
        ),
      ];
    case CodexAppServerSshAuthenticationFailedEvent(
      :final host,
      :final port,
      :final username,
      :final authMode,
      :final message,
      :final detail,
    ):
      return <CodexRuntimeEvent>[
        CodexRuntimeSshAuthenticationFailedEvent(
          createdAt: now,
          host: host,
          port: port,
          username: username,
          authMode: authMode,
          message: message,
          detail: detail,
          rawMethod: 'transport/ssh/authFailed',
        ),
      ];
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
    case CodexAppServerSshPortForwardStartedEvent(
      :final host,
      :final port,
      :final username,
      :final remoteHost,
      :final remotePort,
      :final localPort,
    ):
      return <CodexRuntimeEvent>[
        CodexRuntimeWarningEvent(
          createdAt: now,
          summary:
              'SSH forwarding ready for $username@$host:$port to $remoteHost:$remotePort on localhost:$localPort.',
          rawMethod: 'transport/ssh/portForwardStarted',
        ),
      ];
    case CodexAppServerSshPortForwardFailedEvent(
      :final host,
      :final port,
      :final username,
      :final remoteHost,
      :final remotePort,
      :final message,
      :final detail,
    ):
      return <CodexRuntimeEvent>[
        CodexRuntimeErrorEvent(
          createdAt: now,
          message:
              'SSH forwarding failed for $username@$host:$port to $remoteHost:$remotePort: $message',
          detail: detail,
          errorClass: CodexRuntimeErrorClass.transportError,
          rawMethod: 'transport/ssh/portForwardFailed',
        ),
      ];
    case CodexAppServerRequestEvent() || CodexAppServerNotificationEvent():
      return null;
  }
}
