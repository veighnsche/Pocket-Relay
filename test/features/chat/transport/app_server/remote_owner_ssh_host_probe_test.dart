import 'remote_owner_ssh_test_support.dart';

void main() {
  test(
    'probeHostCapabilities returns supported when tmux and codex are available',
    () async {
      final process = FakeCodexAppServerProcess(
        stdoutLines: <String>[
          '__pocket_relay_capabilities__ tmux=0 workspace=0 codex=0',
        ],
      );
      final probe = CodexSshRemoteAppServerHostProbe(
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return FakeSshBootstrapClient(process: process);
            },
      );

      final capabilities = await probe.probeHostCapabilities(
        profile: sshProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      );

      expect(capabilities.supportsContinuity, isTrue);
      expect(capabilities.issues, isEmpty);
    },
  );

  test(
    'probeHostCapabilities reports explicit missing tmux and codex issues',
    () async {
      final process = FakeCodexAppServerProcess(
        stdoutLines: <String>[
          '__pocket_relay_capabilities__ tmux=1 workspace=0 codex=1',
        ],
      );
      final probe = CodexSshRemoteAppServerHostProbe(
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return FakeSshBootstrapClient(process: process);
            },
      );

      final capabilities = await probe.probeHostCapabilities(
        profile: sshProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      );

      expect(capabilities.issues, <ConnectionRemoteHostCapabilityIssue>{
        ConnectionRemoteHostCapabilityIssue.tmuxMissing,
        ConnectionRemoteHostCapabilityIssue.agentCommandMissing,
      });
    },
  );

  test(
    'probeHostCapabilities reports an unavailable workspace separately from codex availability',
    () async {
      final process = FakeCodexAppServerProcess(
        stdoutLines: <String>[
          '__pocket_relay_capabilities__ tmux=0 workspace=1 codex=1',
        ],
      );
      final probe = CodexSshRemoteAppServerHostProbe(
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return FakeSshBootstrapClient(process: process);
            },
      );

      final capabilities = await probe.probeHostCapabilities(
        profile: sshProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      );

      expect(capabilities.supportsContinuity, isFalse);
      expect(capabilities.issues, <ConnectionRemoteHostCapabilityIssue>{
        ConnectionRemoteHostCapabilityIssue.workspaceUnavailable,
        ConnectionRemoteHostCapabilityIssue.agentCommandMissing,
      });
    },
  );

  test(
    'probeHostCapabilities throws when the remote output is not parseable',
    () async {
      final process = FakeCodexAppServerProcess(
        stdoutLines: <String>['unexpected output'],
        stderrLines: <String>['stderr detail'],
        exitCodeValue: 7,
      );
      final probe = CodexSshRemoteAppServerHostProbe(
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return FakeSshBootstrapClient(process: process);
            },
      );

      await expectLater(
        probe.probeHostCapabilities(
          profile: sshProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('no parseable result'),
          ),
        ),
      );
    },
  );
}
