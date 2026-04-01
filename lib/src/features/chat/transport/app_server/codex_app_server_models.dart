import 'dart:async';
import 'dart:typed_data';

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';

abstract interface class CodexAppServerEvent implements AgentAdapterEvent {}

class CodexAppServerConnectedEvent extends AgentAdapterConnectedEvent
    implements CodexAppServerEvent {
  const CodexAppServerConnectedEvent({super.userAgent});
}

class CodexAppServerDisconnectedEvent extends AgentAdapterDisconnectedEvent
    implements CodexAppServerEvent {
  const CodexAppServerDisconnectedEvent({super.exitCode});
}

class CodexAppServerNotificationEvent extends AgentAdapterNotificationEvent
    implements CodexAppServerEvent {
  const CodexAppServerNotificationEvent({
    required super.method,
    required super.params,
  });
}

class CodexAppServerRequestEvent extends AgentAdapterRequestEvent
    implements CodexAppServerEvent {
  const CodexAppServerRequestEvent({
    required super.requestId,
    required super.method,
    required super.params,
  });
}

class CodexAppServerDiagnosticEvent extends AgentAdapterDiagnosticEvent
    implements CodexAppServerEvent {
  const CodexAppServerDiagnosticEvent({
    required super.message,
    required super.isError,
  });
}

class CodexAppServerUnpinnedHostKeyEvent
    extends AgentAdapterUnpinnedHostKeyEvent
    implements CodexAppServerEvent {
  const CodexAppServerUnpinnedHostKeyEvent({
    required super.host,
    required super.port,
    required super.keyType,
    required super.fingerprint,
  });
}

class CodexAppServerSshConnectFailedEvent
    extends AgentAdapterSshConnectFailedEvent
    implements CodexAppServerEvent {
  const CodexAppServerSshConnectFailedEvent({
    required super.host,
    required super.port,
    required super.message,
    super.detail,
  });
}

class CodexAppServerSshHostKeyMismatchEvent
    extends AgentAdapterSshHostKeyMismatchEvent
    implements CodexAppServerEvent {
  const CodexAppServerSshHostKeyMismatchEvent({
    required super.host,
    required super.port,
    required super.keyType,
    required super.expectedFingerprint,
    required super.actualFingerprint,
  });
}

class CodexAppServerSshAuthenticationFailedEvent
    extends AgentAdapterSshAuthenticationFailedEvent
    implements CodexAppServerEvent {
  const CodexAppServerSshAuthenticationFailedEvent({
    required super.host,
    required super.port,
    required super.username,
    required super.authMode,
    required super.message,
    super.detail,
  });
}

class CodexAppServerSshAuthenticatedEvent
    extends AgentAdapterSshAuthenticatedEvent
    implements CodexAppServerEvent {
  const CodexAppServerSshAuthenticatedEvent({
    required super.host,
    required super.port,
    required super.username,
    required super.authMode,
  });
}

class CodexAppServerSshPortForwardStartedEvent
    extends AgentAdapterSshPortForwardStartedEvent
    implements CodexAppServerEvent {
  const CodexAppServerSshPortForwardStartedEvent({
    required super.host,
    required super.port,
    required super.username,
    required super.remoteHost,
    required super.remotePort,
    required super.localPort,
  });
}

class CodexAppServerSshPortForwardFailedEvent
    extends AgentAdapterSshPortForwardFailedEvent
    implements CodexAppServerEvent {
  const CodexAppServerSshPortForwardFailedEvent({
    required super.host,
    required super.port,
    required super.username,
    required super.remoteHost,
    required super.remotePort,
    required super.message,
    super.detail,
  });
}

class CodexAppServerThreadSummary extends AgentAdapterThreadSummary {
  const CodexAppServerThreadSummary({
    required super.id,
    super.preview = '',
    super.ephemeral = false,
    super.modelProvider = '',
    super.createdAt,
    super.updatedAt,
    super.path,
    super.cwd,
    super.promptCount,
    super.name,
    super.sourceKind,
    super.agentNickname,
    super.agentRole,
  });
}

class CodexAppServerHistoryItem extends AgentAdapterHistoryItem {
  const CodexAppServerHistoryItem({
    required super.id,
    super.type,
    super.status,
    required super.raw,
  });
}

class CodexAppServerHistoryTurn extends AgentAdapterHistoryTurn {
  const CodexAppServerHistoryTurn({
    required super.id,
    super.threadId,
    super.status,
    super.model,
    super.effort,
    super.stopReason,
    super.usage,
    super.modelUsage,
    super.totalCostUsd,
    super.error,
    super.items = const <CodexAppServerHistoryItem>[],
    required super.raw,
  });
}

class CodexAppServerThreadHistory extends AgentAdapterThreadHistory {
  const CodexAppServerThreadHistory({
    required super.id,
    super.preview = '',
    super.ephemeral = false,
    super.modelProvider = '',
    super.createdAt,
    super.updatedAt,
    super.path,
    super.cwd,
    super.promptCount,
    super.name,
    super.sourceKind,
    super.agentNickname,
    super.agentRole,
    super.turns = const <CodexAppServerHistoryTurn>[],
  });
}

class CodexAppServerThreadListPage extends AgentAdapterThreadListPage {
  const CodexAppServerThreadListPage({
    required super.threads,
    required super.nextCursor,
  });
}

class CodexAppServerModelUpgradeInfo extends AgentAdapterModelUpgradeInfo {
  const CodexAppServerModelUpgradeInfo({
    required super.model,
    super.upgradeCopy,
    super.modelLink,
    super.migrationMarkdown,
  });
}

class CodexAppServerReasoningEffortOption
    extends AgentAdapterReasoningEffortOption {
  const CodexAppServerReasoningEffortOption({
    required super.reasoningEffort,
    required super.description,
  });
}

class CodexAppServerModel extends AgentAdapterModel {
  const CodexAppServerModel({
    required super.id,
    required super.model,
    required super.displayName,
    required super.description,
    required super.hidden,
    required super.supportedReasoningEfforts,
    required super.defaultReasoningEffort,
    required super.inputModalities,
    required super.supportsPersonality,
    required super.isDefault,
    super.upgrade,
    super.upgradeInfo,
    super.availabilityNuxMessage,
  });
}

class CodexAppServerModelListPage extends AgentAdapterModelListPage {
  const CodexAppServerModelListPage({
    required super.models,
    required super.nextCursor,
  });
}

class CodexAppServerSession extends AgentAdapterSession {
  const CodexAppServerSession({
    required super.threadId,
    required super.cwd,
    required super.model,
    required super.modelProvider,
    super.reasoningEffort,
    super.thread,
    super.approvalPolicy,
    super.sandbox,
  });
}

class CodexAppServerTurn extends AgentAdapterTurn {
  const CodexAppServerTurn({required super.threadId, required super.turnId});
}

class CodexAppServerTurnInput extends AgentAdapterTurnInput {
  const CodexAppServerTurnInput({
    super.text = '',
    super.textElements = const <CodexAppServerTextElement>[],
    super.images = const <CodexAppServerImageInput>[],
  });

  const CodexAppServerTurnInput.text(String text) : super.text(text);
}

class CodexAppServerImageInput extends AgentAdapterImageInput {
  const CodexAppServerImageInput({required super.url});
}

class CodexAppServerTextElement extends AgentAdapterTextElement {
  const CodexAppServerTextElement({
    required super.start,
    required super.end,
    super.placeholder,
  });
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

class CodexAppServerTransportTermination {
  const CodexAppServerTransportTermination({this.exitCode, this.reason});

  final int? exitCode;
  final String? reason;
}

abstract interface class CodexAppServerTransport {
  Stream<String> get protocolMessages;
  Stream<String> get diagnostics;
  void sendLine(String line);
  Future<void> get done;
  CodexAppServerTransportTermination? get termination;
  Future<void> close();
}

typedef CodexAppServerTransportOpener =
    Future<CodexAppServerTransport> Function({
      required ConnectionProfile profile,
      required ConnectionSecrets secrets,
      required void Function(CodexAppServerEvent event) emitEvent,
    });

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
  Future<CodexSshForwardChannel> forwardLocal(
    String remoteHost,
    int remotePort, {
    String localHost = 'localhost',
    int localPort = 0,
  });
  void close();
}

abstract interface class CodexSshForwardChannel {
  Stream<Uint8List> get stream;
  StreamSink<List<int>> get sink;
  Future<void> get done;
  Future<void> close();
  void destroy();
}

typedef CodexSshProcessBootstrap =
    Future<CodexSshBootstrapClient> Function({
      required ConnectionProfile profile,
      required ConnectionSecrets secrets,
      required bool Function(String keyType, String actualFingerprint)
      verifyHostKey,
    });
