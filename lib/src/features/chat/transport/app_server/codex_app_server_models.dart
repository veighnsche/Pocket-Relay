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

class CodexAppServerSshPortForwardStartedEvent extends CodexAppServerEvent {
  const CodexAppServerSshPortForwardStartedEvent({
    required this.host,
    required this.port,
    required this.username,
    required this.remoteHost,
    required this.remotePort,
    required this.localPort,
  });

  final String host;
  final int port;
  final String username;
  final String remoteHost;
  final int remotePort;
  final int localPort;
}

class CodexAppServerSshPortForwardFailedEvent extends CodexAppServerEvent {
  const CodexAppServerSshPortForwardFailedEvent({
    required this.host,
    required this.port,
    required this.username,
    required this.remoteHost,
    required this.remotePort,
    required this.message,
    this.detail,
  });

  final String host;
  final int port;
  final String username;
  final String remoteHost;
  final int remotePort;
  final String message;
  final Object? detail;
}

class CodexAppServerThreadSummary {
  const CodexAppServerThreadSummary({
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

class CodexAppServerHistoryItem {
  const CodexAppServerHistoryItem({
    required this.id,
    this.type,
    this.status,
    required this.raw,
  });

  final String id;
  final String? type;
  final String? status;
  final Map<String, dynamic> raw;
}

class CodexAppServerHistoryTurn {
  const CodexAppServerHistoryTurn({
    required this.id,
    this.threadId,
    this.status,
    this.model,
    this.effort,
    this.stopReason,
    this.usage,
    this.modelUsage,
    this.totalCostUsd,
    this.error,
    this.items = const <CodexAppServerHistoryItem>[],
    required this.raw,
  });

  final String id;
  final String? threadId;
  final String? status;
  final String? model;
  final String? effort;
  final String? stopReason;
  final Map<String, dynamic>? usage;
  final Map<String, dynamic>? modelUsage;
  final double? totalCostUsd;
  final Map<String, dynamic>? error;
  final List<CodexAppServerHistoryItem> items;
  final Map<String, dynamic> raw;
}

class CodexAppServerThreadHistory extends CodexAppServerThreadSummary {
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
    this.turns = const <CodexAppServerHistoryTurn>[],
  });

  final List<CodexAppServerHistoryTurn> turns;
}

class CodexAppServerThreadListPage {
  const CodexAppServerThreadListPage({
    required this.threads,
    required this.nextCursor,
  });

  final List<CodexAppServerThreadSummary> threads;
  final String? nextCursor;
}

class CodexAppServerModelUpgradeInfo {
  const CodexAppServerModelUpgradeInfo({
    required this.model,
    this.upgradeCopy,
    this.modelLink,
    this.migrationMarkdown,
  });

  final String model;
  final String? upgradeCopy;
  final String? modelLink;
  final String? migrationMarkdown;

  @override
  bool operator ==(Object other) {
    return other is CodexAppServerModelUpgradeInfo &&
        other.model == model &&
        other.upgradeCopy == upgradeCopy &&
        other.modelLink == modelLink &&
        other.migrationMarkdown == migrationMarkdown;
  }

  @override
  int get hashCode =>
      Object.hash(model, upgradeCopy, modelLink, migrationMarkdown);
}

class CodexAppServerReasoningEffortOption {
  const CodexAppServerReasoningEffortOption({
    required this.reasoningEffort,
    required this.description,
  });

  final CodexReasoningEffort reasoningEffort;
  final String description;

  @override
  bool operator ==(Object other) {
    return other is CodexAppServerReasoningEffortOption &&
        other.reasoningEffort == reasoningEffort &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(reasoningEffort, description);
}

class CodexAppServerModel {
  const CodexAppServerModel({
    required this.id,
    required this.model,
    required this.displayName,
    required this.description,
    required this.hidden,
    required this.supportedReasoningEfforts,
    required this.defaultReasoningEffort,
    required this.inputModalities,
    required this.supportsPersonality,
    required this.isDefault,
    this.upgrade,
    this.upgradeInfo,
    this.availabilityNuxMessage,
  });

  final String id;
  final String model;
  final String displayName;
  final String description;
  final bool hidden;
  final List<CodexAppServerReasoningEffortOption> supportedReasoningEfforts;
  final CodexReasoningEffort defaultReasoningEffort;
  final List<String> inputModalities;
  final bool supportsPersonality;
  final bool isDefault;
  final String? upgrade;
  final CodexAppServerModelUpgradeInfo? upgradeInfo;
  final String? availabilityNuxMessage;

  bool get supportsImageInput => inputModalities.contains('image');

  @override
  bool operator ==(Object other) {
    return other is CodexAppServerModel &&
        other.id == id &&
        other.model == model &&
        other.displayName == displayName &&
        other.description == description &&
        other.hidden == hidden &&
        _listEquals(
          other.supportedReasoningEfforts,
          supportedReasoningEfforts,
        ) &&
        other.defaultReasoningEffort == defaultReasoningEffort &&
        _listEquals(other.inputModalities, inputModalities) &&
        other.supportsPersonality == supportsPersonality &&
        other.isDefault == isDefault &&
        other.upgrade == upgrade &&
        other.upgradeInfo == upgradeInfo &&
        other.availabilityNuxMessage == availabilityNuxMessage;
  }

  @override
  int get hashCode => Object.hash(
    id,
    model,
    displayName,
    description,
    hidden,
    Object.hashAll(supportedReasoningEfforts),
    defaultReasoningEffort,
    Object.hashAll(inputModalities),
    supportsPersonality,
    isDefault,
    upgrade,
    upgradeInfo,
    availabilityNuxMessage,
  );
}

class CodexAppServerModelListPage {
  const CodexAppServerModelListPage({
    required this.models,
    required this.nextCursor,
  });

  final List<CodexAppServerModel> models;
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
  final CodexAppServerThreadSummary? thread;
  final Object? approvalPolicy;
  final Object? sandbox;
}

class CodexAppServerTurn {
  const CodexAppServerTurn({required this.threadId, required this.turnId});

  final String threadId;
  final String turnId;
}

class CodexAppServerTurnInput {
  const CodexAppServerTurnInput({
    this.text = '',
    this.textElements = const <CodexAppServerTextElement>[],
    this.images = const <CodexAppServerImageInput>[],
  });

  const CodexAppServerTurnInput.text(String text)
    : this(text: text, textElements: const <CodexAppServerTextElement>[]);

  final String text;
  final List<CodexAppServerTextElement> textElements;
  final List<CodexAppServerImageInput> images;

  bool get hasText => text.trim().isNotEmpty || textElements.isNotEmpty;
  bool get hasImages => images.any((image) => image.url.trim().isNotEmpty);
  bool get isEmpty => !hasText && !hasImages;

  @override
  bool operator ==(Object other) {
    return other is CodexAppServerTurnInput &&
        other.text == text &&
        _listEquals(other.textElements, textElements) &&
        _listEquals(other.images, images);
  }

  @override
  int get hashCode =>
      Object.hash(text, Object.hashAll(textElements), Object.hashAll(images));
}

class CodexAppServerImageInput {
  const CodexAppServerImageInput({required this.url});

  final String url;

  @override
  bool operator ==(Object other) {
    return other is CodexAppServerImageInput && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;
}

class CodexAppServerTextElement {
  const CodexAppServerTextElement({
    required this.start,
    required this.end,
    this.placeholder,
  });

  final int start;
  final int end;
  final String? placeholder;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'byteRange': <String, Object?>{'start': start, 'end': end},
      if (placeholder != null) 'placeholder': placeholder,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is CodexAppServerTextElement &&
        other.start == start &&
        other.end == end &&
        other.placeholder == placeholder;
  }

  @override
  int get hashCode => Object.hash(start, end, placeholder);
}

enum CodexAppServerElicitationAction { accept, decline, cancel }

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

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
