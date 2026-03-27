import 'renderer_test_support.dart';

void main() {
  testWidgets('forwards toolbar and menu actions through app chrome', (
    tester,
  ) async {
    final actions = <ChatScreenActionId>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: Scaffold(
          appBar: FlutterChatAppChrome(
            screen: screenContract(),
            onScreenAction: actions.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Connection settings'));
    await tester.pump();

    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New thread'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Branch conversation'));
    await tester.pumpAndSettle();

    expect(actions, <ChatScreenActionId>[
      ChatScreenActionId.openSettings,
      ChatScreenActionId.newThread,
      ChatScreenActionId.branchConversation,
    ]);
  });

  testWidgets('app chrome supports supplemental workspace menu actions', (
    tester,
  ) async {
    final laneActions = <ChatScreenActionId>[];
    var openedDormantConnections = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: Scaffold(
          appBar: FlutterChatAppChrome(
            screen: screenContract(),
            onScreenAction: laneActions.add,
            supplementalMenuActions: <ChatChromeMenuAction>[
              ChatChromeMenuAction(
                label: 'Saved workspaces',
                onSelected: () {
                  openedDormantConnections = true;
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();

    expect(find.text('New thread'), findsOneWidget);
    expect(find.text('Branch conversation'), findsOneWidget);
    expect(find.text('Saved workspaces'), findsOneWidget);

    await tester.tap(find.text('Saved workspaces'));
    await tester.pumpAndSettle();

    expect(openedDormantConnections, isTrue);
    expect(laneActions, isEmpty);
  });
}
