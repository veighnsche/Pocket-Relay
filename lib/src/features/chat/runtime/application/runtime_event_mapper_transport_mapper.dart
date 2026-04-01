part of 'runtime_event_mapper.dart';

List<TranscriptRuntimeEvent>? _mapTransportRuntimeEvent(
  AgentAdapterEvent event,
  DateTime now,
) {
  switch (event) {
    case AgentAdapterConnectedEvent(:final userAgent):
      return <TranscriptRuntimeEvent>[
        TranscriptRuntimeSessionStateChangedEvent(
          createdAt: now,
          state: TranscriptRuntimeSessionState.ready,
          reason: userAgent == null
              ? 'App-server connected.'
              : 'App-server connected as $userAgent.',
          rawMethod: 'transport/connected',
        ),
      ];
    case AgentAdapterDisconnectedEvent(:final exitCode):
      return <TranscriptRuntimeEvent>[
        TranscriptRuntimeSessionExitedEvent(
          createdAt: now,
          exitKind: exitCode == null || exitCode == 0
              ? TranscriptRuntimeSessionExitKind.graceful
              : TranscriptRuntimeSessionExitKind.error,
          exitCode: exitCode,
          reason: exitCode == null
              ? 'App-server disconnected.'
              : 'App-server exited with code $exitCode.',
          rawMethod: 'transport/disconnected',
        ),
      ];
    case AgentAdapterDiagnosticEvent(:final message, :final isError):
      return <TranscriptRuntimeEvent>[
        isError
            ? TranscriptRuntimeErrorEvent(
                createdAt: now,
                message: message,
                errorClass: TranscriptRuntimeErrorClass.transportError,
                rawMethod: 'transport/diagnostic',
              )
            : TranscriptRuntimeWarningEvent(
                createdAt: now,
                summary: message,
                rawMethod: 'transport/diagnostic',
              ),
      ];
    case AgentAdapterUnpinnedHostKeyEvent(
      :final host,
      :final port,
      :final keyType,
      :final fingerprint,
    ):
      return <TranscriptRuntimeEvent>[
        TranscriptRuntimeUnpinnedHostKeyEvent(
          createdAt: now,
          host: host,
          port: port,
          keyType: keyType,
          fingerprint: fingerprint,
          rawMethod: 'transport/hostKey/unpinned',
        ),
      ];
    case AgentAdapterSshConnectFailedEvent(
      :final host,
      :final port,
      :final message,
      :final detail,
    ):
      return <TranscriptRuntimeEvent>[
        TranscriptRuntimeSshConnectFailedEvent(
          createdAt: now,
          host: host,
          port: port,
          message: message,
          detail: detail,
          rawMethod: 'transport/ssh/connectFailed',
        ),
      ];
    case AgentAdapterSshHostKeyMismatchEvent(
      :final host,
      :final port,
      :final keyType,
      :final expectedFingerprint,
      :final actualFingerprint,
    ):
      return <TranscriptRuntimeEvent>[
        TranscriptRuntimeSshHostKeyMismatchEvent(
          createdAt: now,
          host: host,
          port: port,
          keyType: keyType,
          expectedFingerprint: expectedFingerprint,
          actualFingerprint: actualFingerprint,
          rawMethod: 'transport/ssh/hostKeyMismatch',
        ),
      ];
    case AgentAdapterSshAuthenticationFailedEvent(
      :final host,
      :final port,
      :final username,
      :final authMode,
      :final message,
      :final detail,
    ):
      return <TranscriptRuntimeEvent>[
        TranscriptRuntimeSshAuthenticationFailedEvent(
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
    case AgentAdapterSshAuthenticatedEvent(
      :final host,
      :final port,
      :final username,
      :final authMode,
    ):
      return <TranscriptRuntimeEvent>[
        TranscriptRuntimeSshAuthenticatedEvent(
          createdAt: now,
          host: host,
          port: port,
          username: username,
          authMode: authMode,
          rawMethod: 'transport/ssh/authenticated',
        ),
      ];
    case AgentAdapterSshPortForwardStartedEvent(
      :final host,
      :final port,
      :final username,
      :final remoteHost,
      :final remotePort,
      :final localPort,
    ):
      return <TranscriptRuntimeEvent>[
        TranscriptRuntimeWarningEvent(
          createdAt: now,
          summary:
              'SSH forwarding ready for $username@$host:$port to $remoteHost:$remotePort on localhost:$localPort.',
          rawMethod: 'transport/ssh/portForwardStarted',
        ),
      ];
    case AgentAdapterSshPortForwardFailedEvent(
      :final host,
      :final port,
      :final username,
      :final remoteHost,
      :final remotePort,
      :final message,
      :final detail,
    ):
      return <TranscriptRuntimeEvent>[
        TranscriptRuntimeErrorEvent(
          createdAt: now,
          message:
              'SSH forwarding failed for $username@$host:$port to $remoteHost:$remotePort: $message',
          detail: detail,
          errorClass: TranscriptRuntimeErrorClass.transportError,
          rawMethod: 'transport/ssh/portForwardFailed',
        ),
      ];
    case AgentAdapterRequestEvent() || AgentAdapterNotificationEvent():
      return null;
  }

  return null;
}
