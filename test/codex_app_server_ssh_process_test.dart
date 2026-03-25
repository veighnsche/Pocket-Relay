import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart';

void main() {
  test(
    'emits a typed connect-failed event when bootstrap connect fails',
    () async {
      final events = <CodexAppServerEvent>[];

      await expectLater(
        connectAuthenticatedSshBootstrapClient(
          profile: _profile(),
          secrets: const ConnectionSecrets(password: 'secret'),
          emitEvent: events.add,
          sshBootstrap:
              ({required profile, required secrets, required verifyHostKey}) {
                throw SSHSocketError('connection refused');
              },
        ),
        throwsA(isA<SSHSocketError>()),
      );

      expect(events.single, isA<CodexAppServerSshConnectFailedEvent>());
      final event = events.single as CodexAppServerSshConnectFailedEvent;
      expect(event.host, 'example.com');
      expect(event.port, 22);
      expect(event.message, 'connection refused');
    },
  );

  test(
    'emits a typed host-key mismatch event without a duplicate connect failure',
    () async {
      final events = <CodexAppServerEvent>[];

      await expectLater(
        connectAuthenticatedSshBootstrapClient(
          profile: _profile().copyWith(hostFingerprint: 'aa:bb:cc:dd'),
          secrets: const ConnectionSecrets(password: 'secret'),
          emitEvent: events.add,
          sshBootstrap:
              ({required profile, required secrets, required verifyHostKey}) {
                final accepted = verifyHostKey('ssh-ed25519', '11:22:33:44');
                expect(accepted, isFalse);
                throw SSHHostkeyError('Hostkey verification failed');
              },
        ),
        throwsA(isA<SSHHostkeyError>()),
      );

      expect(events, hasLength(1));
      expect(events.single, isA<CodexAppServerSshHostKeyMismatchEvent>());
      final event = events.single as CodexAppServerSshHostKeyMismatchEvent;
      expect(event.keyType, 'ssh-ed25519');
      expect(event.expectedFingerprint, 'aa:bb:cc:dd');
      expect(event.actualFingerprint, '11:22:33:44');
    },
  );

  test('emits a typed auth-failed event when authentication fails', () async {
    final events = <CodexAppServerEvent>[];
    final client = _FakeSshBootstrapClient(
      authenticateError: SSHAuthFailError('Permission denied'),
    );

    await expectLater(
      connectAuthenticatedSshBootstrapClient(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        emitEvent: events.add,
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return client;
            },
      ),
      throwsA(isA<SSHAuthFailError>()),
    );

    expect(events.single, isA<CodexAppServerSshAuthenticationFailedEvent>());
    final event = events.single as CodexAppServerSshAuthenticationFailedEvent;
    expect(event.username, 'vince');
    expect(event.authMode, AuthMode.password);
    expect(event.message, 'Permission denied');
    expect(client.closeCalls, 1);
  });

  test(
    'emits an unpinned-host-key event and rejects the connection',
    () async {
      final events = <CodexAppServerEvent>[];

      await expectLater(
        connectAuthenticatedSshBootstrapClient(
          profile: _profile(),
          secrets: const ConnectionSecrets(password: 'secret'),
          emitEvent: events.add,
          sshBootstrap:
              ({required profile, required secrets, required verifyHostKey}) {
                final accepted = verifyHostKey(
                  'ssh-ed25519',
                  '7a:9f:d7:dc:2e:f2',
                );
                expect(accepted, isFalse);
                throw SSHHostkeyError('Hostkey verification failed');
              },
        ),
        throwsA(isA<SSHHostkeyError>()),
      );

      expect(events, hasLength(1));
      expect(events.single, isA<CodexAppServerUnpinnedHostKeyEvent>());
      final event = events.single as CodexAppServerUnpinnedHostKeyEvent;
      expect(event.host, 'example.com');
      expect(event.port, 22);
      expect(event.keyType, 'ssh-ed25519');
      expect(event.fingerprint, '7a:9f:d7:dc:2e:f2');
    },
  );

  test('emits an authenticated event on success', () async {
    final events = <CodexAppServerEvent>[];
    final client = _FakeSshBootstrapClient();

    final authenticatedClient = await connectAuthenticatedSshBootstrapClient(
      profile: _profile().copyWith(hostFingerprint: '7a:9f:d7:dc:2e:f2'),
      secrets: const ConnectionSecrets(password: 'secret'),
      emitEvent: events.add,
      sshBootstrap:
          ({
            required profile,
            required secrets,
            required verifyHostKey,
          }) async {
            final accepted = verifyHostKey('ssh-ed25519', '7a:9f:d7:dc:2e:f2');
            expect(accepted, isTrue);
            return client;
          },
    );

    expect(authenticatedClient, same(client));
    expect(events, hasLength(1));
    expect(events.single, isA<CodexAppServerSshAuthenticatedEvent>());
  });
}

ConnectionProfile _profile() {
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

final class _FakeSshBootstrapClient implements CodexSshBootstrapClient {
  _FakeSshBootstrapClient({this.authenticateError});

  final Object? authenticateError;

  int closeCalls = 0;

  @override
  Future<void> authenticate() async {
    if (authenticateError != null) {
      throw authenticateError!;
    }
  }

  @override
  Future<CodexAppServerProcess> launchProcess(String command) {
    throw UnimplementedError('launchProcess is not used in these tests');
  }

  @override
  Future<CodexSshForwardChannel> forwardLocal(
    String remoteHost,
    int remotePort, {
    String localHost = 'localhost',
    int localPort = 0,
  }) {
    throw UnimplementedError('forwardLocal is not used in these tests');
  }

  @override
  void close() {
    closeCalls += 1;
  }
}
