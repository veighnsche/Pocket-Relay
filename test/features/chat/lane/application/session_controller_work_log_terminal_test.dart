import 'session_controller_test_support.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_work_log_terminal_contract.dart';

void main() {
  test(
    'hydrateWorkLogTerminal uses active turn data for running commands',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/started',
          params: <String, Object?>{
            'threadId': 'thread_live',
            'turnId': 'turn_live',
            'item': <String, Object?>{
              'id': 'command_live',
              'type': 'commandExecution',
              'status': 'inProgress',
              'command': 'python demo.py',
              'processId': 'proc_live',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/commandExecution/terminalInteraction',
          params: <String, Object?>{
            'threadId': 'thread_live',
            'turnId': 'turn_live',
            'itemId': 'command_live',
            'processId': 'proc_live',
            'stdin': 'y\n',
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/commandExecution/outputDelta',
          params: <String, Object?>{
            'threadId': 'thread_live',
            'turnId': 'turn_live',
            'itemId': 'command_live',
            'delta': 'continuing...\n',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final hydrated = await controller.hydrateWorkLogTerminal(
        const ChatWorkLogTerminalContract(
          id: 'item_command_live',
          activityLabel: 'Running command',
          commandText: 'python demo.py',
          isRunning: true,
          isWaiting: false,
          itemId: 'command_live',
          threadId: 'thread_live',
          turnId: 'turn_live',
        ),
      );

      expect(hydrated.commandText, 'python demo.py');
      expect(hydrated.processId, 'proc_live');
      expect(hydrated.terminalInput, 'y\n');
      expect(hydrated.terminalOutput, 'continuing...\n');
      expect(appServerClient.readThreadCalls, isEmpty);
    },
  );

  test(
    'hydrateWorkLogTerminal reads historical thread output for completed commands',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] =
            const CodexAppServerThreadHistory(
              id: 'thread_saved',
              turns: <CodexAppServerHistoryTurn>[
                CodexAppServerHistoryTurn(
                  id: 'turn_saved',
                  status: 'completed',
                  items: <CodexAppServerHistoryItem>[
                    CodexAppServerHistoryItem(
                      id: 'command_saved',
                      type: 'commandExecution',
                      status: 'completed',
                      raw: <String, dynamic>{
                        'id': 'command_saved',
                        'type': 'commandExecution',
                        'status': 'completed',
                        'command': 'pwd',
                        'aggregatedOutput': '/repo\n',
                        'exitCode': 0,
                      },
                    ),
                  ],
                  raw: <String, dynamic>{
                    'id': 'turn_saved',
                    'status': 'completed',
                  },
                ),
              ],
            );
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      final hydrated = await controller.hydrateWorkLogTerminal(
        const ChatWorkLogTerminalContract(
          id: 'item_command_saved',
          activityLabel: 'Ran command',
          commandText: 'pwd',
          isRunning: false,
          isWaiting: false,
          itemId: 'command_saved',
          threadId: 'thread_saved',
          turnId: 'turn_saved',
        ),
      );

      expect(appServerClient.readThreadCalls, <String>['thread_saved']);
      expect(hydrated.commandText, 'pwd');
      expect(hydrated.terminalOutput, '/repo\n');
      expect(hydrated.exitCode, 0);
    },
  );

  test(
    'hydrateWorkLogTerminal ignores active items from a different turn id',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_shared'] =
            const CodexAppServerThreadHistory(
              id: 'thread_shared',
              turns: <CodexAppServerHistoryTurn>[
                CodexAppServerHistoryTurn(
                  id: 'turn_old',
                  status: 'completed',
                  items: <CodexAppServerHistoryItem>[
                    CodexAppServerHistoryItem(
                      id: 'shared_command',
                      type: 'commandExecution',
                      status: 'completed',
                      raw: <String, dynamic>{
                        'id': 'shared_command',
                        'type': 'commandExecution',
                        'status': 'completed',
                        'command': 'pwd',
                        'aggregatedOutput': '/repo/old\n',
                      },
                    ),
                  ],
                  raw: <String, dynamic>{
                    'id': 'turn_old',
                    'status': 'completed',
                  },
                ),
                CodexAppServerHistoryTurn(
                  id: 'turn_new',
                  status: 'in_progress',
                  items: <CodexAppServerHistoryItem>[
                    CodexAppServerHistoryItem(
                      id: 'shared_command',
                      type: 'commandExecution',
                      status: 'in_progress',
                      raw: <String, dynamic>{
                        'id': 'shared_command',
                        'type': 'commandExecution',
                        'status': 'in_progress',
                        'command': 'pwd',
                        'aggregatedOutput': '/repo/new\n',
                      },
                    ),
                  ],
                  raw: <String, dynamic>{
                    'id': 'turn_new',
                    'status': 'in_progress',
                  },
                ),
              ],
            );
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/started',
          params: <String, Object?>{
            'threadId': 'thread_shared',
            'turnId': 'turn_new',
            'item': <String, Object?>{
              'id': 'shared_command',
              'type': 'commandExecution',
              'status': 'inProgress',
              'command': 'pwd',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/commandExecution/outputDelta',
          params: <String, Object?>{
            'threadId': 'thread_shared',
            'turnId': 'turn_new',
            'itemId': 'shared_command',
            'delta': '/repo/live\n',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final hydrated = await controller.hydrateWorkLogTerminal(
        const ChatWorkLogTerminalContract(
          id: 'item_shared_command',
          activityLabel: 'Ran command',
          commandText: 'pwd',
          isRunning: false,
          isWaiting: false,
          itemId: 'shared_command',
          threadId: 'thread_shared',
          turnId: 'turn_old',
        ),
      );

      expect(appServerClient.readThreadCalls, <String>['thread_shared']);
      expect(hydrated.terminalOutput, '/repo/old\n');
      expect(hydrated.isRunning, isFalse);
    },
  );

  test(
    'hydrateWorkLogTerminal reads nested result output and exit code',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_result'] =
            const CodexAppServerThreadHistory(
              id: 'thread_result',
              turns: <CodexAppServerHistoryTurn>[
                CodexAppServerHistoryTurn(
                  id: 'turn_result',
                  status: 'completed',
                  items: <CodexAppServerHistoryItem>[
                    CodexAppServerHistoryItem(
                      id: 'command_result',
                      type: 'commandExecution',
                      status: 'completed',
                      raw: <String, dynamic>{
                        'id': 'command_result',
                        'type': 'commandExecution',
                        'status': 'completed',
                        'command': 'git status',
                        'result': <String, dynamic>{
                          'output': 'clean\n',
                          'exitCode': 23,
                        },
                      },
                    ),
                  ],
                  raw: <String, dynamic>{
                    'id': 'turn_result',
                    'status': 'completed',
                  },
                ),
              ],
            );
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      final hydrated = await controller.hydrateWorkLogTerminal(
        const ChatWorkLogTerminalContract(
          id: 'item_command_result',
          activityLabel: 'Ran command',
          commandText: 'git status',
          isRunning: false,
          isWaiting: false,
          itemId: 'command_result',
          threadId: 'thread_result',
          turnId: 'turn_result',
        ),
      );

      expect(hydrated.terminalOutput, 'clean\n');
      expect(hydrated.exitCode, 23);
      expect(hydrated.statusBadgeLabel, 'exit 23');
    },
  );

  test(
    'hydrateWorkLogTerminal preserves failed status without an exit code',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_failed'] =
            const CodexAppServerThreadHistory(
              id: 'thread_failed',
              turns: <CodexAppServerHistoryTurn>[
                CodexAppServerHistoryTurn(
                  id: 'turn_failed',
                  status: 'failed',
                  items: <CodexAppServerHistoryItem>[
                    CodexAppServerHistoryItem(
                      id: 'command_failed',
                      type: 'commandExecution',
                      status: 'failed',
                      raw: <String, dynamic>{
                        'id': 'command_failed',
                        'type': 'commandExecution',
                        'status': 'failed',
                        'command': 'make build',
                        'result': <String, dynamic>{'output': 'boom\n'},
                      },
                    ),
                  ],
                  raw: <String, dynamic>{
                    'id': 'turn_failed',
                    'status': 'failed',
                  },
                ),
              ],
            );
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      final hydrated = await controller.hydrateWorkLogTerminal(
        const ChatWorkLogTerminalContract(
          id: 'item_command_failed',
          activityLabel: 'Ran command',
          commandText: 'make build',
          isRunning: false,
          isWaiting: false,
          itemId: 'command_failed',
          threadId: 'thread_failed',
          turnId: 'turn_failed',
        ),
      );

      expect(hydrated.terminalOutput, 'boom\n');
      expect(hydrated.exitCode, isNull);
      expect(hydrated.isFailed, isTrue);
      expect(hydrated.statusBadgeLabel, 'failed');
    },
  );
}
