part of 'transcript_runtime_event.dart';

final class TranscriptRuntimeWarningEvent extends TranscriptRuntimeEvent {
  const TranscriptRuntimeWarningEvent({
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

final class TranscriptRuntimeSshConnectFailedEvent
    extends TranscriptRuntimeEvent {
  const TranscriptRuntimeSshConnectFailedEvent({
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

final class TranscriptRuntimeUnpinnedHostKeyEvent
    extends TranscriptRuntimeEvent {
  const TranscriptRuntimeUnpinnedHostKeyEvent({
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

final class TranscriptRuntimeSshHostKeyMismatchEvent
    extends TranscriptRuntimeEvent {
  const TranscriptRuntimeSshHostKeyMismatchEvent({
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

final class TranscriptRuntimeSshAuthenticationFailedEvent
    extends TranscriptRuntimeEvent {
  const TranscriptRuntimeSshAuthenticationFailedEvent({
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

final class TranscriptRuntimeSshAuthenticatedEvent
    extends TranscriptRuntimeEvent {
  const TranscriptRuntimeSshAuthenticatedEvent({
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

final class TranscriptRuntimeStatusEvent extends TranscriptRuntimeEvent {
  const TranscriptRuntimeStatusEvent({
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

final class TranscriptRuntimeErrorEvent extends TranscriptRuntimeEvent {
  const TranscriptRuntimeErrorEvent({
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
  final TranscriptRuntimeErrorClass errorClass;
  final Object? detail;
}
