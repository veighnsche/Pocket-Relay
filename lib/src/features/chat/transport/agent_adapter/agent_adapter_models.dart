import 'package:pocket_relay/src/core/models/connection_models.dart';

abstract class AgentAdapterEvent {
  const AgentAdapterEvent();
}

class AgentAdapterConnectedEvent extends AgentAdapterEvent {
  const AgentAdapterConnectedEvent({this.userAgent});

  final String? userAgent;
}

class AgentAdapterDisconnectedEvent extends AgentAdapterEvent {
  const AgentAdapterDisconnectedEvent({this.exitCode});

  final int? exitCode;
}

class AgentAdapterNotificationEvent extends AgentAdapterEvent {
  const AgentAdapterNotificationEvent({
    required this.method,
    required this.params,
  });

  final String method;
  final Object? params;
}

class AgentAdapterRequestEvent extends AgentAdapterEvent {
  const AgentAdapterRequestEvent({
    required this.requestId,
    required this.method,
    required this.params,
  });

  final String requestId;
  final String method;
  final Object? params;
}

class AgentAdapterDiagnosticEvent extends AgentAdapterEvent {
  const AgentAdapterDiagnosticEvent({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;
}

class AgentAdapterUnpinnedHostKeyEvent extends AgentAdapterEvent {
  const AgentAdapterUnpinnedHostKeyEvent({
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

class AgentAdapterSshConnectFailedEvent extends AgentAdapterEvent {
  const AgentAdapterSshConnectFailedEvent({
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

class AgentAdapterSshHostKeyMismatchEvent extends AgentAdapterEvent {
  const AgentAdapterSshHostKeyMismatchEvent({
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

class AgentAdapterSshAuthenticationFailedEvent extends AgentAdapterEvent {
  const AgentAdapterSshAuthenticationFailedEvent({
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

class AgentAdapterSshAuthenticatedEvent extends AgentAdapterEvent {
  const AgentAdapterSshAuthenticatedEvent({
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

class AgentAdapterSshPortForwardStartedEvent extends AgentAdapterEvent {
  const AgentAdapterSshPortForwardStartedEvent({
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

class AgentAdapterSshPortForwardFailedEvent extends AgentAdapterEvent {
  const AgentAdapterSshPortForwardFailedEvent({
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

class AgentAdapterThreadSummary {
  const AgentAdapterThreadSummary({
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

class AgentAdapterHistoryItem {
  const AgentAdapterHistoryItem({
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

class AgentAdapterHistoryTurn {
  const AgentAdapterHistoryTurn({
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
    this.items = const <AgentAdapterHistoryItem>[],
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
  final List<AgentAdapterHistoryItem> items;
  final Map<String, dynamic> raw;
}

class AgentAdapterThreadHistory extends AgentAdapterThreadSummary {
  const AgentAdapterThreadHistory({
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
    this.turns = const <AgentAdapterHistoryTurn>[],
  });

  final List<AgentAdapterHistoryTurn> turns;
}

class AgentAdapterThreadListPage {
  const AgentAdapterThreadListPage({
    required this.threads,
    required this.nextCursor,
  });

  final List<AgentAdapterThreadSummary> threads;
  final String? nextCursor;
}

class AgentAdapterModelUpgradeInfo {
  const AgentAdapterModelUpgradeInfo({
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
    return other is AgentAdapterModelUpgradeInfo &&
        other.model == model &&
        other.upgradeCopy == upgradeCopy &&
        other.modelLink == modelLink &&
        other.migrationMarkdown == migrationMarkdown;
  }

  @override
  int get hashCode =>
      Object.hash(model, upgradeCopy, modelLink, migrationMarkdown);
}

class AgentAdapterReasoningEffortOption {
  const AgentAdapterReasoningEffortOption({
    required this.reasoningEffort,
    required this.description,
  });

  final AgentAdapterReasoningEffort reasoningEffort;
  final String description;

  @override
  bool operator ==(Object other) {
    return other is AgentAdapterReasoningEffortOption &&
        other.reasoningEffort == reasoningEffort &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(reasoningEffort, description);
}

class AgentAdapterModel {
  const AgentAdapterModel({
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
  final List<AgentAdapterReasoningEffortOption> supportedReasoningEfforts;
  final AgentAdapterReasoningEffort defaultReasoningEffort;
  final List<String> inputModalities;
  final bool supportsPersonality;
  final bool isDefault;
  final String? upgrade;
  final AgentAdapterModelUpgradeInfo? upgradeInfo;
  final String? availabilityNuxMessage;

  bool get supportsImageInput => inputModalities.contains('image');

  @override
  bool operator ==(Object other) {
    return other is AgentAdapterModel &&
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

class AgentAdapterModelListPage {
  const AgentAdapterModelListPage({
    required this.models,
    required this.nextCursor,
  });

  final List<AgentAdapterModel> models;
  final String? nextCursor;
}

class AgentAdapterSession {
  const AgentAdapterSession({
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
  final AgentAdapterThreadSummary? thread;
  final Object? approvalPolicy;
  final Object? sandbox;
}

class AgentAdapterTurn {
  const AgentAdapterTurn({required this.threadId, required this.turnId});

  final String threadId;
  final String turnId;
}

class AgentAdapterTurnInput {
  const AgentAdapterTurnInput({
    this.text = '',
    this.textElements = const <AgentAdapterTextElement>[],
    this.images = const <AgentAdapterImageInput>[],
  });

  const AgentAdapterTurnInput.text(String text)
    : this(text: text, textElements: const <AgentAdapterTextElement>[]);

  final String text;
  final List<AgentAdapterTextElement> textElements;
  final List<AgentAdapterImageInput> images;

  bool get hasText => text.trim().isNotEmpty || textElements.isNotEmpty;
  bool get hasImages => images.any((image) => image.url.trim().isNotEmpty);
  bool get isEmpty => !hasText && !hasImages;

  @override
  bool operator ==(Object other) {
    return other is AgentAdapterTurnInput &&
        other.text == text &&
        _listEquals(other.textElements, textElements) &&
        _listEquals(other.images, images);
  }

  @override
  int get hashCode =>
      Object.hash(text, Object.hashAll(textElements), Object.hashAll(images));
}

class AgentAdapterImageInput {
  const AgentAdapterImageInput({required this.url});

  final String url;

  @override
  bool operator ==(Object other) {
    return other is AgentAdapterImageInput && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;
}

class AgentAdapterTextElement {
  const AgentAdapterTextElement({
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
    return other is AgentAdapterTextElement &&
        other.start == start &&
        other.end == end &&
        other.placeholder == placeholder;
  }

  @override
  int get hashCode => Object.hash(start, end, placeholder);
}

enum AgentAdapterElicitationAction { accept, decline, cancel }

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
