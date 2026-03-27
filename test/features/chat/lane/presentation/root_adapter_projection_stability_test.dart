import 'root_adapter_test_support.dart';

void main() {
  testWidgets('composer draft changes do not rebuild the session projection', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    final overlayDelegate = FakeChatRootOverlayDelegate();
    final presenter = CountingChatScreenPresenter();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(
      buildAdapterApp(
        appServerClient: appServerClient,
        overlayDelegate: overlayDelegate,
        screenPresenter: presenter,
      ),
    );
    await tester.pumpAndSettle();

    final initialSessionPresentCalls = presenter.presentSessionCalls;
    expect(initialSessionPresentCalls, greaterThan(0));
    await tester.enterText(
      find.byKey(const ValueKey('composer_input')),
      'Draft without transcript reprojection',
    );
    await tester.pump();

    expect(presenter.presentSessionCalls, initialSessionPresentCalls);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('composer_input')))
          .controller
          ?.text,
      'Draft without transcript reprojection',
    );
  });

  testWidgets(
    'transcript follow changes do not rebuild the session projection',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      final overlayDelegate = FakeChatRootOverlayDelegate();
      final presenter = CountingChatScreenPresenter();
      final laneBinding = buildLaneBinding(
        appServerClient: appServerClient,
        savedProfile: savedProfile(),
      );
      addTearDown(() async {
        laneBinding.dispose();
        await appServerClient.close();
      });

      await tester.pumpWidget(
        buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
          laneBinding: laneBinding,
          screenPresenter: presenter,
        ),
      );
      await tester.pumpAndSettle();

      final initialSessionPresentCalls = presenter.presentSessionCalls;
      expect(initialSessionPresentCalls, greaterThan(0));
      laneBinding.transcriptFollowHost.updateAutoFollowEligibility(
        isNearBottom: false,
      );
      await tester.pump();

      expect(presenter.presentSessionCalls, initialSessionPresentCalls);
      expect(
        laneBinding.transcriptFollowHost.contract.isAutoFollowEnabled,
        isFalse,
      );
    },
  );
}
