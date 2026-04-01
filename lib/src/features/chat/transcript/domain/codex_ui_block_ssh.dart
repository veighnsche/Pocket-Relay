part of 'transcript_ui_block.dart';

sealed class TranscriptSshTranscriptBlock extends TranscriptUiBlock {
  const TranscriptSshTranscriptBlock({
    required super.id,
    required super.kind,
    required super.createdAt,
    required this.host,
    required this.port,
  });

  final String host;
  final int port;
}

final class TranscriptSshUnpinnedHostKeyBlock
    extends TranscriptSshTranscriptBlock {
  const TranscriptSshUnpinnedHostKeyBlock({
    required super.id,
    required super.createdAt,
    required super.host,
    required super.port,
    required this.keyType,
    required this.fingerprint,
    this.isSaved = false,
  }) : super(kind: TranscriptUiBlockKind.status);

  final String keyType;
  final String fingerprint;
  final bool isSaved;

  TranscriptSshUnpinnedHostKeyBlock copyWith({bool? isSaved}) {
    return TranscriptSshUnpinnedHostKeyBlock(
      id: id,
      createdAt: createdAt,
      host: host,
      port: port,
      keyType: keyType,
      fingerprint: fingerprint,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}

final class TranscriptSshConnectFailedBlock
    extends TranscriptSshTranscriptBlock {
  const TranscriptSshConnectFailedBlock({
    required super.id,
    required super.createdAt,
    required super.host,
    required super.port,
    required this.message,
  }) : super(kind: TranscriptUiBlockKind.error);

  final String message;
}

final class TranscriptSshHostKeyMismatchBlock
    extends TranscriptSshTranscriptBlock {
  const TranscriptSshHostKeyMismatchBlock({
    required super.id,
    required super.createdAt,
    required super.host,
    required super.port,
    required this.keyType,
    required this.expectedFingerprint,
    required this.actualFingerprint,
  }) : super(kind: TranscriptUiBlockKind.error);

  final String keyType;
  final String expectedFingerprint;
  final String actualFingerprint;
}

final class TranscriptSshAuthenticationFailedBlock
    extends TranscriptSshTranscriptBlock {
  const TranscriptSshAuthenticationFailedBlock({
    required super.id,
    required super.createdAt,
    required super.host,
    required super.port,
    required this.username,
    required this.authMode,
    required this.message,
  }) : super(kind: TranscriptUiBlockKind.error);

  final String username;
  final AuthMode authMode;
  final String message;
}
