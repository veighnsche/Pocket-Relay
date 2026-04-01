part of 'connection_models.dart';

enum AgentAdapterKind {
  codex(label: 'Codex', defaultCommand: 'codex');

  const AgentAdapterKind({required this.label, required this.defaultCommand});

  final String label;
  final String defaultCommand;
}

@Deprecated('Use AgentAdapterKind instead.')
typedef HostKind = AgentAdapterKind;

AgentAdapterKind _agentAdapterKindFromName(
  String? value, {
  required AgentAdapterKind fallback,
}) {
  for (final kind in AgentAdapterKind.values) {
    if (kind.name == value) {
      return kind;
    }
  }

  return fallback;
}

String defaultAgentAdapterCommandForKind(AgentAdapterKind kind) {
  return kind.defaultCommand;
}

String defaultHostCommandForKind(AgentAdapterKind kind) {
  return defaultAgentAdapterCommandForKind(kind);
}

String agentAdapterKindLabel(AgentAdapterKind kind) {
  return kind.label;
}

String hostKindLabel(AgentAdapterKind kind) {
  return agentAdapterKindLabel(kind);
}
