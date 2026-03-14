import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/services/codex_app_server_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'connect performs initialize handshake and emits connected event',
    () async {
      late _FakeCodexAppServerProcess process;
      process = _FakeCodexAppServerProcess(
        onClientMessage: (message) {
          if (message['method'] == 'initialize') {
            process.sendStdout(<String, Object?>{
              'id': message['id'],
              'result': <String, Object?>{'userAgent': 'codex-app-server-test'},
            });
          }
        },
      );

      final client = CodexAppServerClient(
        processLauncher:
            ({required profile, required secrets, required emitEvent}) async =>
                process,
      );
      final events = <CodexAppServerEvent>[];
      final subscription = client.events.listen(events.add);

      await client.connect(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(process.writtenMessages, hasLength(2));
      expect(process.writtenMessages[0]['method'], 'initialize');
      expect(process.writtenMessages[1], <String, Object?>{
        'method': 'initialized',
      });

      final connected = events.whereType<CodexAppServerConnectedEvent>().single;
      expect(connected.userAgent, 'codex-app-server-test');

      await subscription.cancel();
      await client.disconnect();
    },
  );

  test('startSession and sendUserMessage send the expected requests', () async {
    late _FakeCodexAppServerProcess process;
    process = _FakeCodexAppServerProcess(
      onClientMessage: (message) {
        switch (message['method']) {
          case 'initialize':
            process.sendStdout(<String, Object?>{
              'id': message['id'],
              'result': <String, Object?>{'userAgent': 'codex-app-server-test'},
            });
          case 'thread/start':
            process.sendStdout(<String, Object?>{
              'id': message['id'],
              'result': <String, Object?>{
                'thread': <String, Object?>{'id': 'thread_123'},
                'cwd': '/workspace',
                'model': 'gpt-5.3-codex',
                'modelProvider': 'openai',
                'approvalPolicy': 'on-request',
                'sandbox': <String, Object?>{'type': 'workspace-write'},
              },
            });
          case 'turn/start':
            process.sendStdout(<String, Object?>{
              'id': message['id'],
              'result': <String, Object?>{
                'turn': <String, Object?>{'id': 'turn_123'},
              },
            });
        }
      },
    );

    final client = CodexAppServerClient(
      processLauncher:
          ({required profile, required secrets, required emitEvent}) async =>
              process,
    );

    await client.connect(
      profile: _profile(),
      secrets: const ConnectionSecrets(password: 'secret'),
    );

    final session = await client.startSession();
    final turn = await client.sendUserMessage(
      threadId: session.threadId,
      text: 'hello from phone',
    );

    expect(session.threadId, 'thread_123');
    expect(session.cwd, '/workspace');
    expect(turn.turnId, 'turn_123');
    expect(client.threadId, 'thread_123');
    expect(client.activeTurnId, 'turn_123');

    final threadStartRequest = process.writtenMessages.firstWhere(
      (message) => message['method'] == 'thread/start',
    );
    final turnStartRequest = process.writtenMessages.firstWhere(
      (message) => message['method'] == 'turn/start',
    );

    expect(threadStartRequest['params'], <String, Object?>{
      'cwd': '/workspace',
      'approvalPolicy': 'on-request',
      'sandbox': 'workspace-write',
      'ephemeral': false,
    });
    expect(turnStartRequest['params'], <String, Object?>{
      'threadId': 'thread_123',
      'input': <Object>[
        <String, Object?>{
          'type': 'text',
          'text': 'hello from phone',
          'text_elements': <Object>[],
        },
      ],
    });

    await client.disconnect();
  });

  test('server requests can be answered from the client API', () async {
    late _FakeCodexAppServerProcess process;
    process = _FakeCodexAppServerProcess(
      onClientMessage: (message) {
        if (message['method'] == 'initialize') {
          process.sendStdout(<String, Object?>{
            'id': message['id'],
            'result': <String, Object?>{'userAgent': 'codex-app-server-test'},
          });
        }
      },
    );

    final client = CodexAppServerClient(
      processLauncher:
          ({required profile, required secrets, required emitEvent}) async =>
              process,
    );
    final events = <CodexAppServerEvent>[];
    final subscription = client.events.listen(events.add);

    await client.connect(
      profile: _profile(),
      secrets: const ConnectionSecrets(password: 'secret'),
    );

    process.sendStdout(<String, Object?>{
      'id': 99,
      'method': 'item/tool/requestUserInput',
      'params': <String, Object?>{
        'questions': <Object>[
          <String, Object?>{'id': 'q1', 'prompt': 'Name?'},
        ],
      },
    });
    await Future<void>.delayed(Duration.zero);

    final request = events.whereType<CodexAppServerRequestEvent>().single;
    expect(request.requestId, 'i:99');
    expect(request.method, 'item/tool/requestUserInput');

    await client.answerUserInput(
      requestId: 'i:99',
      answers: const <String, List<String>>{
        'q1': <String>['vince'],
      },
    );

    process.sendStdout(<String, Object?>{
      'id': 'approval-1',
      'method': 'item/fileChange/requestApproval',
      'params': <String, Object?>{'reason': 'Write files'},
    });
    await Future<void>.delayed(Duration.zero);

    await client.resolveApproval(requestId: 's:approval-1', approved: true);

    expect(process.writtenMessages[2], <String, Object?>{
      'id': 99,
      'result': <String, Object?>{
        'answers': <String, Object?>{
          'q1': <String, Object?>{
            'answers': <String>['vince'],
          },
        },
      },
    });
    expect(process.writtenMessages[3], <String, Object?>{
      'id': 'approval-1',
      'result': <String, Object?>{'decision': 'accept'},
    });

    await subscription.cancel();
    await client.disconnect();
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
    skipGitRepoCheck: true,
    dangerouslyBypassSandbox: false,
    ephemeralSession: false,
  );
}

class _FakeCodexAppServerProcess implements CodexAppServerProcess {
  _FakeCodexAppServerProcess({this.onClientMessage}) {
    _stdinController.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final decoded = jsonDecode(line) as Map<String, dynamic>;
          writtenMessages.add(decoded);
          onClientMessage?.call(decoded);
        });
  }

  final void Function(Map<String, dynamic> message)? onClientMessage;
  final List<Map<String, dynamic>> writtenMessages = <Map<String, dynamic>>[];

  final _stdinController = StreamController<Uint8List>();
  final _stdoutController = StreamController<Uint8List>.broadcast();
  final _stderrController = StreamController<Uint8List>.broadcast();
  final _doneCompleter = Completer<void>();

  @override
  Stream<Uint8List> get stdout => _stdoutController.stream;

  @override
  Stream<Uint8List> get stderr => _stderrController.stream;

  @override
  StreamSink<Uint8List> get stdin => _stdinController.sink;

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  int? get exitCode => 0;

  void sendStdout(Map<String, Object?> payload) {
    final line = '${jsonEncode(payload)}\n';
    _stdoutController.add(Uint8List.fromList(utf8.encode(line)));
  }

  @override
  Future<void> close() async {
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
    await _stdinController.close();
    await _stdoutController.close();
    await _stderrController.close();
  }
}
