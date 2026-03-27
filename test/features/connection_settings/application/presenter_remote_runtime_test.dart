import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_presenter.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';

import 'presenter_test_support.dart';

void main() {
  const presenter = ConnectionSettingsPresenter();

  test('preserves remote runtime state for remote settings contracts', () {
    final initialProfile = configuredConnectionProfile();
    const initialSecrets = ConnectionSecrets(password: 'secret');
    final formState = ConnectionSettingsFormState.initial(
      profile: initialProfile,
      secrets: initialSecrets,
    );
    const remoteRuntime = ConnectionRemoteRuntimeState(
      hostCapability: ConnectionRemoteHostCapabilityState.unsupported(
        issues: <ConnectionRemoteHostCapabilityIssue>{
          ConnectionRemoteHostCapabilityIssue.tmuxMissing,
        },
      ),
      server: ConnectionRemoteServerState.notRunning(
        detail: 'No managed remote app-server is running.',
      ),
    );

    final contract = presenter.present(
      initialProfile: initialProfile,
      initialSecrets: initialSecrets,
      formState: formState,
      remoteRuntime: remoteRuntime,
    );

    expect(contract.remoteRuntime, remoteRuntime);
    expect(
      contract.remoteRuntime!.hostCapability.issues,
      <ConnectionRemoteHostCapabilityIssue>{
        ConnectionRemoteHostCapabilityIssue.tmuxMissing,
      },
    );
    expect(
      contract.remoteRuntime!.server.status,
      ConnectionRemoteServerStatus.notRunning,
    );
    expect(contract.remoteConnectionSection, isNotNull);
    expect(contract.remoteConnectionSection!.status, isNotNull);
    expect(
      contract.remoteConnectionSection!.status!.label,
      'System unsupported',
    );
  });

  test(
    'surfaces workspace availability failures inline in the remote system section',
    () {
      final initialProfile = configuredConnectionProfile();
      const initialSecrets = ConnectionSecrets(password: 'secret');
      final formState = ConnectionSettingsFormState.initial(
        profile: initialProfile,
        secrets: initialSecrets,
      );
      const remoteRuntime = ConnectionRemoteRuntimeState(
        hostCapability: ConnectionRemoteHostCapabilityState.unsupported(
          issues: <ConnectionRemoteHostCapabilityIssue>{
            ConnectionRemoteHostCapabilityIssue.workspaceUnavailable,
          },
          detail:
              'The configured workspace directory is not accessible on the remote host.',
        ),
        server: ConnectionRemoteServerState.unknown(),
      );

      final contract = presenter.present(
        initialProfile: initialProfile,
        initialSecrets: initialSecrets,
        formState: formState,
        remoteRuntime: remoteRuntime,
      );

      expect(contract.remoteConnectionSection, isNotNull);
      expect(contract.remoteConnectionSection!.status, isNotNull);
      expect(
        contract.remoteConnectionSection!.status!.label,
        'System unsupported',
      );
      expect(
        contract.remoteConnectionSection!.status!.detail,
        'The configured workspace directory is not accessible on the remote host.',
      );
    },
  );

  test(
    'surfaces managed server state inline when the remote system is saved and unchanged',
    () {
      final initialProfile = configuredConnectionProfile();
      const initialSecrets = ConnectionSecrets(password: 'secret');
      final formState = ConnectionSettingsFormState.initial(
        profile: initialProfile,
        secrets: initialSecrets,
      );
      const remoteRuntime = ConnectionRemoteRuntimeState(
        hostCapability: ConnectionRemoteHostCapabilityState.supported(),
        server: ConnectionRemoteServerState.notRunning(
          ownerId: 'conn_primary',
          sessionName: 'pocket-relay-conn_primary',
        ),
      );

      final contract = presenter.present(
        initialProfile: initialProfile,
        initialSecrets: initialSecrets,
        formState: formState,
        remoteRuntime: remoteRuntime,
      );

      expect(contract.remoteConnectionSection, isNotNull);
      expect(contract.remoteConnectionSection!.status, isNotNull);
      expect(
        contract.remoteConnectionSection!.status!.label,
        'Managed server stopped',
      );
    },
  );

  test('keeps runtime truth visible while the sheet has unsaved changes', () {
    final initialProfile = configuredConnectionProfile();
    const initialSecrets = ConnectionSecrets(password: 'secret');
    final formState =
        ConnectionSettingsFormState.initial(
          profile: initialProfile,
          secrets: initialSecrets,
        ).copyWith(
          draft: ConnectionSettingsDraft.fromConnection(
            profile: initialProfile,
            secrets: initialSecrets,
          ).copyWithField(ConnectionSettingsFieldId.host, 'new-host.local'),
        );
    const remoteRuntime = ConnectionRemoteRuntimeState(
      hostCapability: ConnectionRemoteHostCapabilityState.supported(),
      server: ConnectionRemoteServerState.running(
        ownerId: 'conn_primary',
        sessionName: 'pocket-relay-conn_primary',
        port: 4100,
      ),
    );

    final contract = presenter.present(
      initialProfile: initialProfile,
      initialSecrets: initialSecrets,
      formState: formState,
      remoteRuntime: remoteRuntime,
    );

    expect(contract.remoteConnectionSection, isNotNull);
    expect(contract.remoteConnectionSection!.status, isNotNull);
    expect(
      contract.remoteConnectionSection!.status!.label,
      'Managed server running',
    );
  });
}
