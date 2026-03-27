part of 'codex_ui_block.dart';

enum CodexUiBlockKind {
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

sealed class CodexUiBlock {
  const CodexUiBlock({
    required this.id,
    required this.kind,
    required this.createdAt,
  });

  final String id;
  final CodexUiBlockKind kind;
  final DateTime createdAt;
}

class CodexChangedFile {
  const CodexChangedFile({
    required this.path,
    this.movePath,
    this.additions = 0,
    this.deletions = 0,
  });

  final String path;
  final String? movePath;
  final int additions;
  final int deletions;

  CodexChangedFile copyWith({
    String? path,
    Object? movePath = _unchangedMovePath,
    int? additions,
    int? deletions,
  }) {
    return CodexChangedFile(
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

enum CodexWorkLogEntryKind {
  commandExecution,
  webSearch,
  imageView,
  imageGeneration,
  mcpToolCall,
  dynamicToolCall,
  collabAgentToolCall,
  unknown,
}

class CodexWorkLogEntry {
  const CodexWorkLogEntry({
    required this.id,
    required this.createdAt,
    required this.entryKind,
    required this.title,
    this.turnId,
    this.preview,
    this.body,
    this.isRunning = false,
    this.exitCode,
    this.snapshot,
  });

  final String id;
  final DateTime createdAt;
  final CodexWorkLogEntryKind entryKind;
  final String title;
  final String? turnId;
  final String? preview;
  final String? body;
  final bool isRunning;
  final int? exitCode;
  final Map<String, dynamic>? snapshot;

  CodexWorkLogEntry copyWith({
    DateTime? createdAt,
    CodexWorkLogEntryKind? entryKind,
    String? title,
    String? turnId,
    String? preview,
    String? body,
    bool? isRunning,
    int? exitCode,
    Map<String, dynamic>? snapshot,
  }) {
    return CodexWorkLogEntry(
      id: id,
      createdAt: createdAt ?? this.createdAt,
      entryKind: entryKind ?? this.entryKind,
      title: title ?? this.title,
      turnId: turnId ?? this.turnId,
      preview: preview ?? this.preview,
      body: body ?? this.body,
      isRunning: isRunning ?? this.isRunning,
      exitCode: exitCode ?? this.exitCode,
      snapshot: snapshot ?? this.snapshot,
    );
  }
}

final class CodexUserMessageBlock extends CodexUiBlock {
  const CodexUserMessageBlock({
    required super.id,
    required super.createdAt,
    required this.text,
    required this.deliveryState,
    this.structuredDraft,
    this.providerItemId,
  }) : super(kind: CodexUiBlockKind.userMessage);

  final String text;
  final CodexUserMessageDeliveryState deliveryState;
  final ChatComposerDraft? structuredDraft;
  final String? providerItemId;

  ChatComposerDraft get draft =>
      structuredDraft ?? ChatComposerDraft(text: text);

  CodexUserMessageBlock copyWith({
    String? text,
    CodexUserMessageDeliveryState? deliveryState,
    ChatComposerDraft? structuredDraft,
    bool clearStructuredDraft = false,
    String? providerItemId,
    bool clearProviderItemId = false,
  }) {
    return CodexUserMessageBlock(
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

enum CodexUserMessageDeliveryState { localEcho, sent }
