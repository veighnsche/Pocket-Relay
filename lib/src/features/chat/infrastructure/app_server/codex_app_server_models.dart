import 'dart:async';
import 'dart:typed_data';

import 'package:pocket_relay/src/core/models/connection_models.dart';

sealed class CodexAppServerEvent {
  const CodexAppServerEvent();
}

class CodexAppServerConnectedEvent extends CodexAppServerEvent {
  const CodexAppServerConnectedEvent({this.userAgent});

  final String? userAgent;
}

class CodexAppServerDisconnectedEvent extends CodexAppServerEvent {
  const CodexAppServerDisconnectedEvent({this.exitCode});

  final int? exitCode;
}

class CodexAppServerNotificationEvent extends CodexAppServerEvent {
  const CodexAppServerNotificationEvent({
    required this.method,
    required this.params,
  });

  final String method;
  final Object? params;
}

class CodexAppServerRequestEvent extends CodexAppServerEvent {
  const CodexAppServerRequestEvent({
    required this.requestId,
    required this.method,
    required this.params,
  });

  final String requestId;
  final String method;
  final Object? params;
}

class CodexAppServerDiagnosticEvent extends CodexAppServerEvent {
  const CodexAppServerDiagnosticEvent({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;
}

class CodexAppServerUnpinnedHostKeyEvent extends CodexAppServerEvent {
  const CodexAppServerUnpinnedHostKeyEvent({
    required this.host,
    required this.port,
    required this.keyType,
    required this.fingerprint,
  });

  final String host;
  final int port;
  final String keyType;
  final String fingerprint;
}

class CodexAppServerSshConnectFailedEvent extends CodexAppServerEvent {
  const CodexAppServerSshConnectFailedEvent({
    required this.host,
    required this.port,
    required this.message,
    this.detail,
  });

  final String host;
  final int port;
  final String message;
  final Object? detail;
}

class CodexAppServerSshHostKeyMismatchEvent extends CodexAppServerEvent {
  const CodexAppServerSshHostKeyMismatchEvent({
    required this.host,
    required this.port,
    required this.keyType,
    required this.expectedFingerprint,
    required this.actualFingerprint,
  });

  final String host;
  final int port;
  final String keyType;
  final String expectedFingerprint;
  final String actualFingerprint;
}

class CodexAppServerSshAuthenticationFailedEvent extends CodexAppServerEvent {
  const CodexAppServerSshAuthenticationFailedEvent({
    required this.host,
    required this.port,
    required this.username,
    required this.authMode,
    required this.message,
    this.detail,
  });

  final String host;
  final int port;
  final String username;
  final AuthMode authMode;
  final String message;
  final Object? detail;
}

class CodexAppServerSshAuthenticatedEvent extends CodexAppServerEvent {
  const CodexAppServerSshAuthenticatedEvent({
    required this.host,
    required this.port,
    required this.username,
    required this.authMode,
  });

  final String host;
  final int port;
  final String username;
  final AuthMode authMode;
}

class CodexAppServerSshRemoteLaunchFailedEvent extends CodexAppServerEvent {
  const CodexAppServerSshRemoteLaunchFailedEvent({
    required this.host,
    required this.port,
    required this.username,
    required this.command,
    required this.message,
    this.detail,
  });

  final String host;
  final int port;
  final String username;
  final String command;
  final String message;
  final Object? detail;
}

class CodexAppServerSshRemoteProcessStartedEvent extends CodexAppServerEvent {
  const CodexAppServerSshRemoteProcessStartedEvent({
    required this.host,
    required this.port,
    required this.username,
    required this.command,
  });

  final String host;
  final int port;
  final String username;
  final String command;
}

class CodexAppServerThread {
  const CodexAppServerThread({
    required this.id,
    this.preview = '',
    this.ephemeral = false,
    this.modelProvider = '',
    this.createdAt,
    this.updatedAt,
    this.path,
    this.cwd,
    this.promptCount,
    this.name,
    this.sourceKind,
    this.agentNickname,
    this.agentRole,
  });

  final String id;
  final String preview;
  final bool ephemeral;
  final String modelProvider;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? path;
  final String? cwd;
  final int? promptCount;
  final String? name;
  final String? sourceKind;
  final String? agentNickname;
  final String? agentRole;
}

class CodexAppServerThreadListPage {
  const CodexAppServerThreadListPage({
    required this.threads,
    required this.nextCursor,
  });

  final List<CodexAppServerThread> threads;
  final String? nextCursor;
}

class CodexAppServerSession {
  const CodexAppServerSession({
    required this.threadId,
    required this.cwd,
    required this.model,
    required this.modelProvider,
    this.reasoningEffort,
    this.thread,
    this.approvalPolicy,
    this.sandbox,
  });

  final String threadId;
  final String cwd;
  final String model;
  final String modelProvider;
  final String? reasoningEffort;
  final CodexAppServerThread? thread;
  final Object? approvalPolicy;
  final Object? sandbox;
}

class CodexAppServerTurn {
  const CodexAppServerTurn({required this.threadId, required this.turnId});

  final String threadId;
  final String turnId;
}

enum CodexAppServerElicitationAction { accept, decline, cancel }

class CodexAppServerException implements Exception {
  const CodexAppServerException(this.message, {this.code, this.data});

  final String message;
  final int? code;
  final Object? data;

  @override
  String toString() {
    if (code == null) {
      return 'CodexAppServerException: $message';
    }
    return 'CodexAppServerException($code): $message';
  }
}

abstract interface class CodexAppServerProcess {
  Stream<Uint8List> get stdout;
  Stream<Uint8List> get stderr;
  StreamSink<Uint8List> get stdin;
  Future<void> get done;
  int? get exitCode;
  Future<void> close();
}

typedef CodexAppServerProcessLauncher =
    Future<CodexAppServerProcess> Function({
      required ConnectionProfile profile,
      required ConnectionSecrets secrets,
      required void Function(CodexAppServerEvent event) emitEvent,
    });

abstract interface class CodexSshBootstrapClient {
  Future<void> authenticate();
  Future<CodexAppServerProcess> launchProcess(String command);
  void close();
}

typedef CodexSshProcessBootstrap =
    Future<CodexSshBootstrapClient> Function({
      required ConnectionProfile profile,
      required ConnectionSecrets secrets,
      required bool Function(String keyType, String actualFingerprint)
      verifyHostKey,
    });
