abstract class AgentAdapterRuntimeEvent {
  const AgentAdapterRuntimeEvent({
    required this.createdAt,
    this.threadId,
    this.turnId,
    this.itemId,
    this.requestId,
    this.rawMethod,
    this.rawPayload,
  });

  final DateTime createdAt;
  final String? threadId;
  final String? turnId;
  final String? itemId;
  final String? requestId;
  final String? rawMethod;
  final Object? rawPayload;
}
