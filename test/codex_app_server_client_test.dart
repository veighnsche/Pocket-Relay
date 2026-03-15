import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
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

  test(
    'connect preserves the final stderr line when startup exits immediately',
    () async {
      late _FakeCodexAppServerProcess process;
      process = _FakeCodexAppServerProcess(
        exitCodeValue: 127,
        onClientMessage: (message) {
          if (message['method'] == 'initialize') {
            process.sendStderr(
              'Codex CLI not found on PATH',
              includeTrailingNewline: false,
            );
            unawaited(process.close());
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

      await expectLater(
        client.connect(
          profile: _profile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
        throwsA(
          isA<CodexAppServerException>().having(
            (error) => error.message,
            'message',
            contains('disconnected'),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        events.whereType<CodexAppServerDiagnosticEvent>().map((e) => e.message),
        contains('Codex CLI not found on PATH'),
      );

      await subscription.cancel();
      await client.disconnect();
    },
  );

  test('dispose closes the event stream and rejects reuse', () async {
    final client = CodexAppServerClient(
      processLauncher:
          ({required profile, required secrets, required emitEvent}) async =>
              _FakeCodexAppServerProcess(),
    );
    var didCloseEvents = false;
    final subscription = client.events.listen(
      (_) {},
      onDone: () {
        didCloseEvents = true;
      },
    );

    await client.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(didCloseEvents, isTrue);
    await expectLater(
      client.connect(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      ),
      throwsA(
        isA<CodexAppServerException>().having(
          (error) => error.message,
          'message',
          contains('disposed'),
        ),
      ),
    );

    await subscription.cancel();
  });

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
                'approvalPolicy': 'onRequest',
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
      'approvalPolicy': 'onRequest',
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

  test(
    'startSession uses thread/resume params without ephemeral field',
    () async {
      late _FakeCodexAppServerProcess process;
      process = _FakeCodexAppServerProcess(
        onClientMessage: (message) {
          switch (message['method']) {
            case 'initialize':
              process.sendStdout(<String, Object?>{
                'id': message['id'],
                'result': <String, Object?>{
                  'userAgent': 'codex-app-server-test',
                },
              });
            case 'thread/resume':
              process.sendStdout(<String, Object?>{
                'id': message['id'],
                'result': <String, Object?>{
                  'thread': <String, Object?>{'id': 'thread_resumed'},
                  'cwd': '/workspace',
                  'model': 'gpt-5.3-codex',
                  'modelProvider': 'openai',
                  'approvalPolicy': 'onRequest',
                  'sandbox': <String, Object?>{'type': 'workspace-write'},
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

      await client.startSession(resumeThreadId: 'thread_old');

      final resumeRequest = process.writtenMessages.firstWhere(
        (message) => message['method'] == 'thread/resume',
      );
      expect(resumeRequest['params'], <String, Object?>{
        'cwd': '/workspace',
        'approvalPolicy': 'onRequest',
        'sandbox': 'workspace-write',
        'threadId': 'thread_old',
      });

      await client.disconnect();
    },
  );

  test(
    'startSession falls back to thread/start when thread/resume cannot find the thread',
    () async {
      late _FakeCodexAppServerProcess process;
      process = _FakeCodexAppServerProcess(
        onClientMessage: (message) {
          switch (message['method']) {
            case 'initialize':
              process.sendStdout(<String, Object?>{
                'id': message['id'],
                'result': <String, Object?>{
                  'userAgent': 'codex-app-server-test',
                },
              });
            case 'thread/resume':
              process.sendStdout(<String, Object?>{
                'id': message['id'],
                'error': <String, Object?>{
                  'code': -32000,
                  'message': 'thread/resume failed: thread not found',
                },
              });
            case 'thread/start':
              process.sendStdout(<String, Object?>{
                'id': message['id'],
                'result': <String, Object?>{
                  'thread': <String, Object?>{'id': 'thread_fresh'},
                  'cwd': '/workspace',
                  'model': 'gpt-5.3-codex',
                  'modelProvider': 'openai',
                  'approvalPolicy': 'onRequest',
                  'sandbox': <String, Object?>{'type': 'workspace-write'},
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

      final session = await client.startSession(resumeThreadId: 'thread_old');

      expect(session.threadId, 'thread_fresh');
      expect(
        process.writtenMessages
            .where((message) => message['method'] == 'thread/resume')
            .length,
        1,
      );
      expect(
        process.writtenMessages
            .where((message) => message['method'] == 'thread/start')
            .length,
        1,
      );

      await client.disconnect();
    },
  );

  test('ephemeral sessions ignore resume thread ids and start fresh', () async {
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
                'thread': <String, Object?>{'id': 'thread_new'},
                'cwd': '/workspace',
                'model': 'gpt-5.3-codex',
                'modelProvider': 'openai',
                'approvalPolicy': 'onRequest',
                'sandbox': <String, Object?>{'type': 'workspace-write'},
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
      profile: _profile(ephemeralSession: true),
      secrets: const ConnectionSecrets(password: 'secret'),
    );

    await client.startSession(resumeThreadId: 'thread_old');

    final startRequest = process.writtenMessages.firstWhere(
      (message) => message['method'] == 'thread/start',
    );
    expect(startRequest['params'], <String, Object?>{
      'cwd': '/workspace',
      'approvalPolicy': 'onRequest',
      'sandbox': 'workspace-write',
      'ephemeral': true,
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

  test(
    'permissions approval requests can be resolved through the client API',
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

      await client.connect(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      );

      process.sendStdout(<String, Object?>{
        'id': 'perm-1',
        'method': 'item/permissions/requestApproval',
        'params': <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'itemId': 'item_123',
          'permissions': <String, Object?>{
            'network': <String, Object?>{'enabled': true},
            'fileSystem': <String, Object?>{
              'write': <String>['/tmp/project'],
            },
            'macos': null,
          },
        },
      });
      await Future<void>.delayed(Duration.zero);

      await client.resolveApproval(requestId: 's:perm-1', approved: true);

      expect(process.writtenMessages.last, <String, Object?>{
        'id': 'perm-1',
        'result': <String, Object?>{
          'permissions': <String, Object?>{
            'network': <String, Object?>{'enabled': true},
            'fileSystem': <String, Object?>{
              'write': <String>['/tmp/project'],
            },
          },
          'scope': 'turn',
        },
      });

      await client.disconnect();
    },
  );

  test('dynamic tool requests can be answered with tool output', () async {
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

    await client.connect(
      profile: _profile(),
      secrets: const ConnectionSecrets(password: 'secret'),
    );

    process.sendStdout(<String, Object?>{
      'id': 'tool-1',
      'method': 'item/tool/call',
      'params': <String, Object?>{
        'threadId': 'thread_123',
        'turnId': 'turn_123',
        'callId': 'call_123',
        'tool': 'preview-image',
        'arguments': <String, Object?>{'path': '/tmp/image.png'},
      },
    });
    await Future<void>.delayed(Duration.zero);

    await client.respondDynamicToolCall(
      requestId: 's:tool-1',
      success: false,
      contentItems: const <Map<String, Object?>>[
        <String, Object?>{
          'type': 'inputText',
          'text': 'Dynamic tool calls are not supported.',
        },
      ],
    );

    expect(process.writtenMessages.last, <String, Object?>{
      'id': 'tool-1',
      'result': <String, Object?>{
        'contentItems': <Object>[
          <String, Object?>{
            'type': 'inputText',
            'text': 'Dynamic tool calls are not supported.',
          },
        ],
        'success': false,
      },
    });

    await client.disconnect();
  });

  test('auth token refresh requests can be answered or rejected', () async {
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

    await client.connect(
      profile: _profile(),
      secrets: const ConnectionSecrets(password: 'secret'),
    );

    process.sendStdout(<String, Object?>{
      'id': 'auth-1',
      'method': 'account/chatgptAuthTokens/refresh',
      'params': <String, Object?>{
        'reason': 'unauthorized',
        'previousAccountId': 'org-123',
      },
    });
    await Future<void>.delayed(Duration.zero);

    await client.respondAuthTokensRefresh(
      requestId: 's:auth-1',
      accessToken: 'access-token',
      chatgptAccountId: 'org-456',
      chatgptPlanType: 'plus',
    );

    expect(process.writtenMessages.last, <String, Object?>{
      'id': 'auth-1',
      'result': <String, Object?>{
        'accessToken': 'access-token',
        'chatgptAccountId': 'org-456',
        'chatgptPlanType': 'plus',
      },
    });

    process.sendStdout(<String, Object?>{
      'id': 'legacy-read-1',
      'method': 'item/fileRead/requestApproval',
      'params': <String, Object?>{'reason': 'Read file'},
    });
    await Future<void>.delayed(Duration.zero);

    await client.rejectServerRequest(
      requestId: 's:legacy-read-1',
      message: 'Unsupported request.',
      code: -32601,
    );

    expect(process.writtenMessages.last, <String, Object?>{
      'id': 'legacy-read-1',
      'error': <String, Object?>{
        'code': -32601,
        'message': 'Unsupported request.',
      },
    });

    await client.disconnect();
  });

  test(
    'session exit notifications clear tracked thread and turn ids',
    () async {
      late _FakeCodexAppServerProcess process;
      process = _FakeCodexAppServerProcess(
        onClientMessage: (message) {
          switch (message['method']) {
            case 'initialize':
              process.sendStdout(<String, Object?>{
                'id': message['id'],
                'result': <String, Object?>{
                  'userAgent': 'codex-app-server-test',
                },
              });
            case 'thread/start':
              process.sendStdout(<String, Object?>{
                'id': message['id'],
                'result': <String, Object?>{
                  'thread': <String, Object?>{'id': 'thread_123'},
                  'cwd': '/workspace',
                  'model': 'gpt-5.3-codex',
                  'modelProvider': 'openai',
                  'approvalPolicy': 'onRequest',
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
      await client.sendUserMessage(
        threadId: session.threadId,
        text: 'hello from phone',
      );

      expect(client.threadId, 'thread_123');
      expect(client.activeTurnId, 'turn_123');

      process.sendStdout(<String, Object?>{
        'method': 'session/exited',
        'params': <String, Object?>{'exitCode': 0},
      });
      await Future<void>.delayed(Duration.zero);

      expect(client.threadId, isNull);
      expect(client.activeTurnId, isNull);

      await client.disconnect();
    },
  );

  test('starting a new session clears the active turn pointer', () async {
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
                'approvalPolicy': 'onRequest',
                'sandbox': <String, Object?>{'type': 'workspace-write'},
              },
            });
          case 'thread/resume':
            process.sendStdout(<String, Object?>{
              'id': message['id'],
              'result': <String, Object?>{
                'thread': <String, Object?>{'id': 'thread_456'},
                'cwd': '/workspace',
                'model': 'gpt-5.3-codex',
                'modelProvider': 'openai',
                'approvalPolicy': 'onRequest',
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
    await client.sendUserMessage(threadId: session.threadId, text: 'hello');
    expect(client.activeTurnId, 'turn_123');

    final resumed = await client.startSession(resumeThreadId: 'thread_456');

    expect(resumed.threadId, 'thread_456');
    expect(client.threadId, 'thread_456');
    expect(client.activeTurnId, isNull);

    await client.disconnect();
  });

  test(
    'notification pointer updates ignore stale turn completions and clear closed threads',
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

      await client.connect(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      );

      process.sendStdout(<String, Object?>{
        'method': 'thread/started',
        'params': <String, Object?>{
          'thread': <String, Object?>{'id': 'thread_123'},
        },
      });
      process.sendStdout(<String, Object?>{
        'method': 'turn/started',
        'params': <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{'id': 'turn_old'},
        },
      });
      process.sendStdout(<String, Object?>{
        'method': 'turn/started',
        'params': <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{'id': 'turn_new'},
        },
      });
      await Future<void>.delayed(Duration.zero);

      expect(client.threadId, 'thread_123');
      expect(client.activeTurnId, 'turn_new');

      process.sendStdout(<String, Object?>{
        'method': 'turn/completed',
        'params': <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{'id': 'turn_old'},
        },
      });
      await Future<void>.delayed(Duration.zero);

      expect(client.activeTurnId, 'turn_new');

      process.sendStdout(<String, Object?>{
        'method': 'thread/closed',
        'params': <String, Object?>{'threadId': 'thread_123'},
      });
      await Future<void>.delayed(Duration.zero);

      expect(client.threadId, isNull);
      expect(client.activeTurnId, isNull);

      await client.disconnect();
    },
  );

  test(
    'mcp elicitation requests can be resolved through the client API',
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

      await client.connect(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      );

      process.sendStdout(<String, Object?>{
        'id': 'elicitation-1',
        'method': 'mcpServer/elicitation/request',
        'params': <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'serverName': 'filesystem',
          'message': 'Choose a directory',
          'mode': 'form',
          'requestedSchema': <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{
              'path': <String, Object?>{'type': 'string'},
            },
          },
        },
      });
      await Future<void>.delayed(Duration.zero);

      await client.respondToElicitation(
        requestId: 's:elicitation-1',
        action: CodexAppServerElicitationAction.accept,
        content: <String, Object?>{'path': '/workspace'},
      );

      expect(process.writtenMessages.last, <String, Object?>{
        'id': 'elicitation-1',
        'result': <String, Object?>{
          'action': 'accept',
          'content': <String, Object?>{'path': '/workspace'},
        },
      });

      await client.disconnect();
    },
  );
}

ConnectionProfile _profile({bool ephemeralSession = false}) {
  return ConnectionProfile(
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
    ephemeralSession: ephemeralSession,
  );
}

class _FakeCodexAppServerProcess implements CodexAppServerProcess {
  _FakeCodexAppServerProcess({this.onClientMessage, this.exitCodeValue = 0}) {
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
  final int? exitCodeValue;
  final List<Map<String, dynamic>> writtenMessages = <Map<String, dynamic>>[];

  final _stdinController = StreamController<Uint8List>();
  final _stdoutController = StreamController<Uint8List>.broadcast();
  final _stderrController = StreamController<Uint8List>.broadcast();
  final _doneCompleter = Completer<void>();
  bool _isClosed = false;

  @override
  Stream<Uint8List> get stdout => _stdoutController.stream;

  @override
  Stream<Uint8List> get stderr => _stderrController.stream;

  @override
  StreamSink<Uint8List> get stdin => _stdinController.sink;

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  int? get exitCode => exitCodeValue;

  void sendStdout(Map<String, Object?> payload) {
    final line = '${jsonEncode(payload)}\n';
    _stdoutController.add(Uint8List.fromList(utf8.encode(line)));
  }

  void sendStderr(String text, {bool includeTrailingNewline = true}) {
    final output = includeTrailingNewline ? '$text\n' : text;
    _stderrController.add(Uint8List.fromList(utf8.encode(output)));
  }

  @override
  Future<void> close() async {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
    await _stdinController.close();
    await _stdoutController.close();
    await _stderrController.close();
  }
}
