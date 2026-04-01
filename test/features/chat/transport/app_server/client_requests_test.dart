import 'client_test_support.dart';

void main() {
  test('server requests can be answered from the client API', () async {
    late FakeCodexAppServerProcess process;
    process = FakeCodexAppServerProcess(
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
    final events = <AgentAdapterEvent>[];
    final subscription = client.events.listen(events.add);

    await client.connect(
      profile: clientProfile(),
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

    final request = events.whereType<AgentAdapterRequestEvent>().single;
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
      late FakeCodexAppServerProcess process;
      process = FakeCodexAppServerProcess(
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
        profile: clientProfile(),
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
    late FakeCodexAppServerProcess process;
    process = FakeCodexAppServerProcess(
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
      profile: clientProfile(),
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

  test('unsupported host requests can be rejected generically', () async {
    late FakeCodexAppServerProcess process;
    process = FakeCodexAppServerProcess(
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
      profile: clientProfile(),
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

    await client.rejectServerRequest(
      requestId: 's:auth-1',
      message: 'Unsupported request.',
      code: -32601,
    );

    expect(process.writtenMessages.last, <String, Object?>{
      'id': 'auth-1',
      'error': <String, Object?>{
        'code': -32601,
        'message': 'Unsupported request.',
      },
    });

    process.sendStdout(<String, Object?>{
      'id': 'tool-2',
      'method': 'item/tool/call',
      'params': <String, Object?>{'tool': 'experimental-host-tool'},
    });
    await Future<void>.delayed(Duration.zero);

    await client.rejectServerRequest(
      requestId: 's:tool-2',
      message: 'Unsupported request.',
      code: -32601,
    );

    expect(process.writtenMessages.last, <String, Object?>{
      'id': 'tool-2',
      'error': <String, Object?>{
        'code': -32601,
        'message': 'Unsupported request.',
      },
    });

    await client.disconnect();
  });

  test(
    'mcp elicitation requests can be resolved through the client API',
    () async {
      late FakeCodexAppServerProcess process;
      process = FakeCodexAppServerProcess(
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
        profile: clientProfile(),
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
        action: AgentAdapterElicitationAction.accept,
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
