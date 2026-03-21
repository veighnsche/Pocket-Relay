import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';

sealed class ChatRequestContract {
  const ChatRequestContract({
    required this.id,
    required this.createdAt,
    required this.requestId,
    required this.requestType,
    required this.title,
    required this.body,
    required this.isResolved,
  });

  final String id;
  final DateTime createdAt;
  final String requestId;
  final CodexCanonicalRequestType requestType;
  final String title;
  final String body;
  final bool isResolved;
}

final class ChatApprovalRequestContract extends ChatRequestContract {
  const ChatApprovalRequestContract({
    required super.id,
    required super.createdAt,
    required super.requestId,
    required super.requestType,
    required super.title,
    required super.body,
    required super.isResolved,
    this.resolutionLabel,
  });

  final String? resolutionLabel;
}

final class ChatUserInputRequestContract extends ChatRequestContract {
  const ChatUserInputRequestContract({
    required super.id,
    required super.createdAt,
    required super.requestId,
    required super.requestType,
    required super.title,
    required super.body,
    required super.isResolved,
    this.questions = const <CodexRuntimeUserInputQuestion>[],
    this.answers = const <String, List<String>>{},
  });

  final List<CodexRuntimeUserInputQuestion> questions;
  final Map<String, List<String>> answers;
}
