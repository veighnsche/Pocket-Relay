part of 'codex_runtime_event.dart';

final class CodexRuntimeWarningEvent extends CodexRuntimeEvent {
  const CodexRuntimeWarningEvent({
    required super.createdAt,
    required this.summary,
    super.threadId,
    super.turnId,
    super.itemId,
    super.requestId,
    super.rawMethod,
    super.rawPayload,
    this.details,
  });

  final String summary;
  final String? details;
}

final class CodexRuntimeSshConnectFailedEvent extends CodexRuntimeEvent {
  const CodexRuntimeSshConnectFailedEvent({
    required super.createdAt,
    required this.host,
    required this.port,
    required this.message,
    super.threadId,
    super.turnId,
    super.itemId,
    super.requestId,
    super.rawMethod,
    super.rawPayload,
    this.detail,
  });

  final String host;
  final int port;
  final String message;
  final Object? detail;
}

final class CodexRuntimeUnpinnedHostKeyEvent extends CodexRuntimeEvent {
  const CodexRuntimeUnpinnedHostKeyEvent({
    required super.createdAt,
    required this.host,
    required this.port,
    required this.keyType,
    required this.fingerprint,
    super.threadId,
    super.turnId,
    super.itemId,
    super.requestId,
    super.rawMethod,
    super.rawPayload,
  });

  final String host;
  final int port;
  final String keyType;
  final String fingerprint;
}

final class CodexRuntimeSshHostKeyMismatchEvent extends CodexRuntimeEvent {
  const CodexRuntimeSshHostKeyMismatchEvent({
    required super.createdAt,
    required this.host,
    required this.port,
    required this.keyType,
    required this.expectedFingerprint,
    required this.actualFingerprint,
    super.threadId,
    super.turnId,
    super.itemId,
    super.requestId,
    super.rawMethod,
    super.rawPayload,
  });

  final String host;
  final int port;
  final String keyType;
  final String expectedFingerprint;
  final String actualFingerprint;
}

final class CodexRuntimeSshAuthenticationFailedEvent extends CodexRuntimeEvent {
  const CodexRuntimeSshAuthenticationFailedEvent({
    required super.createdAt,
    required this.host,
    required this.port,
    required this.username,
    required this.authMode,
    required this.message,
    super.threadId,
    super.turnId,
    super.itemId,
    super.requestId,
    super.rawMethod,
    super.rawPayload,
    this.detail,
  });

  final String host;
  final int port;
  final String username;
  final AuthMode authMode;
  final String message;
  final Object? detail;
}

final class CodexRuntimeSshAuthenticatedEvent extends CodexRuntimeEvent {
  const CodexRuntimeSshAuthenticatedEvent({
    required super.createdAt,
    required this.host,
    required this.port,
    required this.username,
    required this.authMode,
    super.threadId,
    super.turnId,
    super.itemId,
    super.requestId,
    super.rawMethod,
    super.rawPayload,
  });

  final String host;
  final int port;
  final String username;
  final AuthMode authMode;
}

final class CodexRuntimeStatusEvent extends CodexRuntimeEvent {
  const CodexRuntimeStatusEvent({
    required super.createdAt,
    required this.title,
    required this.message,
    super.threadId,
    super.turnId,
    super.itemId,
    super.requestId,
    super.rawMethod,
    super.rawPayload,
  });

  final String title;
  final String message;
}

final class CodexRuntimeErrorEvent extends CodexRuntimeEvent {
  const CodexRuntimeErrorEvent({
    required super.createdAt,
    required this.message,
    required this.errorClass,
    super.threadId,
    super.turnId,
    super.itemId,
    super.requestId,
    super.rawMethod,
    super.rawPayload,
    this.detail,
  });

  final String message;
  final CodexRuntimeErrorClass errorClass;
  final Object? detail;
}
