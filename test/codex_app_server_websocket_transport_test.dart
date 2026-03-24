import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_websocket_transport.dart';

void main() {
  test('websocket transport forwards text frames in both directions', () async {
    final receivedFrames = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    final serverDone = Completer<void>();
    unawaited(
      server.transform(WebSocketTransformer()).listen((socket) {
        socket.listen((message) {
          receivedFrames.add(message as String);
          socket.add('{"jsonrpc":"2.0","method":"server/ping"}');
        });
      }).asFuture<void>().whenComplete(serverDone.complete),
    );

    final transport = await openCodexAppServerWebSocketTransport(
      uri: Uri.parse('ws://127.0.0.1:${server.port}'),
    );
    addTearDown(() async {
      await transport.close();
      await serverDone.future.timeout(
        const Duration(seconds: 1),
        onTimeout: () {},
      );
    });

    transport.sendLine('{"jsonrpc":"2.0","method":"client/ping"}');

    expect(
      await transport.protocolMessages.first,
      '{"jsonrpc":"2.0","method":"server/ping"}',
    );
    expect(receivedFrames, <String>['{"jsonrpc":"2.0","method":"client/ping"}']);
  });

  test('websocket transport reports binary frames as diagnostics', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    unawaited(
      server.transform(WebSocketTransformer()).listen((socket) async {
        socket.add(Uint8List.fromList(<int>[1, 2, 3]));
        await socket.close();
      }).asFuture<void>(),
    );

    final transport = await openCodexAppServerWebSocketTransport(
      uri: Uri.parse('ws://127.0.0.1:${server.port}'),
    );
    addTearDown(transport.close);

    expect(
      await transport.diagnostics.first,
      'Unexpected non-text websocket frame from app-server.',
    );
  });

  test(
    'codex app-server client can initialize and start a session over websocket',
    () async {
      final requests = <Map<String, dynamic>>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      unawaited(
        server.transform(WebSocketTransformer()).listen((socket) {
          socket.listen((message) {
            final request = jsonDecode(message as String) as Map<String, dynamic>;
            requests.add(request);
            switch (request['method']) {
              case 'initialize':
                socket.add(
                  jsonEncode(<String, Object?>{
                    'id': request['id'],
                    'result': <String, Object?>{
                      'userAgent': 'codex-app-server-websocket-test',
                    },
                  }),
                );
              case 'thread/start':
                socket.add(
                  jsonEncode(<String, Object?>{
                    'id': request['id'],
                    'result': <String, Object?>{
                      'thread': <String, Object?>{'id': 'thread_ws'},
                      'cwd': '/workspace',
                      'model': 'gpt-5.3-codex',
                      'modelProvider': 'openai',
                      'approvalPolicy': 'on-request',
                      'sandbox': <String, Object?>{'type': 'workspace-write'},
                    },
                  }),
                );
            }
          });
        }).asFuture<void>(),
      );

      final client = CodexAppServerClient(
        transportOpener:
            ({required profile, required secrets, required emitEvent}) {
              return openCodexAppServerWebSocketTransport(
                uri: Uri.parse('ws://127.0.0.1:${server.port}'),
              );
            },
      );
      addTearDown(client.dispose);

      final events = <CodexAppServerEvent>[];
      final subscription = client.events.listen(events.add);
      addTearDown(subscription.cancel);

      await client.connect(
        profile: ConnectionProfile.defaults().copyWith(
          workspaceDir: '/workspace',
          codexPath: 'codex',
        ),
        secrets: const ConnectionSecrets(),
      );

      final session = await client.startSession();

      expect(session.threadId, 'thread_ws');
      expect(requests.map((request) => request['method']), containsAll(<Object?>[
        'initialize',
        'initialized',
        'thread/start',
      ]));
      expect(
        events.whereType<CodexAppServerConnectedEvent>().single.userAgent,
        'codex-app-server-websocket-test',
      );
    },
  );
}
