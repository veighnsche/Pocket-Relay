import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/app.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_history_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';

import 'support/fake_codex_app_server_client.dart';

void main() {
  testWidgets('sends prompts through app-server and renders assistant output', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient()
      ..startSessionCwd = '/Users/vince/Projects/Pocket-Relay'
      ..startSessionModel = 'gpt-5.4';
    addTearDown(appServerClient.close);

    await tester.pumpWidget(_buildCatalogApp(appServerClient: appServerClient));

    await _pumpAppReady(tester);

    final composerField = find.byKey(const ValueKey('composer_input'));
    await tester.enterText(composerField, 'Hello Codex');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pumpAndSettle();

    expect(appServerClient.connectCalls, 1);
    expect(appServerClient.startSessionCalls, 1);
    expect(appServerClient.sentMessages, <String>['Hello Codex']);
    expect(find.text('Hello Codex'), findsOneWidget);
    expect(tester.widget<TextField>(composerField).controller?.text, isEmpty);
    expect(find.text('Pocket-Relay'), findsOneWidget);
    expect(find.text('gpt-5.4'), findsOneWidget);

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'turn/started',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{
            'id': 'turn_1',
            'status': 'running',
            'model': 'gpt-5.4',
            'effort': 'high',
          },
        },
      ),
    );
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/started',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'item': <String, Object?>{
            'id': 'item_1',
            'type': 'agentMessage',
            'status': 'inProgress',
          },
        },
      ),
    );
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/agentMessage/delta',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'itemId': 'item_1',
          'delta': 'Hi from Codex',
        },
      ),
    );
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/completed',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'item': <String, Object?>{
            'id': 'item_1',
            'type': 'agentMessage',
            'status': 'completed',
            'text': 'Hi from Codex',
          },
        },
      ),
    );
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'turn/completed',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{
            'id': 'turn_1',
            'status': 'completed',
            'usage': <String, Object?>{'inputTokens': 12, 'outputTokens': 34},
          },
        },
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Hi from Codex'), findsOneWidget);
    expect(find.textContaining('end'), findsOneWidget);
  });

  testWidgets('keeps the composer text when sending the prompt fails', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient()
      ..sendUserMessageError = StateError('transport broke');
    addTearDown(appServerClient.close);

    await tester.pumpWidget(_buildCatalogApp(appServerClient: appServerClient));

    await _pumpAppReady(tester);

    final composerField = find.byKey(const ValueKey('composer_input'));
    await tester.enterText(composerField, 'Hello Codex');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pumpAndSettle();

    expect(appServerClient.connectCalls, 1);
    expect(appServerClient.startSessionCalls, 1);
    expect(appServerClient.sentMessages, isEmpty);
    expect(
      tester.widget<TextField>(composerField).controller?.text,
      'Hello Codex',
    );
    expect(find.textContaining('Could not send the prompt'), findsOneWidget);
  });

  testWidgets(
    'blocks sending after a missing conversation until the user starts fresh',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      final composerField = find.byKey(const ValueKey('composer_input'));
      await tester.enterText(composerField, 'First prompt');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turn': <String, Object?>{'id': 'turn_1', 'status': 'completed'},
          },
        ),
      );
      await tester.pumpAndSettle();

      appServerClient.sendUserMessageError = const CodexAppServerException(
        'turn/start failed: thread not found',
      );

      await tester.enterText(composerField, 'Second prompt');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      expect(find.text("This conversation can't continue."), findsOneWidget);
      expect(find.text('Start new conversation'), findsOneWidget);
      expect(find.text('First prompt'), findsOneWidget);
      expect(
        tester.widget<TextField>(composerField).controller?.text,
        'Second prompt',
      );

      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      expect(appServerClient.startSessionCalls, 1);
      expect(appServerClient.sentMessages, <String>['First prompt']);

      await tester.tap(
        find.byKey(
          const ValueKey('conversation_recovery_startFreshConversation'),
        ),
      );
      await tester.pumpAndSettle();
      appServerClient.sendUserMessageError = null;

      expect(find.text("This conversation can't continue."), findsNothing);

      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      expect(appServerClient.startSessionCalls, 2);
      expect(appServerClient.sentMessages, <String>[
        'First prompt',
        'Second prompt',
      ]);
    },
  );

  testWidgets(
    'shows an explicit thread-mismatch recovery notice when resume returns a different conversation',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient()
        ..startSessionError = const CodexAppServerException(
          'thread/resume returned a different thread id than requested.',
          data: <String, Object?>{
            'expectedThreadId': 'thread_old',
            'actualThreadId': 'thread_new',
          },
        );
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(
          appServerClient: appServerClient,
          connectionConversationStateStore:
              MemoryCodexConnectionConversationHistoryStore(
                initialStates: <String, SavedConnectionConversationState>{
                  'conn_primary': const SavedConnectionConversationState(
                    selectedThreadId: 'thread_old',
                  ),
                },
              ),
        ),
      );

      await _pumpAppReady(tester);

      final composerField = find.byKey(const ValueKey('composer_input'));
      await tester.enterText(composerField, 'Resume the old work');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      expect(find.text('Conversation identity changed.'), findsOneWidget);
      expect(find.textContaining('"thread_old"'), findsWidgets);
      expect(find.textContaining('"thread_new"'), findsWidgets);
      expect(
        tester.widget<TextField>(composerField).controller?.text,
        'Resume the old work',
      );
      expect(appServerClient.sentMessages, isEmpty);
    },
  );

  testWidgets('child agent output stays on its own timeline until selected', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(_buildCatalogApp(appServerClient: appServerClient));

    await _pumpAppReady(tester);

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'thread/started',
        params: <String, Object?>{
          'thread': <String, Object?>{'id': 'thread_root'},
        },
      ),
    );
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'thread/started',
        params: <String, Object?>{
          'thread': <String, Object?>{
            'id': 'thread_child',
            'agentNickname': 'Reviewer',
          },
        },
      ),
    );
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'turn/started',
        params: <String, Object?>{
          'threadId': 'thread_child',
          'turn': <String, Object?>{'id': 'turn_child_1', 'status': 'running'},
        },
      ),
    );
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/completed',
        params: <String, Object?>{
          'threadId': 'thread_child',
          'turnId': 'turn_child_1',
          'item': <String, Object?>{
            'id': 'item_child_1',
            'type': 'agentMessage',
            'status': 'completed',
            'text': 'Child analysis',
          },
        },
      ),
    );
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'turn/completed',
        params: <String, Object?>{
          'threadId': 'thread_child',
          'turn': <String, Object?>{
            'id': 'turn_child_1',
            'status': 'completed',
          },
        },
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('timeline_thread_child')), findsOneWidget);
    expect(find.text('Reviewer'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Child analysis'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('timeline_thread_child')));
    await tester.pumpAndSettle();

    expect(find.text('Child analysis'), findsOneWidget);
    expect(find.text('New'), findsNothing);
  });

  testWidgets(
    'renders an actionable host fingerprint card and saves it into connection settings',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);
      final repository = MemoryCodexConnectionRepository.single(
        savedProfile: _savedProfile(),
        connectionId: 'conn_primary',
      );

      await tester.pumpWidget(
        _buildCatalogApp(
          connectionRepository: repository,
          appServerClient: appServerClient,
        ),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerUnpinnedHostKeyEvent(
          host: 'example.com',
          port: 22,
          keyType: 'ssh-ed25519',
          fingerprint: '7a:9f:d7:dc:2e:f2:7d:c0:18:29:33:4d:22:2f:ae:4c',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Host key not pinned'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('save_host_fingerprint')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('host_fingerprint_value')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('save_host_fingerprint')));
      await tester.pumpAndSettle();

      expect(find.text('saved'), findsOneWidget);
      expect(find.byKey(const ValueKey('save_host_fingerprint')), findsNothing);
      expect(
        (await repository.loadConnection(
          'conn_primary',
        )).profile.hostFingerprint,
        '7a:9f:d7:dc:2e:f2:7d:c0:18:29:33:4d:22:2f:ae:4c',
      );

      await tester.tap(find.byKey(const ValueKey('open_connection_settings')));
      await tester.pumpAndSettle();

      final fingerprintField = tester.widget<TextField>(
        find.byKey(
          const ValueKey<String>('connection_settings_hostFingerprint'),
        ),
      );
      expect(
        fingerprintField.controller?.text,
        '7a:9f:d7:dc:2e:f2:7d:c0:18:29:33:4d:22:2f:ae:4c',
      );
    },
  );

  testWidgets(
    'renders SSH host key mismatch as a dedicated settings-oriented card',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerSshHostKeyMismatchEvent(
          host: 'example.com',
          port: 22,
          keyType: 'ssh-ed25519',
          expectedFingerprint: 'aa:bb:cc:dd',
          actualFingerprint: '11:22:33:44',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SSH host key mismatch'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('expected_host_fingerprint_value')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('observed_host_fingerprint_value')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('save_host_fingerprint')), findsNothing);
      expect(
        find.byKey(const ValueKey('open_connection_settings')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'renders SSH authentication failure as a dedicated settings-oriented card',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerSshAuthenticationFailedEvent(
          host: 'example.com',
          port: 22,
          username: 'vince',
          authMode: AuthMode.privateKey,
          message: 'Permission denied',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SSH authentication failed'), findsOneWidget);
      expect(find.textContaining('private key'), findsWidgets);
      expect(find.text('Permission denied'), findsOneWidget);
      expect(find.byKey(const ValueKey('save_host_fingerprint')), findsNothing);
      expect(
        find.byKey(const ValueKey('open_connection_settings')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'renders SSH remote launch failure as a dedicated settings-oriented card',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerSshRemoteLaunchFailedEvent(
          host: 'example.com',
          port: 22,
          username: 'vince',
          command: 'bash -lc codex app-server --listen stdio://',
          message: 'exec request denied',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SSH remote launch failed'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ssh_remote_command_value')),
        findsOneWidget,
      );
      expect(find.text('exec request denied'), findsOneWidget);
      expect(find.byKey(const ValueKey('save_host_fingerprint')), findsNothing);
    },
  );

  testWidgets(
    'reuses the current SSH failure card when the same connect failure repeats',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerSshConnectFailedEvent(
          host: 'example.com',
          port: 22,
          message: 'Connection refused',
        ),
      );
      appServerClient.emit(
        const CodexAppServerSshConnectFailedEvent(
          host: 'example.com',
          port: 22,
          message: 'Timed out',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SSH connection failed'), findsOneWidget);
      expect(find.text('Connection refused'), findsNothing);
      expect(find.text('Timed out'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ssh_connect_failed_card')),
        findsOneWidget,
      );
    },
  );

  testWidgets('appends plan update cards instead of replacing them', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(_buildCatalogApp(appServerClient: appServerClient));

    await _pumpAppReady(tester);

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'turn/plan/updated',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'explanation': 'Starting with the initial structure.',
          'plan': <Map<String, Object?>>[
            <String, Object?>{
              'step': 'Inspect transcript ownership',
              'status': 'in_progress',
            },
          ],
        },
      ),
    );

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'turn/plan/updated',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'explanation': 'Refining after reading the reducer.',
          'plan': <Map<String, Object?>>[
            <String, Object?>{
              'step': 'Inspect transcript ownership',
              'status': 'completed',
            },
            <String, Object?>{
              'step': 'Append visible plan updates',
              'status': 'in_progress',
            },
          ],
        },
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Updated Plan'), findsNWidgets(2));
    expect(find.text('Starting with the initial structure.'), findsOneWidget);
    expect(find.text('Refining after reading the reducer.'), findsOneWidget);
    expect(find.text('Append visible plan updates'), findsOneWidget);
  });

  testWidgets(
    'renders one grouped changed-files card for a multi-file file-change item',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await tester.pump(const Duration(milliseconds: 200));

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/started',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'file_change_1',
              'type': 'fileChange',
              'status': 'inProgress',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/fileChange/outputDelta',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'file_change_1',
            'delta': 'apply_patch exited successfully',
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'file_change_1',
              'type': 'fileChange',
              'status': 'completed',
              'changes': <Object?>[
                <String, Object?>{
                  'path': 'README.md',
                  'kind': <String, Object?>{'type': 'add'},
                  'diff': 'first line\nsecond line\n',
                },
                <String, Object?>{
                  'path': 'lib/app.dart',
                  'kind': <String, Object?>{
                    'type': 'update',
                    'move_path': null,
                  },
                  'diff':
                      '--- a/lib/app.dart\n'
                      '+++ b/lib/app.dart\n'
                      '@@ -1 +1,2 @@\n'
                      '-old\n'
                      '+new\n'
                      '+second\n',
                },
              ],
            },
          },
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Changed files'), findsOneWidget);
      expect(find.text('2 files'), findsOneWidget);
      expect(find.text('+4 -1'), findsOneWidget);
      expect(find.text('README.md'), findsOneWidget);
      expect(find.text('lib/app.dart'), findsOneWidget);
      expect(find.text('View diff'), findsNWidgets(2));

      await tester.tap(find.text('README.md'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('+first line'), findsOneWidget);
      expect(find.text('+second line'), findsOneWidget);
    },
  );

  testWidgets(
    'keeps interrupted assistant history as separate cards when the same item resumes',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/started',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'item_1',
              'type': 'agentMessage',
              'status': 'inProgress',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/agentMessage/delta',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_1',
            'delta': 'First',
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'configWarning',
          params: <String, Object?>{'summary': 'Intervening warning'},
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/agentMessage/delta',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_1',
            'delta': 'Second',
          },
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
    },
  );

  testWidgets(
    'keeps assistant, work, and resumed assistant in chronological order',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'assistant_1',
              'type': 'agentMessage',
              'status': 'completed',
              'text': 'Before work',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'command_1',
              'type': 'commandExecution',
              'status': 'completed',
              'command': 'git status',
              'result': <String, Object?>{'output': 'clean', 'exitCode': 0},
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'assistant_2',
              'type': 'agentMessage',
              'status': 'completed',
              'text': 'After work',
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      final beforeWorkDy = tester.getTopLeft(find.text('Before work')).dy;
      final workDy = tester
          .getTopLeft(find.text('Checking worktree status'))
          .dy;
      final afterWorkDy = tester.getTopLeft(find.text('After work')).dy;

      expect(find.text('Work log'), findsOneWidget);
      expect(beforeWorkDy, lessThan(workDy));
      expect(workDy, lessThan(afterWorkDy));
    },
  );

  testWidgets('renders consecutive work items in one grouped work card', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(_buildCatalogApp(appServerClient: appServerClient));

    await _pumpAppReady(tester);

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/completed',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'item': <String, Object?>{
            'id': 'item_cmd_1',
            'type': 'commandExecution',
            'status': 'completed',
            'command': 'git status',
            'result': <String, Object?>{'output': 'clean', 'exitCode': 0},
          },
        },
      ),
    );
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/completed',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'item': <String, Object?>{
            'id': 'item_search_2',
            'type': 'webSearch',
            'status': 'completed',
            'title': 'Search docs',
          },
        },
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Work log'), findsOneWidget);
    expect(find.text('Checking worktree status'), findsOneWidget);
    expect(find.text('Current repository'), findsOneWidget);
    expect(find.text('git status'), findsNothing);
    expect(find.text('Search docs'), findsOneWidget);
  });

  testWidgets('strips shell-wrapper noise from command work-log titles', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(_buildCatalogApp(appServerClient: appServerClient));

    await _pumpAppReady(tester);

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/completed',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'item': <String, Object?>{
            'id': 'item_cmd_1',
            'type': 'commandExecution',
            'status': 'completed',
            'command': '/usr/bin/zsh -lc "sed -n \'1,40p\' lib/main.dart"',
            'result': <String, Object?>{
              'output': 'class App {}',
              'exitCode': 0,
            },
          },
        },
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Reading lines 1 to 40'), findsOneWidget);
    expect(find.text('main.dart'), findsOneWidget);
    expect(find.text('lib/main.dart'), findsOneWidget);
    expect(find.text("sed -n '1,40p' lib/main.dart"), findsNothing);
    expect(find.textContaining('/usr/bin/zsh -lc'), findsNothing);
  });

  testWidgets('renders MCP tool calls as structured work-log rows', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(_buildCatalogApp(appServerClient: appServerClient));

    await _pumpAppReady(tester);

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/completed',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'item': <String, Object?>{
            'id': 'item_mcp_1',
            'type': 'mcpToolCall',
            'status': 'completed',
            'server': 'filesystem',
            'tool': 'read_file',
            'arguments': <String, Object?>{'path': 'README.md'},
            'result': <String, Object?>{
              'structuredContent': <String, Object?>{
                'path': 'README.md',
                'encoding': 'utf-8',
              },
            },
            'durationMs': 42,
          },
        },
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('filesystem.read_file'), findsOneWidget);
    expect(find.text('args: path: README.md'), findsOneWidget);
    expect(
      find.text('completed · path: README.md, encoding: utf-8 · 42 ms'),
      findsOneWidget,
    );
    expect(find.text('MCP tool call'), findsNothing);
  });

  testWidgets(
    'renders PowerShell-wrapped Get-Content commands as structured read work logs',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'item_cmd_pwsh_1',
              'type': 'commandExecution',
              'status': 'completed',
              'command':
                  r'powershell.exe -NoLogo -NoProfile -Command "Get-Content -Path C:\repo\README.md -TotalCount 25"',
              'result': <String, Object?>{
                'output': 'Pocket Relay',
                'exitCode': 0,
              },
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Reading first 25 lines'), findsOneWidget);
      expect(find.text('README.md'), findsOneWidget);
      expect(find.text(r'C:\repo\README.md'), findsOneWidget);
      expect(find.textContaining('powershell.exe -NoLogo'), findsNothing);
    },
  );

  testWidgets(
    'renders shell-wrapped rg commands as structured search work logs',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'item_cmd_rg_1',
              'type': 'commandExecution',
              'status': 'completed',
              'command':
                  '/usr/bin/zsh -lc "rg -n \\"relay_search_probe\\" lib test"',
              'result': <String, Object?>{
                'output': 'lib/main.dart:1:relay_search_probe',
                'exitCode': 0,
              },
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Searching for'), findsOneWidget);
      expect(find.text('relay_search_probe'), findsOneWidget);
      expect(find.text('In lib, test'), findsOneWidget);
      expect(find.textContaining('/usr/bin/zsh -lc'), findsNothing);
      expect(find.text('rg -n "relay_search_probe" lib test'), findsNothing);
    },
  );

  testWidgets(
    'renders PowerShell-wrapped Select-String commands as structured search work logs',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'item_cmd_select_string_1',
              'type': 'commandExecution',
              'status': 'completed',
              'command':
                  r'powershell.exe -NoLogo -NoProfile -Command "Select-String -Path C:\repo\README.md -Pattern \"relay_search_probe\""',
              'result': <String, Object?>{
                'output': 'README.md:1:relay_search_probe',
                'exitCode': 0,
              },
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Searching for'), findsOneWidget);
      expect(find.text('relay_search_probe'), findsOneWidget);
      expect(find.text(r'In C:\repo\README.md'), findsOneWidget);
      expect(find.textContaining('powershell.exe -NoLogo'), findsNothing);
      expect(
        find.text(
          r'Select-String -Path C:\repo\README.md -Pattern "relay_search_probe"',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'keeps a single local user prompt when the app-server echoes it back',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      await tester.enterText(
        find.byKey(const ValueKey('composer_input')),
        'Hello Codex',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'thread/started',
          params: <String, Object?>{
            'thread': <String, Object?>{'id': 'thread_123'},
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/started',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turn': <String, Object?>{'id': 'turn_1', 'status': 'running'},
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'configWarning',
          params: <String, Object?>{
            'summary': 'Connected to the remote session.',
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/updated',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'item_user_1',
              'type': 'userMessage',
              'status': 'inProgress',
              'text': 'Hello Codex',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'item_user_1',
              'type': 'userMessage',
              'status': 'completed',
              'text': 'Hello Codex',
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Hello Codex'), findsOneWidget);
      expect(find.text('You'), findsNothing);
      expect(find.text('local echo'), findsNothing);
      expect(find.text('sent'), findsNothing);
      expect(find.byType(SelectableText), findsWidgets);
      expect(
        find.textContaining('Connected to the remote session.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'consolidates sequential distinct file-change items into one changed-files card',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'file_change_1',
              'type': 'fileChange',
              'status': 'completed',
              'changes': <Object?>[
                <String, Object?>{
                  'path': 'README.md',
                  'kind': <String, Object?>{'type': 'add'},
                  'diff': 'first line\n',
                },
              ],
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'file_change_2',
              'type': 'fileChange',
              'status': 'completed',
              'changes': <Object?>[
                <String, Object?>{
                  'path': 'lib/app.dart',
                  'kind': <String, Object?>{'type': 'update'},
                  'diff':
                      '--- a/lib/app.dart\n'
                      '+++ b/lib/app.dart\n'
                      '@@ -1 +1 @@\n'
                      '-old\n'
                      '+new\n',
                },
              ],
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Changed files'), findsOneWidget);
      expect(find.text('2 files'), findsOneWidget);
      final readmeDy = tester.getTopLeft(find.text('README.md')).dy;
      final appDy = tester.getTopLeft(find.text('lib/app.dart')).dy;
      expect(readmeDy, lessThan(appDy));
    },
  );

  testWidgets(
    'starts a new changed-files card when the same file-change item resumes after a warning',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/started',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'file_change_1',
              'type': 'fileChange',
              'status': 'inProgress',
              'changes': <Object?>[
                <String, Object?>{
                  'path': 'README.md',
                  'kind': <String, Object?>{'type': 'add'},
                  'diff': 'first line\n',
                },
              ],
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'configWarning',
          params: <String, Object?>{'summary': 'Intervening warning'},
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'file_change_1',
              'type': 'fileChange',
              'status': 'completed',
              'changes': <Object?>[
                <String, Object?>{
                  'path': 'README.md',
                  'kind': <String, Object?>{'type': 'add'},
                  'diff': 'first line\n',
                },
                <String, Object?>{
                  'path': 'lib/app.dart',
                  'kind': <String, Object?>{'type': 'update'},
                  'diff':
                      '--- a/lib/app.dart\n'
                      '+++ b/lib/app.dart\n'
                      '@@ -1 +1 @@\n'
                      '-old\n'
                      '+new\n',
                },
              ],
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Changed files'), findsNWidgets(2));
      expect(find.text('README.md'), findsNWidgets(2));
      expect(find.text('lib/app.dart'), findsOneWidget);
      expect(find.textContaining('Intervening warning'), findsOneWidget);

      final firstChangedFilesDy = tester
          .getTopLeft(find.text('Changed files').first)
          .dy;
      final warningDy = tester
          .getTopLeft(find.textContaining('Intervening warning'))
          .dy;
      final secondChangedFilesDy = tester
          .getTopLeft(find.text('Changed files').last)
          .dy;

      expect(firstChangedFilesDy, lessThan(warningDy));
      expect(warningDy, lessThan(secondChangedFilesDy));
    },
  );

  testWidgets(
    'starts a new changed-files card when the same file-change item resumes after approval',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/started',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'file_change_1',
              'type': 'fileChange',
              'status': 'inProgress',
              'changes': <Object?>[
                <String, Object?>{
                  'path': 'README.md',
                  'kind': <String, Object?>{'type': 'add'},
                  'diff': 'first line\n',
                },
              ],
            },
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Changed files'), findsOneWidget);
      expect(find.text('README.md'), findsOneWidget);
      expect(find.text('updating'), findsOneWidget);

      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 'i:99',
          method: 'item/fileChange/requestApproval',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'file_change_1',
            'reason': 'Write files',
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Changed files'), findsOneWidget);
      expect(find.text('updating'), findsNothing);
      expect(find.text('File change approval'), findsOneWidget);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'serverRequest/resolved',
          params: <String, Object?>{'threadId': 'thread_123', 'requestId': 99},
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'file_change_1',
              'type': 'fileChange',
              'status': 'completed',
              'changes': <Object?>[
                <String, Object?>{
                  'path': 'README.md',
                  'kind': <String, Object?>{'type': 'add'},
                  'diff': 'first line\n',
                },
                <String, Object?>{
                  'path': 'lib/app.dart',
                  'kind': <String, Object?>{'type': 'update'},
                  'diff':
                      '--- a/lib/app.dart\n'
                      '+++ b/lib/app.dart\n'
                      '@@ -1 +1 @@\n'
                      '-old\n'
                      '+new\n',
                },
              ],
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Changed files'), findsNWidgets(2));
      expect(find.text('README.md'), findsNWidgets(2));
      expect(find.text('lib/app.dart'), findsOneWidget);
      expect(find.text('File change approval resolved'), findsOneWidget);

      final firstChangedFilesDy = tester
          .getTopLeft(find.text('Changed files').first)
          .dy;
      final resolvedDy = tester
          .getTopLeft(find.text('File change approval resolved'))
          .dy;
      final secondChangedFilesDy = tester
          .getTopLeft(find.text('Changed files').last)
          .dy;

      expect(firstChangedFilesDy, lessThan(resolvedDy));
      expect(resolvedDy, lessThan(secondChangedFilesDy));
    },
  );

  testWidgets('approval actions are routed to the app-server client', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(_buildCatalogApp(appServerClient: appServerClient));

    await _pumpAppReady(tester);

    appServerClient.emit(
      const CodexAppServerRequestEvent(
        requestId: 'i:99',
        method: 'item/fileChange/requestApproval',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'itemId': 'item_1',
          'reason': 'Write files',
        },
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('File change approval'), findsOneWidget);
    expect(find.text('Write files'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(
      appServerClient.approvalDecisions,
      <({String requestId, bool approved})>[
        (requestId: 'i:99', approved: true),
      ],
    );
  });

  testWidgets('freezes a running assistant card when approval opens', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(_buildCatalogApp(appServerClient: appServerClient));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/started',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'item': <String, Object?>{
            'id': 'assistant_1',
            'type': 'agentMessage',
            'status': 'inProgress',
          },
        },
      ),
    );
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/agentMessage/delta',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'itemId': 'assistant_1',
          'delta': 'Before request',
        },
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Before request'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    appServerClient.emit(
      const CodexAppServerRequestEvent(
        requestId: 'i:99',
        method: 'item/fileChange/requestApproval',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'itemId': 'assistant_1',
          'reason': 'Write files',
        },
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Before request'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('File change approval'), findsOneWidget);
  });

  testWidgets(
    'keeps pending approvals off the transcript until resolution and preserves chronology',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'assistant_before',
              'type': 'agentMessage',
              'status': 'completed',
              'text': 'Before request',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 'i:99',
          method: 'item/fileChange/requestApproval',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'assistant_before',
            'reason': 'Write files',
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Before request'), findsOneWidget);
      expect(find.text('File change approval'), findsOneWidget);
      expect(find.text('File change approval resolved'), findsNothing);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'serverRequest/resolved',
          params: <String, Object?>{'threadId': 'thread_123', 'requestId': 99},
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'assistant_after',
              'type': 'agentMessage',
              'status': 'completed',
              'text': 'After request',
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('File change approval'), findsNothing);
      expect(find.text('File change approval resolved'), findsOneWidget);

      final beforeRequestDy = tester.getTopLeft(find.text('Before request')).dy;
      final resolvedDy = tester
          .getTopLeft(find.text('File change approval resolved'))
          .dy;
      final afterRequestDy = tester.getTopLeft(find.text('After request')).dy;

      expect(beforeRequestDy, lessThan(resolvedDy));
      expect(resolvedDy, lessThan(afterRequestDy));
    },
  );

  testWidgets(
    'freezes running work before approval opens and resumes work after resolution',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/started',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'command_1',
              'type': 'commandExecution',
              'status': 'inProgress',
              'command': 'git status',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/commandExecution/outputDelta',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'command_1',
            'delta': 'clean',
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Work log'), findsOneWidget);
      expect(find.text('Checking worktree status'), findsOneWidget);
      expect(find.text('running'), findsOneWidget);

      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 'i:99',
          method: 'item/fileChange/requestApproval',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'command_1',
            'reason': 'Write files',
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Checking worktree status'), findsOneWidget);
      expect(find.text('running'), findsNothing);
      expect(find.text('File change approval'), findsOneWidget);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'serverRequest/resolved',
          params: <String, Object?>{'threadId': 'thread_123', 'requestId': 99},
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'search_2',
              'type': 'webSearch',
              'status': 'completed',
              'title': 'Search docs',
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Work log'), findsNWidgets(2));
      expect(find.text('File change approval resolved'), findsOneWidget);
      expect(find.text('Search docs'), findsOneWidget);

      final firstWorkDy = tester
          .getTopLeft(find.text('Checking worktree status'))
          .dy;
      final resolvedDy = tester
          .getTopLeft(find.text('File change approval resolved'))
          .dy;
      final resumedWorkDy = tester.getTopLeft(find.text('Search docs')).dy;

      expect(firstWorkDy, lessThan(resolvedDy));
      expect(resolvedDy, lessThan(resumedWorkDy));
    },
  );

  testWidgets(
    'keeps updating the existing work row after assistant text takes the tail',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/started',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'command_1',
              'type': 'commandExecution',
              'status': 'inProgress',
              'command': 'git status',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/commandExecution/outputDelta',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'command_1',
            'delta': 'clean',
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/agentMessage/delta',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'assistant_1',
            'delta': 'Investigating',
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Work log'), findsOneWidget);
      expect(find.text('Checking worktree status'), findsOneWidget);
      expect(find.text('Investigating'), findsOneWidget);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/commandExecution/outputDelta',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'command_1',
            'delta': ' status',
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Work log'), findsOneWidget);
      expect(find.text('Checking worktree status'), findsOneWidget);
      expect(find.text('Investigating'), findsOneWidget);
    },
  );

  testWidgets(
    'promotes the next pending approval without broadening the pinned approval surface',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 'i:101',
          method: 'item/fileChange/requestApproval',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_1',
            'reason': 'Write the first file',
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 'i:102',
          method: 'item/fileChange/requestApproval',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_2',
            'reason': 'Write the second file',
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Write the first file'), findsOneWidget);
      expect(find.text('Write the second file'), findsNothing);
      expect(find.text('File change approval'), findsOneWidget);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'serverRequest/resolved',
          params: <String, Object?>{'threadId': 'thread_123', 'requestId': 101},
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Write the first file'), findsNothing);
      expect(find.text('Write the second file'), findsOneWidget);
      expect(find.text('File change approval'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the live turn timer above the composer without needing an assistant block',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'thread/started',
          params: <String, Object?>{
            'thread': <String, Object?>{'id': 'thread_123'},
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/started',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turn': <String, Object?>{
              'id': 'turn_live',
              'model': 'gpt-5.3-codex',
            },
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('Elapsed'), findsOneWidget);
      expect(find.text('Assistant message'), findsNothing);

      final timerChip = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.padding ==
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      );
      final timerRect = tester.getRect(timerChip);
      final inputRect = tester.getRect(
        find.byKey(const ValueKey('composer_input')),
      );

      expect(timerRect.top, lessThan(inputRect.top));
      expect(inputRect.top - timerRect.bottom, greaterThan(0));
    },
  );

  testWidgets(
    'user-input requests are submitted through the app-server client',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 's:user-input-1',
          method: 'item/tool/requestUserInput',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_1',
            'questions': <Object>[
              <String, Object?>{
                'id': 'q1',
                'header': 'Name',
                'question': 'What is your name?',
                'options': <Object>[
                  <String, Object?>{
                    'label': 'Vince',
                    'description': 'Use the saved profile name.',
                  },
                ],
              },
            ],
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Input required'), findsOneWidget);
      expect(find.text('What is your name?'), findsOneWidget);

      await tester.tap(find.text('Vince').first);
      await tester.pump();
      await tester.ensureVisible(find.text('Submit response'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit response'));
      await tester.pumpAndSettle();

      expect(appServerClient.userInputResponses, hasLength(1));
      expect(
        appServerClient.userInputResponses.single.requestId,
        's:user-input-1',
      );
      expect(
        appServerClient.userInputResponses.single.answers,
        <String, List<String>>{
          'q1': <String>['Vince'],
        },
      );
      expect(appServerClient.elicitationResponses, isEmpty);
    },
  );

  testWidgets(
    'promotes the next pending user-input request without leaking the prior draft',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 's:user-input-1',
          method: 'item/tool/requestUserInput',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_1',
            'questions': <Object>[
              <String, Object?>{
                'id': 'q1',
                'header': 'Project',
                'question': 'Which first project should I use?',
              },
            ],
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 's:user-input-2',
          method: 'item/tool/requestUserInput',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_2',
            'questions': <Object>[
              <String, Object?>{
                'id': 'q1',
                'header': 'Project',
                'question': 'Which second project should I use?',
              },
            ],
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Which first project should I use?'), findsOneWidget);
      expect(find.text('Which second project should I use?'), findsNothing);

      final textField = find.byKey(
        const ValueKey<String>('pending_user_input_q1'),
      );
      await tester.enterText(textField, 'Pocket Relay');
      await tester.pump();
      await tester.ensureVisible(find.text('Submit response'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit response'));
      await tester.pumpAndSettle();

      expect(appServerClient.userInputResponses, hasLength(1));
      expect(
        appServerClient.userInputResponses.single.requestId,
        's:user-input-1',
      );
      expect(
        appServerClient.userInputResponses.single.answers,
        <String, List<String>>{
          'q1': <String>['Pocket Relay'],
        },
      );

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/tool/requestUserInput/answered',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_1',
            'requestId': 'user-input-1',
            'answers': <String, Object?>{
              'q1': <String, Object?>{
                'answers': <String>['Pocket Relay'],
              },
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Which first project should I use?'), findsNothing);
      expect(find.text('Which second project should I use?'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey<String>('pending_user_input_q1')),
            )
            .controller
            ?.text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'mcp elicitation requests are submitted through the elicitation response path',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 's:elicitation-1',
          method: 'mcpServer/elicitation/request',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
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
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('MCP input required'), findsOneWidget);
      expect(find.text('Choose a directory'), findsOneWidget);

      final responseField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Response',
      );

      await tester.enterText(responseField, '/workspace/mobile');
      await tester.ensureVisible(find.text('Submit response'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit response'));
      await tester.pumpAndSettle();

      expect(appServerClient.userInputResponses, isEmpty);
      expect(appServerClient.elicitationResponses, hasLength(1));
      expect(
        appServerClient.elicitationResponses.single.requestId,
        's:elicitation-1',
      );
      expect(
        appServerClient.elicitationResponses.single.action,
        CodexAppServerElicitationAction.accept,
      );
      expect(
        appServerClient.elicitationResponses.single.content,
        '/workspace/mobile',
      );
    },
  );

  testWidgets(
    'keeps the richer user-input transcript card when a generic resolved event arrives later',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 's:user-input-1',
          method: 'item/tool/requestUserInput',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_1',
            'questions': <Object>[
              <String, Object?>{
                'id': 'q1',
                'header': 'Name',
                'question': 'What is your name?',
              },
            ],
          },
        ),
      );

      await tester.pumpAndSettle();

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/tool/requestUserInput/answered',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_1',
            'requestId': 'user-input-1',
            'answers': <String, Object?>{
              'q1': <Object>['Vince'],
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Input submitted'), findsOneWidget);
      expect(find.textContaining('Vince'), findsOneWidget);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'serverRequest/resolved',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'requestId': 'user-input-1',
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Input submitted'), findsOneWidget);
      expect(find.textContaining('Vince'), findsOneWidget);
      expect(find.text('Input required resolved'), findsNothing);
      expect(find.text('Request resolved'), findsNothing);
    },
  );

  testWidgets(
    'keeps user-input chronology when assistant output resumes after submission',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/started',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'assistant_1',
              'type': 'agentMessage',
              'status': 'inProgress',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/agentMessage/delta',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'assistant_1',
            'delta': 'Before request',
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Before request'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 's:user-input-1',
          method: 'item/tool/requestUserInput',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'assistant_1',
            'questions': <Object>[
              <String, Object?>{
                'id': 'q1',
                'header': 'Name',
                'question': 'What is your name?',
              },
            ],
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Input required'), findsOneWidget);
      expect(find.text('Before request'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/tool/requestUserInput/answered',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'assistant_1',
            'requestId': 'user-input-1',
            'answers': <String, Object?>{
              'q1': <Object>['Vince'],
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Input required'), findsNothing);
      expect(find.text('Input submitted'), findsOneWidget);
      expect(find.textContaining('Vince'), findsOneWidget);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/agentMessage/delta',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'assistant_1',
            'delta': 'After request',
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('After request'), findsOneWidget);

      final beforeDy = tester.getTopLeft(find.text('Before request')).dy;
      final submittedDy = tester.getTopLeft(find.text('Input submitted')).dy;
      final afterDy = tester.getTopLeft(find.text('After request')).dy;

      expect(beforeDy, lessThan(submittedDy));
      expect(submittedDy, lessThan(afterDy));
    },
  );

  testWidgets('unsupported host requests are rejected with a status entry', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(_buildCatalogApp(appServerClient: appServerClient));

    await _pumpAppReady(tester);

    appServerClient.emit(
      const CodexAppServerRequestEvent(
        requestId: 's:auth-1',
        method: 'account/chatgptAuthTokens/refresh',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'reason': 'unauthorized',
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Auth refresh unsupported'), findsOneWidget);
    expect(
      find.textContaining('does not manage external ChatGPT tokens'),
      findsOneWidget,
    );
    expect(appServerClient.rejectedRequests, <
      ({String requestId, String message})
    >[
      (
        requestId: 's:auth-1',
        message:
            'Pocket Relay does not manage external ChatGPT tokens, so this app-server auth refresh request was rejected.',
      ),
    ]);
  });

  testWidgets(
    'streaming updates do not yank the transcript while scrolled up',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );

      await _pumpAppReady(tester);

      for (var index = 0; index < 24; index += 1) {
        appServerClient.emit(
          CodexAppServerNotificationEvent(
            method: 'item/completed',
            params: <String, Object?>{
              'threadId': 'thread_123',
              'turnId': 'turn_$index',
              'item': <String, Object?>{
                'id': 'item_$index',
                'type': 'agentMessage',
                'status': 'completed',
                'text': 'Assistant message $index',
              },
            },
          ),
        );
      }

      await tester.pumpAndSettle();

      final scrollableState = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollableState.position.maxScrollExtent, greaterThan(0));

      await tester.drag(find.byType(ListView), const Offset(0, 320));
      await tester.pumpAndSettle();

      final pixelsBeforeStream = scrollableState.position.pixels;
      expect(
        pixelsBeforeStream,
        lessThan(scrollableState.position.maxScrollExtent),
      );

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/started',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_live',
            'item': <String, Object?>{
              'id': 'item_live',
              'type': 'agentMessage',
              'status': 'inProgress',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/agentMessage/delta',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_live',
            'itemId': 'item_live',
            'delta': 'Live stream text',
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(scrollableState.position.pixels, closeTo(pixelsBeforeStream, 1));
      expect(
        scrollableState.position.pixels,
        lessThan(scrollableState.position.maxScrollExtent - 40),
      );
    },
  );

  testWidgets('invalid prompt submission does not force transcript follow', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(
      _buildCatalogApp(
        appServerClient: appServerClient,
        savedProfile: _savedProfile(secrets: const ConnectionSecrets()),
      ),
    );

    await _pumpAppReady(tester);

    for (var index = 0; index < 24; index += 1) {
      appServerClient.emit(
        CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_$index',
            'item': <String, Object?>{
              'id': 'item_$index',
              'type': 'agentMessage',
              'status': 'completed',
              'text': 'Assistant message $index',
            },
          },
        ),
      );
    }

    await tester.pumpAndSettle();

    final scrollableState = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollableState.position.maxScrollExtent, greaterThan(0));

    await tester.drag(find.byType(ListView), const Offset(0, 320));
    await tester.pumpAndSettle();

    final pixelsBeforeSubmit = scrollableState.position.pixels;
    expect(
      pixelsBeforeSubmit,
      lessThan(scrollableState.position.maxScrollExtent),
    );

    await tester.enterText(
      find.byKey(const ValueKey('composer_input')),
      'Needs credentials',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pumpAndSettle();

    expect(find.text('This profile needs an SSH password.'), findsOneWidget);
    expect(appServerClient.sentMessages, isEmpty);
    expect(scrollableState.position.pixels, closeTo(pixelsBeforeSubmit, 1));
    expect(
      scrollableState.position.pixels,
      lessThan(scrollableState.position.maxScrollExtent - 40),
    );
  });

  testWidgets('thread token usage is shown once when the turn completes', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(_buildCatalogApp(appServerClient: appServerClient));

    await _pumpAppReady(tester);

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'turn/started',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{
            'id': 'turn_live',
            'model': 'gpt-5.3-codex',
          },
        },
      ),
    );

    for (var index = 0; index < 20; index += 1) {
      appServerClient.emit(
        CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_$index',
            'item': <String, Object?>{
              'id': 'item_$index',
              'type': 'agentMessage',
              'status': 'completed',
              'text': 'Assistant message $index',
            },
          },
        ),
      );
    }
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'thread/tokenUsage/updated',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_live',
          'tokenUsage': <String, Object?>{
            'last': <String, Object?>{
              'inputTokens': 10,
              'cachedInputTokens': 2,
              'outputTokens': 4,
              'reasoningOutputTokens': 1,
              'totalTokens': 17,
            },
            'total': <String, Object?>{
              'inputTokens': 20,
              'cachedInputTokens': 3,
              'outputTokens': 8,
              'reasoningOutputTokens': 1,
              'totalTokens': 32,
            },
            'modelContextWindow': 200000,
          },
        },
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Thread usage'), findsNothing);

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'turn/completed',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{
            'id': 'turn_live',
            'status': 'completed',
            'usage': <String, Object?>{
              'inputTokens': 12,
              'cachedInputTokens': 3,
              'outputTokens': 7,
            },
          },
        },
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Thread usage'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Thread usage'), findsOneWidget);
    expect(find.text('ctx 200k'), findsOneWidget);
    expect(find.textContaining('end'), findsAtLeastNWidgets(1));

    final endRect = tester.getRect(find.textContaining('end').last);
    final usageRect = tester.getRect(find.text('Thread usage'));
    expect(usageRect.top, lessThan(endRect.top));
  });
}

ConnectionProfile _configuredProfile() {
  return ConnectionProfile.defaults().copyWith(
    host: 'example.com',
    username: 'vince',
    workspaceDir: '/workspace',
  );
}

SavedProfile _savedProfile({
  ConnectionSecrets secrets = const ConnectionSecrets(password: 'secret'),
}) {
  return SavedProfile(profile: _configuredProfile(), secrets: secrets);
}

PocketRelayApp _buildCatalogApp({
  required CodexAppServerClient appServerClient,
  SavedProfile? savedProfile,
  CodexConnectionRepository? connectionRepository,
  CodexConnectionConversationStateStore? connectionConversationStateStore,
}) {
  return PocketRelayApp(
    connectionRepository:
        connectionRepository ??
        MemoryCodexConnectionRepository.single(
          savedProfile: savedProfile ?? _savedProfile(),
          connectionId: 'conn_primary',
        ),
    connectionConversationStateStore:
        connectionConversationStateStore ??
        MemoryCodexConnectionConversationHistoryStore(),
    appServerClient: appServerClient,
  );
}

Future<void> _pumpAppReady(WidgetTester tester) {
  return _pumpUntil(
    tester,
    () => find.byKey(const ValueKey('send')).evaluate().isNotEmpty,
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 2),
  Duration step = const Duration(milliseconds: 50),
}) async {
  final maxTicks = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (var tick = 0; tick < maxTicks; tick += 1) {
    await tester.pump(step);
    final exception = tester.takeException();
    if (exception != null) {
      throw exception;
    }
    if (predicate()) {
      return;
    }
  }

  throw TestFailure(
    'Condition was not met within $timeout. '
    'send=${find.byKey(const ValueKey('send')).evaluate().length} '
    'textField=${find.byType(TextField).evaluate().length} '
    'loading=${find.byType(CircularProgressIndicator).evaluate().length} '
    'title=${find.text('Pocket Relay').evaluate().length} '
    'configureRemote=${find.text('Configure remote').evaluate().length}',
  );
}
