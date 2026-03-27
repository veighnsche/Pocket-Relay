import 'screen_app_server_test_support.dart';

void main() {
  testWidgets('renders MCP tool calls as structured work-log rows', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(buildCatalogApp(appServerClient: appServerClient));

    await pumpAppReady(tester);

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

    expect(find.text('Work log'), findsOneWidget);
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
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);

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
    'renders PowerShell-wrapped Get-Content Select-Object range commands as structured read work logs',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'item_cmd_pwsh_select_1',
              'type': 'commandExecution',
              'status': 'completed',
              'command':
                  r'powershell.exe -NoLogo -NoProfile -Command "Get-Content -Path C:\repo\README.md | Select-Object -Skip 4 -First 21"',
              'result': <String, Object?>{'output': 'line 5', 'exitCode': 0},
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Reading lines 5 to 25'), findsOneWidget);
      expect(find.text('README.md'), findsOneWidget);
      expect(find.text(r'C:\repo\README.md'), findsOneWidget);
      expect(find.textContaining('powershell.exe -NoLogo'), findsNothing);
      expect(
        find.textContaining('Get-Content -Path C:\\repo\\README.md |'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'renders shell-wrapped nl piped into sed commands as structured read work logs',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'item_cmd_nl_sed_1',
              'type': 'commandExecution',
              'status': 'completed',
              'command':
                  '/usr/bin/zsh -lc "nl -ba lib/main.dart | sed -n \'1,40p\'"',
              'result': <String, Object?>{'output': '1\timport', 'exitCode': 0},
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Reading lines 1 to 40'), findsOneWidget);
      expect(find.text('main.dart'), findsOneWidget);
      expect(find.text('lib/main.dart'), findsOneWidget);
      expect(find.textContaining('/usr/bin/zsh -lc'), findsNothing);
      expect(
        find.textContaining('nl -ba lib/main.dart | sed -n'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'renders shell-wrapped rg commands as structured search work logs',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);

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
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);

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
}
