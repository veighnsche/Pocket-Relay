import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/app/pocket_relay_app.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_remote_runtime_delegate.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/testing/fake_agent_adapter_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';

export 'package:flutter/material.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:pocket_relay/src/app/pocket_relay_app.dart';
export 'package:pocket_relay/src/core/models/connection_models.dart';
export 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
export 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
export 'package:pocket_relay/src/features/chat/transport/agent_adapter/testing/fake_agent_adapter_client.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
export 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';

ConnectionProfile configuredProfile() {
  return ConnectionProfile.defaults().copyWith(
    host: 'example.com',
    username: 'vince',
    workspaceDir: '/workspace',
  );
}

SavedProfile testSavedProfile({
  ConnectionSecrets secrets = const ConnectionSecrets(password: 'secret'),
}) {
  return SavedProfile(profile: configuredProfile(), secrets: secrets);
}

SavedProfile savedProfile({
  ConnectionSecrets secrets = const ConnectionSecrets(password: 'secret'),
}) {
  return testSavedProfile(secrets: secrets);
}

PocketRelayApp buildCatalogApp({
  AgentAdapterClient? agentAdapterClient,
  @Deprecated('Use agentAdapterClient instead.')
  AgentAdapterClient? appServerClient,
  SavedProfile? savedProfile,
  CodexConnectionRepository? connectionRepository,
  AgentAdapterRemoteRuntimeDelegateFactory?
  agentAdapterRemoteRuntimeDelegateFactory,
  @Deprecated('Use agentAdapterRemoteRuntimeDelegateFactory instead.')
  CodexRemoteAppServerHostProbe remoteAppServerHostProbe =
      const FakeRemoteHostProbe(CodexRemoteAppServerHostCapabilities()),
  @Deprecated('Use agentAdapterRemoteRuntimeDelegateFactory instead.')
  CodexRemoteAppServerOwnerInspector remoteAppServerOwnerInspector =
      const FakeRemoteOwnerInspector(
        CodexRemoteAppServerOwnerSnapshot(
          ownerId: 'conn_primary',
          workspaceDir: '/workspace',
          status: CodexRemoteAppServerOwnerStatus.stopped,
          sessionName: 'pocket-relay-conn_primary',
          detail: 'Managed remote app-server is not running.',
        ),
      ),
}) {
  final resolvedAgentAdapterClient = agentAdapterClient ?? appServerClient;
  assert(
    resolvedAgentAdapterClient != null,
    'An agent adapter client is required.',
  );
  return PocketRelayApp(
    connectionRepository:
        connectionRepository ??
        MemoryCodexConnectionRepository.single(
          savedProfile: savedProfile ?? testSavedProfile(),
          connectionId: 'conn_primary',
        ),
    modelCatalogStore: MemoryConnectionModelCatalogStore(),
    recoveryStore: MemoryConnectionWorkspaceRecoveryStore(),
    agentAdapterClient: resolvedAgentAdapterClient!,
    agentAdapterRemoteRuntimeDelegateFactory:
        agentAdapterRemoteRuntimeDelegateFactory,
    remoteAppServerHostProbe: agentAdapterRemoteRuntimeDelegateFactory == null
        ? remoteAppServerHostProbe
        : null,
    remoteAppServerOwnerInspector:
        agentAdapterRemoteRuntimeDelegateFactory == null
        ? remoteAppServerOwnerInspector
        : null,
  );
}

Future<void> pumpAppReady(WidgetTester tester) {
  return pumpUntil(
    tester,
    () => find.byKey(const ValueKey('send')).evaluate().isNotEmpty,
  );
}

Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 2),
  Duration step = const Duration(milliseconds: 50),
}) async {
  final maxTicks = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (var tick = 0; tick < maxTicks; tick += 1) {
    await tester.pump(step);
    final exception = tester.takeException();
    if (exception != null) {
      throw exception;
    }
    if (predicate()) {
      return;
    }
  }

  throw TestFailure(
    'Condition was not met within $timeout. '
    'send=${find.byKey(const ValueKey('send')).evaluate().length} '
    'textField=${find.byType(TextField).evaluate().length} '
    'loading=${find.byType(CircularProgressIndicator).evaluate().length} '
    'title=${find.text('Pocket Relay').evaluate().length} '
    'configureRemote=${find.text('Configure remote').evaluate().length}',
  );
}

final class FakeRemoteHostProbe implements CodexRemoteAppServerHostProbe {
  const FakeRemoteHostProbe(this.capabilities);

  final CodexRemoteAppServerHostCapabilities capabilities;

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return capabilities;
  }
}

final class FakeRemoteOwnerInspector
    implements CodexRemoteAppServerOwnerInspector {
  const FakeRemoteOwnerInspector(this.snapshot);

  final CodexRemoteAppServerOwnerSnapshot snapshot;

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshot;
  }

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }
}
