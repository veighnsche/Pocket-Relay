import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_lifecycle_errors.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';

void main() {
  test(
    'open connection failure maps a stopped remote owner to a stable code',
    () {
      final error = ConnectionLifecycleErrors.openConnectionFailure(
        profile: _remoteProfile(),
        remoteRuntime: const ConnectionRemoteRuntimeState(
          hostCapability: ConnectionRemoteHostCapabilityState.supported(),
          server: ConnectionRemoteServerState.notRunning(
            ownerId: 'conn_primary',
            sessionName: 'pocket-relay-conn_primary',
            detail: 'No managed remote app-server is running for this connection.',
          ),
        ),
      );

      expect(
        error.definition,
        PocketErrorCatalog.connectionOpenRemoteServerStopped,
      );
      expect(
        error.inlineMessage,
        contains(
          '[${PocketErrorCatalog.connectionOpenRemoteServerStopped.code}]',
        ),
      );
    },
  );

  test(
    'start server failure keeps the runtime code and the underlying error',
    () {
      final error = ConnectionLifecycleErrors.remoteServerActionFailure(
        ConnectionSettingsRemoteServerActionId.start,
        remoteRuntime: const ConnectionRemoteRuntimeState(
          hostCapability: ConnectionRemoteHostCapabilityState.supported(),
          server: ConnectionRemoteServerState.notRunning(
            ownerId: 'conn_primary',
            sessionName: 'pocket-relay-conn_primary',
            detail: 'No managed remote app-server is running for this connection.',
          ),
        ),
        error: StateError(
          'Remote owner control command failed: exit 1 | tmux is not available on the remote host.',
        ),
      );

      expect(
        error.definition,
        PocketErrorCatalog.connectionStartServerStillStopped,
      );
      expect(error.inlineMessage, contains('Underlying error:'));
      expect(
        error.inlineMessage,
        contains('tmux is not available on the remote host.'),
      );
    },
  );

  test(
    'transport unavailable notice maps unsupported continuity to a stable code',
    () {
      final error = ConnectionLifecycleErrors.transportUnavailableNotice(
        const ConnectionRemoteRuntimeState(
          hostCapability: ConnectionRemoteHostCapabilityState.unsupported(
            issues: <ConnectionRemoteHostCapabilityIssue>{
              ConnectionRemoteHostCapabilityIssue.tmuxMissing,
            },
            detail: 'tmux is not installed on this host.',
          ),
          server: ConnectionRemoteServerState.unknown(),
        ),
      );

      expect(
        error.definition,
        PocketErrorCatalog.connectionReconnectContinuityUnsupported,
      );
      expect(error.title, 'Remote continuity unavailable');
      expect(
        error.bodyWithCode,
        contains('tmux is not installed on this host.'),
      );
    },
  );

  test(
    'conversation history failure maps unpinned host keys to a stable code',
    () {
      final error = ConnectionLifecycleErrors.conversationHistoryFailure(
        const CodexWorkspaceConversationHistoryUnpinnedHostKeyException(
          host: 'example.com',
          port: 22,
          keyType: 'ssh-ed25519',
          fingerprint: '7a:9f:d7:dc:2e:f2',
        ),
      );

      expect(
        error.definition,
        PocketErrorCatalog.connectionHistoryHostKeyUnpinned,
      );
      expect(error.title, 'Host key not pinned');
      expect(error.bodyWithCode, contains('7a:9f:d7:dc:2e:f2'));
    },
  );
}

ConnectionProfile _remoteProfile() {
  return const ConnectionProfile(
    label: 'Developer Box',
    host: 'example.com',
    port: 22,
    username: 'vince',
    workspaceDir: '/workspace',
    codexPath: 'codex',
    authMode: AuthMode.password,
    hostFingerprint: '',
    dangerouslyBypassSandbox: false,
    ephemeralSession: false,
  );
}
