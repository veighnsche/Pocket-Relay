part of 'codex_ui_block.dart';

sealed class CodexSshTranscriptBlock extends CodexUiBlock {
  const CodexSshTranscriptBlock({
    required super.id,
    required super.kind,
    required super.createdAt,
    required this.host,
    required this.port,
  });

  final String host;
  final int port;
}

final class CodexSshUnpinnedHostKeyBlock extends CodexSshTranscriptBlock {
  const CodexSshUnpinnedHostKeyBlock({
    required super.id,
    required super.createdAt,
    required super.host,
    required super.port,
    required this.keyType,
    required this.fingerprint,
    this.isSaved = false,
  }) : super(kind: CodexUiBlockKind.status);

  final String keyType;
  final String fingerprint;
  final bool isSaved;

  CodexSshUnpinnedHostKeyBlock copyWith({bool? isSaved}) {
    return CodexSshUnpinnedHostKeyBlock(
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

final class CodexSshConnectFailedBlock extends CodexSshTranscriptBlock {
  const CodexSshConnectFailedBlock({
    required super.id,
    required super.createdAt,
    required super.host,
    required super.port,
    required this.message,
  }) : super(kind: CodexUiBlockKind.error);

  final String message;
}

final class CodexSshHostKeyMismatchBlock extends CodexSshTranscriptBlock {
  const CodexSshHostKeyMismatchBlock({
    required super.id,
    required super.createdAt,
    required super.host,
    required super.port,
    required this.keyType,
    required this.expectedFingerprint,
    required this.actualFingerprint,
  }) : super(kind: CodexUiBlockKind.error);

  final String keyType;
  final String expectedFingerprint;
  final String actualFingerprint;
}

final class CodexSshAuthenticationFailedBlock extends CodexSshTranscriptBlock {
  const CodexSshAuthenticationFailedBlock({
    required super.id,
    required super.createdAt,
    required super.host,
    required super.port,
    required this.username,
    required this.authMode,
    required this.message,
  }) : super(kind: CodexUiBlockKind.error);

  final String username;
  final AuthMode authMode;
  final String message;
}
