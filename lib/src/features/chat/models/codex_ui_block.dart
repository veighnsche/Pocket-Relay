import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';

enum CodexUiBlockKind {
  userMessage,
  assistantMessage,
  reasoning,
  plan,
  commandExecution,
  fileChange,
  approvalRequest,
  userInputRequest,
  status,
  error,
  usage,
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

final class CodexUserMessageBlock extends CodexUiBlock {
  const CodexUserMessageBlock({
    required super.id,
    required super.createdAt,
    required this.text,
  }) : super(kind: CodexUiBlockKind.userMessage);

  final String text;
}

final class CodexTextBlock extends CodexUiBlock {
  const CodexTextBlock({
    required super.id,
    required super.kind,
    required super.createdAt,
    required this.title,
    required this.body,
    this.isRunning = false,
  });

  final String title;
  final String body;
  final bool isRunning;

  CodexTextBlock copyWith({String? title, String? body, bool? isRunning}) {
    return CodexTextBlock(
      id: id,
      kind: kind,
      createdAt: createdAt,
      title: title ?? this.title,
      body: body ?? this.body,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

final class CodexCommandExecutionBlock extends CodexUiBlock {
  const CodexCommandExecutionBlock({
    required super.id,
    required super.createdAt,
    required this.command,
    required this.output,
    this.isRunning = false,
    this.exitCode,
  }) : super(kind: CodexUiBlockKind.commandExecution);

  final String command;
  final String output;
  final bool isRunning;
  final int? exitCode;

  CodexCommandExecutionBlock copyWith({
    String? command,
    String? output,
    bool? isRunning,
    int? exitCode,
  }) {
    return CodexCommandExecutionBlock(
      id: id,
      createdAt: createdAt,
      command: command ?? this.command,
      output: output ?? this.output,
      isRunning: isRunning ?? this.isRunning,
      exitCode: exitCode ?? this.exitCode,
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

final class CodexStatusBlock extends CodexUiBlock {
  const CodexStatusBlock({
    required super.id,
    required super.createdAt,
    required this.title,
    required this.body,
  }) : super(kind: CodexUiBlockKind.status);

  final String title;
  final String body;
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
