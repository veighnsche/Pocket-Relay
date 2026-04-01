import 'client_test_support.dart';

void main() {
  test('startSession and sendUserMessage send the expected requests', () async {
    late FakeCodexAppServerProcess process;
    process = FakeCodexAppServerProcess(
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
      profile: clientProfile(),
      secrets: const ConnectionSecrets(password: 'secret'),
    );

    final session = await client.startSession(
      model: 'gpt-5.4',
      reasoningEffort: CodexReasoningEffort.high,
    );
    final turn = await client.sendUserMessage(
      threadId: session.threadId,
      text: 'hello from phone',
      model: 'gpt-5.4',
      effort: CodexReasoningEffort.low,
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
      'model': 'gpt-5.4',
      'reasoning_effort': 'high',
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
      'model': 'gpt-5.4',
      'effort': 'low',
    });

    await client.disconnect();
  });

  test('sendUserMessage supports structured local-image turn input', () async {
    late FakeCodexAppServerProcess process;
    process = FakeCodexAppServerProcess(
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
      profile: clientProfile(),
      secrets: const ConnectionSecrets(password: 'secret'),
    );

    final session = await client.startSession();
    await client.sendUserMessage(
      threadId: session.threadId,
      input: const AgentAdapterTurnInput(
        text: 'Check [Image #1]',
        textElements: <AgentAdapterTextElement>[
          AgentAdapterTextElement(start: 6, end: 16, placeholder: '[Image #1]'),
        ],
        images: <AgentAdapterImageInput>[
          AgentAdapterImageInput(url: 'data:image/png;base64,aW1hZ2U='),
        ],
      ),
    );

    final turnStartRequest = process.writtenMessages.firstWhere(
      (message) => message['method'] == 'turn/start',
    );

    expect(turnStartRequest['params'], <String, Object?>{
      'threadId': 'thread_123',
      'input': <Object>[
        <String, Object?>{
          'type': 'image',
          'image_url': 'data:image/png;base64,aW1hZ2U=',
        },
        <String, Object?>{
          'type': 'text',
          'text': 'Check [Image #1]',
          'text_elements': <Object>[
            <String, Object?>{
              'byteRange': <String, Object?>{'start': 6, 'end': 16},
              'placeholder': '[Image #1]',
            },
          ],
        },
      ],
    });

    await client.disconnect();
  });

  test(
    'startSession uses thread/resume params without ephemeral field',
    () async {
      late FakeCodexAppServerProcess process;
      process = FakeCodexAppServerProcess(
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
                  'thread': <String, Object?>{'id': 'thread_old'},
                  'cwd': '/workspace',
                  'model': 'gpt-5.3-codex',
                  'modelProvider': 'openai',
                  'approvalPolicy': 'on-request',
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
        profile: clientProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      );

      await client.startSession(resumeThreadId: 'thread_old');

      final resumeRequest = process.writtenMessages.firstWhere(
        (message) => message['method'] == 'thread/resume',
      );
      expect(resumeRequest['params'], <String, Object?>{
        'cwd': '/workspace',
        'approvalPolicy': 'on-request',
        'sandbox': 'workspace-write',
        'threadId': 'thread_old',
      });

      await client.disconnect();
    },
  );

  test(
    'startSession surfaces thread/resume mismatches instead of accepting a different thread id',
    () async {
      late FakeCodexAppServerProcess process;
      process = FakeCodexAppServerProcess(
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
                  'thread': <String, Object?>{'id': 'thread_other'},
                  'cwd': '/workspace',
                  'model': 'gpt-5.3-codex',
                  'modelProvider': 'openai',
                  'approvalPolicy': 'on-request',
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
        profile: clientProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      );

      await expectLater(
        client.startSession(resumeThreadId: 'thread_old'),
        throwsA(
          isA<CodexAppServerException>()
              .having(
                (error) => error.message,
                'message',
                'thread/resume returned a different thread id than requested.',
              )
              .having((error) => error.data, 'data', <String, Object?>{
                'expectedThreadId': 'thread_old',
                'actualThreadId': 'thread_other',
              }),
        ),
      );
      expect(client.threadId, isNull);

      await client.disconnect();
    },
  );

  test(
    'startSession surfaces thread/resume missing-thread failures without silently starting fresh',
    () async {
      late FakeCodexAppServerProcess process;
      process = FakeCodexAppServerProcess(
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

      await expectLater(
        client.startSession(resumeThreadId: 'thread_old'),
        throwsA(
          isA<CodexAppServerException>().having(
            (error) => error.message,
            'message',
            contains('thread/resume failed: thread not found'),
          ),
        ),
      );
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
        0,
      );

      await client.disconnect();
    },
  );

  test('ephemeral sessions ignore resume thread ids and start fresh', () async {
    late FakeCodexAppServerProcess process;
    process = FakeCodexAppServerProcess(
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
                'approvalPolicy': 'on-request',
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
      profile: clientProfile(ephemeralSession: true),
      secrets: const ConnectionSecrets(password: 'secret'),
    );

    await client.startSession(resumeThreadId: 'thread_old');

    final startRequest = process.writtenMessages.firstWhere(
      (message) => message['method'] == 'thread/start',
    );
    expect(startRequest['params'], <String, Object?>{
      'cwd': '/workspace',
      'approvalPolicy': 'on-request',
      'sandbox': 'workspace-write',
      'ephemeral': true,
    });

    await client.disconnect();
  });
}
