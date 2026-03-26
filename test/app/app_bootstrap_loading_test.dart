import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/flutter_chat_screen_renderer.dart';

import '../support/builders/app_test_harness.dart';

void main() {
  registerAppTestStorageLifecycle();

  testWidgets(
    'shows the material bootstrap shell while the catalog is loading on iOS',
    (tester) async {
      final connectionRepository = DeferredConnectionRepository();

      await tester.pumpWidget(
        buildCatalogApp(connectionRepository: connectionRepository),
      );
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Pocket Relay'), findsOneWidget);
      expect(
        find.text('Loading saved connections and workspace state.'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsOneWidget);

      connectionRepository.complete(testSavedProfile());
      await tester.pumpAndSettle();

      expect(find.byType(FlutterChatScreenRenderer), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'shows a retry action when workspace bootstrap initialization fails',
    (tester) async {
      final connectionRepository = FailOnceConnectionRepository(
        savedConnection: buildSavedConnection(),
      );

      await tester.pumpWidget(
        buildCatalogApp(connectionRepository: connectionRepository),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Pocket Relay could not finish loading your workspace.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('retry_workspace_bootstrap')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('retry_workspace_bootstrap')));
      await tester.pumpAndSettle();

      expect(find.byType(FlutterChatScreenRenderer), findsOneWidget);
      expect(connectionRepository.loadCatalogCalls, 2);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
