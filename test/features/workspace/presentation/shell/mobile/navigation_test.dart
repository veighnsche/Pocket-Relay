import 'mobile_shell_test_support.dart';

void main() {
  testWidgets('swiping past the live lane reveals the dormant roster', (
    tester,
  ) async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(buildShell(controller));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved workspaces'), findsWidgets);
    expect(
      find.byKey(const ValueKey('saved_connection_conn_secondary')),
      findsOneWidget,
    );
    expect(controller.state.isShowingSavedConnections, isTrue);
    expect(controller.state.selectedConnectionId, 'conn_primary');
  });

  testWidgets('overflow menu opens the dormant roster page', (tester) async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(buildShell(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved workspaces'));
    await tester.pumpAndSettle();

    expect(controller.state.isShowingSavedConnections, isTrue);
    expect(
      find.byKey(const ValueKey('saved_connections_page')),
      findsOneWidget,
    );
  });
}
