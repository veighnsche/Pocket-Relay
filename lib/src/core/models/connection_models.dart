import 'package:flutter/foundation.dart';

part 'connection_models_catalog.dart';
part 'connection_models_codex_models.dart';
part 'connection_models_host.dart';
part 'connection_models_model_catalog.dart';
part 'connection_models_model_selection.dart';
part 'connection_models_profile.dart';
part 'connection_models_remote_runtime.dart';
part 'connection_models_saved_connection.dart';
part 'connection_models_system.dart';
part 'connection_models_workspace.dart';

enum AuthMode { password, privateKey }

enum ConnectionMode { remote, local }

enum AgentAdapterReasoningEffort { none, minimal, low, medium, high, xhigh }

@Deprecated('Use AgentAdapterReasoningEffort instead.')
typedef CodexReasoningEffort = AgentAdapterReasoningEffort;

AgentAdapterReasoningEffort? agentAdapterReasoningEffortFromWireValue(
  String? value,
) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  for (final effort in AgentAdapterReasoningEffort.values) {
    if (effort.name == normalized) {
      return effort;
    }
  }

  return null;
}

@Deprecated('Use agentAdapterReasoningEffortFromWireValue instead.')
CodexReasoningEffort? codexReasoningEffortFromWireValue(String? value) =>
    agentAdapterReasoningEffortFromWireValue(value);

AuthMode _authModeFromName(String? value, {required AuthMode fallback}) {
  for (final mode in AuthMode.values) {
    if (mode.name == value) {
      return mode;
    }
  }

  return fallback;
}

ConnectionMode _connectionModeFromName(
  String? value, {
  required ConnectionMode fallback,
}) {
  for (final mode in ConnectionMode.values) {
    if (mode.name == value) {
      return mode;
    }
  }

  return fallback;
}

bool connectionSecretsEqual(ConnectionSecrets first, ConnectionSecrets second) {
  return first == second;
}
