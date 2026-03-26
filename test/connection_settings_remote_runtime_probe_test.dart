import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_remote_runtime_probe.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';

void main() {
  test(
    'probeConnectionSettingsRemoteRuntime maps supported running owner state',
    () async {
      final runtime = await probeConnectionSettingsRemoteRuntime(
        payload: _payload(),
        ownerId: 'remote-1',
        hostProbe: _FakeHostProbe(const CodexRemoteAppServerHostCapabilities()),
        ownerInspector: _FakeOwnerInspector(
          const CodexRemoteAppServerOwnerSnapshot(
            ownerId: 'remote-1',
            workspaceDir: '/workspace',
            status: CodexRemoteAppServerOwnerStatus.running,
            sessionName: 'pocket-relay:remote-1',
            endpoint: CodexRemoteAppServerEndpoint(
              host: '127.0.0.1',
              port: 4100,
            ),
          ),
        ),
      );

      expect(runtime.hostCapability.isSupported, isTrue);
      expect(runtime.server.status, ConnectionRemoteServerStatus.running);
      expect(runtime.server.ownerId, 'remote-1');
      expect(runtime.server.sessionName, 'pocket-relay:remote-1');
      expect(runtime.server.port, 4100);
    },
  );

  test(
    'probeConnectionSettingsRemoteRuntime keeps server unknown without owner id',
    () async {
      final runtime = await probeConnectionSettingsRemoteRuntime(
        payload: _payload(),
        hostProbe: _FakeHostProbe(const CodexRemoteAppServerHostCapabilities()),
        ownerInspector: _ThrowingOwnerInspector(),
      );

      expect(runtime.hostCapability.isSupported, isTrue);
      expect(runtime.server.status, ConnectionRemoteServerStatus.unknown);
    },
  );

  test(
    'probeConnectionSettingsRemoteRuntime does not inspect owner when host is unsupported',
    () async {
      final runtime = await probeConnectionSettingsRemoteRuntime(
        payload: _payload(),
        ownerId: 'remote-1',
        hostProbe: _FakeHostProbe(
          const CodexRemoteAppServerHostCapabilities(
            issues: <ConnectionRemoteHostCapabilityIssue>{
              ConnectionRemoteHostCapabilityIssue.tmuxMissing,
            },
          ),
        ),
        ownerInspector: _ThrowingOwnerInspector(),
      );

      expect(runtime.hostCapability.isUnsupported, isTrue);
      expect(runtime.server.status, ConnectionRemoteServerStatus.unknown);
    },
  );

  test(
    'probeConnectionSettingsRemoteRuntime preserves explicit workspace capability issues',
    () async {
      final runtime = await probeConnectionSettingsRemoteRuntime(
        payload: _payload(),
        ownerId: 'remote-1',
        hostProbe: _FakeHostProbe(
          const CodexRemoteAppServerHostCapabilities(
            issues: <ConnectionRemoteHostCapabilityIssue>{
              ConnectionRemoteHostCapabilityIssue.workspaceUnavailable,
            },
            detail:
                'The configured workspace directory is not accessible on the remote host.',
          ),
        ),
        ownerInspector: _ThrowingOwnerInspector(),
      );

      expect(runtime.hostCapability.isUnsupported, isTrue);
      expect(
        runtime.hostCapability.issues,
        <ConnectionRemoteHostCapabilityIssue>{
          ConnectionRemoteHostCapabilityIssue.workspaceUnavailable,
        },
      );
      expect(
        runtime.hostCapability.detail,
        contains('workspace directory is not accessible'),
      );
      expect(runtime.server.status, ConnectionRemoteServerStatus.unknown);
    },
  );

  test(
    'probeConnectionSettingsRemoteRuntime maps missing owner to notRunning',
    () async {
      final runtime = await probeConnectionSettingsRemoteRuntime(
        payload: _payload(),
        ownerId: 'remote-1',
        hostProbe: _FakeHostProbe(const CodexRemoteAppServerHostCapabilities()),
        ownerInspector: _FakeOwnerInspector(
          const CodexRemoteAppServerOwnerSnapshot(
            ownerId: 'remote-1',
            workspaceDir: '/workspace',
            status: CodexRemoteAppServerOwnerStatus.missing,
            sessionName: 'pocket-relay:remote-1',
            detail: 'No Pocket Relay server is running for this connection.',
          ),
        ),
      );

      expect(runtime.server.status, ConnectionRemoteServerStatus.notRunning);
      expect(
        runtime.server.detail,
        contains('No Pocket Relay server is running'),
      );
    },
  );
}

ConnectionSettingsSubmitPayload _payload() {
  return ConnectionSettingsSubmitPayload(
    profile: const ConnectionProfile(
      label: 'Developer Box',
      host: 'example.com',
      port: 22,
      username: 'vince',
      workspaceDir: '/workspace',
      codexPath: 'codex',
      authMode: AuthMode.password,
      hostFingerprint: 'SHA256:test',
      dangerouslyBypassSandbox: false,
      ephemeralSession: false,
    ),
    secrets: const ConnectionSecrets(password: 'secret'),
  );
}

final class _FakeHostProbe implements CodexRemoteAppServerHostProbe {
  const _FakeHostProbe(this.capabilities);

  final CodexRemoteAppServerHostCapabilities capabilities;

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return capabilities;
  }
}

final class _FakeOwnerInspector implements CodexRemoteAppServerOwnerInspector {
  const _FakeOwnerInspector(this.snapshot);

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

final class _ThrowingOwnerInspector
    implements CodexRemoteAppServerOwnerInspector {
  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    throw StateError('owner inspection should not have been called');
  }

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }
}
