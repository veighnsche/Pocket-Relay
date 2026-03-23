import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';

void main() {
  test(
    'stores remote runtime separately from reconnect and recovery state',
    () {
      final state = ConnectionWorkspaceState.initial().copyWith(
        remoteRuntimeByConnectionId:
            const <String, ConnectionRemoteRuntimeState>{
              'remote-1': ConnectionRemoteRuntimeState(
                hostCapability: ConnectionRemoteHostCapabilityState.supported(),
                server: ConnectionRemoteServerState.unhealthy(
                  sessionName: 'pocket-relay:remote-1',
                  port: 4100,
                  detail: 'healthz probe failed',
                ),
              ),
            },
      );

      expect(
        state.remoteRuntimeFor('remote-1'),
        const ConnectionRemoteRuntimeState(
          hostCapability: ConnectionRemoteHostCapabilityState.supported(),
          server: ConnectionRemoteServerState.unhealthy(
            sessionName: 'pocket-relay:remote-1',
            port: 4100,
            detail: 'healthz probe failed',
          ),
        ),
      );
      expect(state.reconnectRequiredConnectionIds, isEmpty);
    },
  );

  test('keeps host capability distinct from server runtime status', () {
    const runtime = ConnectionRemoteRuntimeState(
      hostCapability: ConnectionRemoteHostCapabilityState.unsupported(
        issues: <ConnectionRemoteHostCapabilityIssue>{
          ConnectionRemoteHostCapabilityIssue.tmuxMissing,
        },
        detail: 'tmux is not installed on the host.',
      ),
      server: ConnectionRemoteServerState.notRunning(
        detail: 'No managed server was found.',
      ),
    );

    expect(runtime.hostCapability.isUnsupported, isTrue);
    expect(runtime.server.status, ConnectionRemoteServerStatus.notRunning);
    expect(runtime.server.isConnectable, isFalse);
  });
}
