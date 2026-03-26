import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_ssh_forward.dart';

void main() {
  test(
    'ssh-forwarded websocket transport reaches an existing websocket server',
    () async {
      final receivedFrames = <String>[];
      final events = <CodexAppServerEvent>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      unawaited(
        server.transform(WebSocketTransformer()).listen((socket) {
          socket.listen((message) {
            receivedFrames.add(message as String);
            socket.add('{"jsonrpc":"2.0","method":"server/ping"}');
          });
        }).asFuture<void>(),
      );

      final bootstrapClient = _FakeSshBootstrapClient(
        onForwardLocal: (remoteHost, remotePort) async {
          final socket = await Socket.connect(remoteHost, remotePort);
          return _SocketBackedSshForwardChannel(socket);
        },
      );

      final transport = await openSshForwardedCodexAppServerWebSocketTransport(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        remoteHost: InternetAddress.loopbackIPv4.address,
        remotePort: server.port,
        emitEvent: events.add,
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async => bootstrapClient,
      );
      addTearDown(transport.close);

      transport.sendLine('{"jsonrpc":"2.0","method":"client/ping"}');

      expect(
        await transport.protocolMessages.first,
        '{"jsonrpc":"2.0","method":"server/ping"}',
      );
      expect(receivedFrames, <String>[
        '{"jsonrpc":"2.0","method":"client/ping"}',
      ]);
      expect(
        events.whereType<CodexAppServerSshAuthenticatedEvent>(),
        hasLength(1),
      );
      expect(
        events.whereType<CodexAppServerSshPortForwardStartedEvent>().single,
        isA<CodexAppServerSshPortForwardStartedEvent>().having(
          (event) => event.remotePort,
          'remotePort',
          server.port,
        ),
      );
      expect(bootstrapClient.forwardCalls, 1);
    },
  );

  test(
    'local SSH forward emits a distinct port-forward failure event',
    () async {
      final events = <CodexAppServerEvent>[];
      final bootstrapClient = _FakeSshBootstrapClient(
        onForwardLocal: (remoteHost, remotePort) async {
          throw StateError('forward failed');
        },
      );

      final forward = await openCodexSshLocalPortForward(
        profile: _profile(),
        client: bootstrapClient,
        remoteHost: '127.0.0.1',
        remotePort: 4100,
        emitEvent: events.add,
      );
      addTearDown(forward.close);

      final socket = await Socket.connect(
        forward.websocketUri.host,
        forward.websocketUri.port,
      );
      addTearDown(socket.close);

      await socket.done.timeout(
        const Duration(seconds: 1),
        onTimeout: () => socket.destroy(),
      );

      expect(
        events.whereType<CodexAppServerSshPortForwardStartedEvent>(),
        hasLength(1),
      );
      expect(
        events
            .whereType<CodexAppServerSshPortForwardFailedEvent>()
            .single
            .message,
        contains('forward failed'),
      );
      expect(bootstrapClient.forwardCalls, 1);
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

final class _FakeSshBootstrapClient implements CodexSshBootstrapClient {
  _FakeSshBootstrapClient({required this.onForwardLocal});

  final Future<CodexSshForwardChannel> Function(
    String remoteHost,
    int remotePort,
  )
  onForwardLocal;

  int forwardCalls = 0;
  int closeCalls = 0;

  @override
  Future<void> authenticate() async {}

  @override
  Future<CodexAppServerProcess> launchProcess(String command) {
    throw UnimplementedError('launchProcess is not used in ssh forward tests');
  }

  @override
  Future<CodexSshForwardChannel> forwardLocal(
    String remoteHost,
    int remotePort, {
    String localHost = 'localhost',
    int localPort = 0,
  }) async {
    forwardCalls += 1;
    return onForwardLocal(remoteHost, remotePort);
  }

  @override
  void close() {
    closeCalls += 1;
  }
}

final class _SocketBackedSshForwardChannel implements CodexSshForwardChannel {
  _SocketBackedSshForwardChannel(this._socket);

  final Socket _socket;

  @override
  Stream<Uint8List> get stream => _socket;

  @override
  StreamSink<List<int>> get sink => _socket;

  @override
  Future<void> get done => _socket.done;

  @override
  Future<void> close() => _socket.close();

  @override
  void destroy() {
    _socket.destroy();
  }
}
