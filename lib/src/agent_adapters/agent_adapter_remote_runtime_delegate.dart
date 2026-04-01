import 'package:pocket_relay/src/core/models/connection_models.dart';

typedef AgentAdapterRemoteRuntimeDelegateFactory =
    AgentAdapterRemoteRuntimeDelegate Function(AgentAdapterKind kind);

abstract interface class AgentAdapterRemoteRuntimeDelegate {
  Future<ConnectionRemoteRuntimeState> probeRemoteRuntime({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    String? ownerId,
  });

  Future<void> startRemoteServer({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
  });

  Future<void> stopRemoteServer({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
  });

  Future<void> restartRemoteServer({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
  });
}
