import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_connection_scoped_transport.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';

void main() {
  test(
    'connection-scoped transport uses the local launcher for local mode',
    () async {
      var localCalls = 0;
      var inspectCalls = 0;

      final opener = buildConnectionScopedCodexAppServerTransportOpener(
        ownerId: 'conn_primary',
        remoteOwnerInspector: _FakeRemoteOwnerInspector(
          onInspect:
              ({
                required profile,
                required secrets,
                required ownerId,
                required workspaceDir,
              }) async {
                inspectCalls += 1;
                throw StateError('remote inspector should not run');
              },
        ),
        localLauncher:
            ({required profile, required secrets, required emitEvent}) async {
              localCalls += 1;
              return _FakeProcess();
            },
      );

      final transport = await opener(
        profile: _profile().copyWith(connectionMode: ConnectionMode.local),
        secrets: const ConnectionSecrets(),
        emitEvent: (_) {},
      );

      expect(transport, isA<CodexAppServerTransport>());
      expect(localCalls, 1);
      expect(inspectCalls, 0);
    },
  );

  test(
    'connection-scoped transport uses the inspected websocket owner for remote mode',
    () async {
      var remoteTransportCalls = 0;
      final remoteTransport = _FakeTransport();

      final opener = buildConnectionScopedCodexAppServerTransportOpener(
        ownerId: 'conn_primary',
        remoteOwnerInspector: _FakeRemoteOwnerInspector(
          onInspect:
              ({
                required profile,
                required secrets,
                required ownerId,
                required workspaceDir,
              }) async {
                return const CodexRemoteAppServerOwnerSnapshot(
                  ownerId: 'conn_primary',
                  workspaceDir: '/workspace',
                  status: CodexRemoteAppServerOwnerStatus.running,
                  sessionName: 'pocket-relay-conn_primary',
                  endpoint: CodexRemoteAppServerEndpoint(
                    host: '127.0.0.1',
                    port: 4100,
                  ),
                );
              },
        ),
        remoteTransportOpener:
            ({
              required profile,
              required secrets,
              required remoteHost,
              required remotePort,
              required emitEvent,
            }) async {
              remoteTransportCalls += 1;
              expect(remoteHost, '127.0.0.1');
              expect(remotePort, 4100);
              return remoteTransport;
            },
      );

      final transport = await opener(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        emitEvent: (_) {},
      );

      expect(transport, same(remoteTransport));
      expect(remoteTransportCalls, 1);
    },
  );

  test(
    'connection-scoped transport throws when the remote owner is not running',
    () async {
      final opener = buildConnectionScopedCodexAppServerTransportOpener(
        ownerId: 'conn_primary',
        remoteOwnerInspector: _FakeRemoteOwnerInspector(
          onInspect:
              ({
                required profile,
                required secrets,
                required ownerId,
                required workspaceDir,
              }) async {
                return const CodexRemoteAppServerOwnerSnapshot(
                  ownerId: 'conn_primary',
                  workspaceDir: '/workspace',
                  status: CodexRemoteAppServerOwnerStatus.missing,
                  sessionName: 'pocket-relay-conn_primary',
                );
              },
        ),
      );

      await expectLater(
        opener(
          profile: _profile(),
          secrets: const ConnectionSecrets(),
          emitEvent: (_) {},
        ),
        throwsA(
          isA<CodexRemoteAppServerAttachException>().having(
            (error) => error.snapshot.status,
            'snapshot.status',
            CodexRemoteAppServerOwnerStatus.missing,
          ),
        ),
      );
    },
  );

  test(
    'connection-scoped transport throws when the remote owner is unhealthy',
    () async {
      final opener = buildConnectionScopedCodexAppServerTransportOpener(
        ownerId: 'conn_primary',
        remoteOwnerInspector: _FakeRemoteOwnerInspector(
          onInspect:
              ({
                required profile,
                required secrets,
                required ownerId,
                required workspaceDir,
              }) async {
                return const CodexRemoteAppServerOwnerSnapshot(
                  ownerId: 'conn_primary',
                  workspaceDir: '/workspace',
                  status: CodexRemoteAppServerOwnerStatus.unhealthy,
                  sessionName: 'pocket-relay-conn_primary',
                  endpoint: CodexRemoteAppServerEndpoint(
                    host: '127.0.0.1',
                    port: 4100,
                  ),
                  detail: 'readyz failed',
                );
              },
        ),
      );

      await expectLater(
        opener(
          profile: _profile(),
          secrets: const ConnectionSecrets(),
          emitEvent: (_) {},
        ),
        throwsA(
          isA<CodexRemoteAppServerAttachException>()
              .having(
                (error) => error.snapshot.status,
                'snapshot.status',
                CodexRemoteAppServerOwnerStatus.unhealthy,
              )
              .having(
                (error) => error.message,
                'message',
                contains('readyz failed'),
              ),
        ),
      );
    },
  );
}

ConnectionProfile _profile() {
  return ConnectionProfile.defaults().copyWith(
    host: 'example.com',
    username: 'vince',
    workspaceDir: '/workspace',
    codexPath: 'codex',
  );
}

final class _FakeRemoteOwnerInspector
    implements CodexRemoteAppServerOwnerInspector {
  _FakeRemoteOwnerInspector({required this.onInspect});

  final Future<CodexRemoteAppServerOwnerSnapshot> Function({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  })
  onInspect;

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) {
    return onInspect(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    );
  }
}

final class _FakeTransport implements CodexAppServerTransport {
  final _protocolController = StreamController<String>.broadcast();
  final _diagnosticsController = StreamController<String>.broadcast();

  @override
  Stream<String> get protocolMessages => _protocolController.stream;

  @override
  Stream<String> get diagnostics => _diagnosticsController.stream;

  @override
  void sendLine(String line) {
    _protocolController.add(line);
  }

  @override
  Future<void> get done => Future<void>.value();

  @override
  CodexAppServerTransportTermination? get termination => null;

  @override
  Future<void> close() async {
    await _protocolController.close();
    await _diagnosticsController.close();
  }
}

final class _FakeProcess implements CodexAppServerProcess {
  final _stdinController = StreamController<Uint8List>();

  @override
  Stream<Uint8List> get stdout => const Stream<Uint8List>.empty();

  @override
  Stream<Uint8List> get stderr => const Stream<Uint8List>.empty();

  @override
  StreamSink<Uint8List> get stdin => _stdinController.sink;

  @override
  Future<void> get done => Future<void>.value();

  @override
  int? get exitCode => 0;

  @override
  Future<void> close() async {
    await _stdinController.close();
  }
}
