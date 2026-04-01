part of 'transcript_ui_block.dart';

enum TranscriptUiBlockKind {
  userMessage,
  assistantMessage,
  reasoning,
  plan,
  proposedPlan,
  workLogEntry,
  workLogGroup,
  changedFiles,
  approvalRequest,
  userInputRequest,
  status,
  error,
  usage,
  turnBoundary,
}

sealed class TranscriptUiBlock {
  const TranscriptUiBlock({
    required this.id,
    required this.kind,
    required this.createdAt,
  });

  final String id;
  final TranscriptUiBlockKind kind;
  final DateTime createdAt;
}

class TranscriptChangedFile {
  const TranscriptChangedFile({
    required this.path,
    this.movePath,
    this.additions = 0,
    this.deletions = 0,
  });

  final String path;
  final String? movePath;
  final int additions;
  final int deletions;

  TranscriptChangedFile copyWith({
    String? path,
    Object? movePath = _unchangedMovePath,
    int? additions,
    int? deletions,
  }) {
    return TranscriptChangedFile(
      path: path ?? this.path,
      movePath: identical(movePath, _unchangedMovePath)
          ? this.movePath
          : movePath as String?,
      additions: additions ?? this.additions,
      deletions: deletions ?? this.deletions,
    );
  }
}

const Object _unchangedMovePath = Object();

enum TranscriptWorkLogEntryKind {
  commandExecution,
  webSearch,
  imageView,
  imageGeneration,
  mcpToolCall,
  dynamicToolCall,
  collabAgentToolCall,
  unknown,
}

class TranscriptWorkLogEntry {
  const TranscriptWorkLogEntry({
    required this.id,
    required this.createdAt,
    required this.entryKind,
    required this.title,
    this.itemId,
    this.threadId,
    this.turnId,
    this.preview,
    this.body,
    this.isRunning = false,
    this.exitCode,
    this.snapshot,
  });

  final String id;
  final DateTime createdAt;
  final TranscriptWorkLogEntryKind entryKind;
  final String title;
  final String? itemId;
  final String? threadId;
  final String? turnId;
  final String? preview;
  final String? body;
  final bool isRunning;
  final int? exitCode;
  final Map<String, dynamic>? snapshot;

  TranscriptWorkLogEntry copyWith({
    DateTime? createdAt,
    TranscriptWorkLogEntryKind? entryKind,
    String? title,
    String? itemId,
    String? threadId,
    String? turnId,
    String? preview,
    String? body,
    bool? isRunning,
    int? exitCode,
    Map<String, dynamic>? snapshot,
  }) {
    return TranscriptWorkLogEntry(
      id: id,
      createdAt: createdAt ?? this.createdAt,
      entryKind: entryKind ?? this.entryKind,
      title: title ?? this.title,
      itemId: itemId ?? this.itemId,
      threadId: threadId ?? this.threadId,
      turnId: turnId ?? this.turnId,
      preview: preview ?? this.preview,
      body: body ?? this.body,
      isRunning: isRunning ?? this.isRunning,
      exitCode: exitCode ?? this.exitCode,
      snapshot: snapshot ?? this.snapshot,
    );
  }
}

final class TranscriptUserMessageBlock extends TranscriptUiBlock {
  const TranscriptUserMessageBlock({
    required super.id,
    required super.createdAt,
    required this.text,
    required this.deliveryState,
    this.structuredDraft,
    this.providerItemId,
  }) : super(kind: TranscriptUiBlockKind.userMessage);

  final String text;
  final TranscriptUserMessageDeliveryState deliveryState;
  final ChatComposerDraft? structuredDraft;
  final String? providerItemId;

  ChatComposerDraft get draft =>
      structuredDraft ?? ChatComposerDraft(text: text);

  TranscriptUserMessageBlock copyWith({
    String? text,
    TranscriptUserMessageDeliveryState? deliveryState,
    ChatComposerDraft? structuredDraft,
    bool clearStructuredDraft = false,
    String? providerItemId,
    bool clearProviderItemId = false,
  }) {
    return TranscriptUserMessageBlock(
      id: id,
      createdAt: createdAt,
      text: text ?? this.text,
      deliveryState: deliveryState ?? this.deliveryState,
      structuredDraft: clearStructuredDraft
          ? null
          : (structuredDraft ?? this.structuredDraft),
      providerItemId: clearProviderItemId
          ? null
          : (providerItemId ?? this.providerItemId),
    );
  }
}

enum TranscriptUserMessageDeliveryState { localEcho, sent }
