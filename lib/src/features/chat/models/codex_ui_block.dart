import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';

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
  final bool isRunning;
  final int? exitCode;
  final Map<String, dynamic>? snapshot;

  CodexWorkLogEntry copyWith({
    DateTime? createdAt,
    CodexWorkLogEntryKind? entryKind,
    String? title,
    String? turnId,
    String? preview,
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
    this.providerItemId,
  }) : super(kind: CodexUiBlockKind.userMessage);

  final String text;
  final CodexUserMessageDeliveryState deliveryState;
  final String? providerItemId;

  CodexUserMessageBlock copyWith({
    String? text,
    CodexUserMessageDeliveryState? deliveryState,
    String? providerItemId,
    bool clearProviderItemId = false,
  }) {
    return CodexUserMessageBlock(
      id: id,
      createdAt: createdAt,
      text: text ?? this.text,
      deliveryState: deliveryState ?? this.deliveryState,
      providerItemId: clearProviderItemId
          ? null
          : (providerItemId ?? this.providerItemId),
    );
  }
}

enum CodexUserMessageDeliveryState { localEcho, sent }

final class CodexTextBlock extends CodexUiBlock {
  const CodexTextBlock({
    required super.id,
    required super.kind,
    required super.createdAt,
    required this.title,
    required this.body,
    this.turnId,
    this.isRunning = false,
  });

  final String title;
  final String body;
  final String? turnId;
  final bool isRunning;

  CodexTextBlock copyWith({
    String? title,
    String? body,
    String? turnId,
    bool? isRunning,
  }) {
    return CodexTextBlock(
      id: id,
      kind: kind,
      createdAt: createdAt,
      title: title ?? this.title,
      body: body ?? this.body,
      turnId: turnId ?? this.turnId,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

final class CodexPlanUpdateBlock extends CodexUiBlock {
  const CodexPlanUpdateBlock({
    required super.id,
    required super.createdAt,
    this.explanation,
    this.steps = const <CodexRuntimePlanStep>[],
  }) : super(kind: CodexUiBlockKind.plan);

  final String? explanation;
  final List<CodexRuntimePlanStep> steps;

  CodexPlanUpdateBlock copyWith({
    String? explanation,
    List<CodexRuntimePlanStep>? steps,
  }) {
    return CodexPlanUpdateBlock(
      id: id,
      createdAt: createdAt,
      explanation: explanation ?? this.explanation,
      steps: steps ?? this.steps,
    );
  }
}

final class CodexProposedPlanBlock extends CodexUiBlock {
  const CodexProposedPlanBlock({
    required super.id,
    required super.createdAt,
    required this.title,
    required this.markdown,
    this.turnId,
    this.isStreaming = false,
  }) : super(kind: CodexUiBlockKind.proposedPlan);

  final String title;
  final String markdown;
  final String? turnId;
  final bool isStreaming;

  CodexProposedPlanBlock copyWith({
    String? title,
    String? markdown,
    String? turnId,
    bool? isStreaming,
  }) {
    return CodexProposedPlanBlock(
      id: id,
      createdAt: createdAt,
      title: title ?? this.title,
      markdown: markdown ?? this.markdown,
      turnId: turnId ?? this.turnId,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

final class CodexWorkLogGroupBlock extends CodexUiBlock {
  const CodexWorkLogGroupBlock({
    required super.id,
    required super.createdAt,
    required this.entries,
  }) : super(kind: CodexUiBlockKind.workLogGroup);

  final List<CodexWorkLogEntry> entries;

  CodexWorkLogGroupBlock copyWith({List<CodexWorkLogEntry>? entries}) {
    return CodexWorkLogGroupBlock(
      id: id,
      createdAt: createdAt,
      entries: entries ?? this.entries,
    );
  }
}

final class CodexChangedFilesBlock extends CodexUiBlock {
  const CodexChangedFilesBlock({
    required super.id,
    required super.createdAt,
    required this.title,
    this.files = const <CodexChangedFile>[],
    this.unifiedDiff,
    this.turnId,
    this.isRunning = false,
  }) : super(kind: CodexUiBlockKind.changedFiles);

  final String title;
  final List<CodexChangedFile> files;
  final String? unifiedDiff;
  final String? turnId;
  final bool isRunning;

  CodexChangedFilesBlock copyWith({
    String? title,
    List<CodexChangedFile>? files,
    String? unifiedDiff,
    String? turnId,
    bool? isRunning,
  }) {
    return CodexChangedFilesBlock(
      id: id,
      createdAt: createdAt,
      title: title ?? this.title,
      files: files ?? this.files,
      unifiedDiff: unifiedDiff ?? this.unifiedDiff,
      turnId: turnId ?? this.turnId,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

final class CodexApprovalRequestBlock extends CodexUiBlock {
  const CodexApprovalRequestBlock({
    required super.id,
    required super.createdAt,
    required this.requestId,
    required this.requestType,
    required this.title,
    required this.body,
    this.isResolved = false,
    this.resolutionLabel,
  }) : super(kind: CodexUiBlockKind.approvalRequest);

  final String requestId;
  final CodexCanonicalRequestType requestType;
  final String title;
  final String body;
  final bool isResolved;
  final String? resolutionLabel;

  CodexApprovalRequestBlock copyWith({
    String? title,
    String? body,
    bool? isResolved,
    String? resolutionLabel,
  }) {
    return CodexApprovalRequestBlock(
      id: id,
      createdAt: createdAt,
      requestId: requestId,
      requestType: requestType,
      title: title ?? this.title,
      body: body ?? this.body,
      isResolved: isResolved ?? this.isResolved,
      resolutionLabel: resolutionLabel ?? this.resolutionLabel,
    );
  }
}

final class CodexUserInputRequestBlock extends CodexUiBlock {
  const CodexUserInputRequestBlock({
    required super.id,
    required super.createdAt,
    required this.requestId,
    required this.requestType,
    required this.title,
    required this.body,
    this.questions = const <CodexRuntimeUserInputQuestion>[],
    this.isResolved = false,
    this.answers = const <String, List<String>>{},
  }) : super(kind: CodexUiBlockKind.userInputRequest);

  final String requestId;
  final CodexCanonicalRequestType requestType;
  final String title;
  final String body;
  final List<CodexRuntimeUserInputQuestion> questions;
  final bool isResolved;
  final Map<String, List<String>> answers;

  CodexUserInputRequestBlock copyWith({
    String? title,
    String? body,
    List<CodexRuntimeUserInputQuestion>? questions,
    bool? isResolved,
    Map<String, List<String>>? answers,
  }) {
    return CodexUserInputRequestBlock(
      id: id,
      createdAt: createdAt,
      requestId: requestId,
      requestType: requestType,
      title: title ?? this.title,
      body: body ?? this.body,
      questions: questions ?? this.questions,
      isResolved: isResolved ?? this.isResolved,
      answers: answers ?? this.answers,
    );
  }
}

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

final class CodexSshRemoteLaunchFailedBlock extends CodexSshTranscriptBlock {
  const CodexSshRemoteLaunchFailedBlock({
    required super.id,
    required super.createdAt,
    required super.host,
    required super.port,
    required this.username,
    required this.command,
    required this.message,
  }) : super(kind: CodexUiBlockKind.error);

  final String username;
  final String command;
  final String message;
}

final class CodexStatusBlock extends CodexUiBlock {
  const CodexStatusBlock({
    required super.id,
    required super.createdAt,
    required this.title,
    required this.body,
    this.statusKind = CodexStatusBlockKind.info,
    this.isTranscriptSignal = false,
  }) : super(kind: CodexUiBlockKind.status);

  final String title;
  final String body;
  final CodexStatusBlockKind statusKind;
  final bool isTranscriptSignal;
}

enum CodexStatusBlockKind {
  info,
  warning,
  review,
  compaction,
  auth,
}

final class CodexErrorBlock extends CodexUiBlock {
  const CodexErrorBlock({
    required super.id,
    required super.createdAt,
    required this.title,
    required this.body,
  }) : super(kind: CodexUiBlockKind.error);

  final String title;
  final String body;
}

final class CodexUsageBlock extends CodexUiBlock {
  const CodexUsageBlock({
    required super.id,
    required super.createdAt,
    required this.title,
    required this.body,
  }) : super(kind: CodexUiBlockKind.usage);

  final String title;
  final String body;
}

final class CodexTurnBoundaryBlock extends CodexUiBlock {
  const CodexTurnBoundaryBlock({
    required super.id,
    required super.createdAt,
    this.label = 'end',
    this.elapsed,
    this.usage,
  }) : super(kind: CodexUiBlockKind.turnBoundary);

  final String label;
  final Duration? elapsed;
  final CodexUsageBlock? usage;
}
