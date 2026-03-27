import 'root_adapter_test_support.dart';

void main() {
  testWidgets('clears adapter-owned draft state when dependencies rebind', (
    tester,
  ) async {
    final firstClient = FakeCodexAppServerClient();
    final secondClient = FakeCodexAppServerClient();
    final overlayDelegate = FakeChatRootOverlayDelegate();
    addTearDown(firstClient.close);
    addTearDown(secondClient.close);

    await tester.pumpWidget(
      buildAdapterApp(
        appServerClient: firstClient,
        overlayDelegate: overlayDelegate,
        savedProfile: savedProfile(),
      ),
    );
    await tester.pumpAndSettle();

    final composerField = find.byKey(const ValueKey('composer_input'));
    await tester.enterText(composerField, 'Stale draft');
    await tester.pump();

    await tester.pumpWidget(
      buildAdapterApp(
        appServerClient: secondClient,
        overlayDelegate: overlayDelegate,
        savedProfile: savedProfile(
          profile: configuredProfile().copyWith(
            label: 'Fresh Box',
            host: 'fresh.example.com',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(composerField).controller?.text, isEmpty);
  });

  testWidgets('ignores stale send completions after the adapter rebinds', (
    tester,
  ) async {
    final firstClient = FakeCodexAppServerClient()
      ..sendUserMessageGate = Completer<void>();
    final secondClient = FakeCodexAppServerClient();
    final overlayDelegate = FakeChatRootOverlayDelegate();
    addTearDown(firstClient.close);
    addTearDown(secondClient.close);

    await tester.pumpWidget(
      buildAdapterApp(
        appServerClient: firstClient,
        overlayDelegate: overlayDelegate,
        savedProfile: savedProfile(),
      ),
    );
    await tester.pumpAndSettle();

    final composerField = find.byKey(const ValueKey('composer_input'));
    await tester.enterText(composerField, 'Old prompt');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pump();

    await tester.pumpWidget(
      buildAdapterApp(
        appServerClient: secondClient,
        overlayDelegate: overlayDelegate,
        savedProfile: savedProfile(
          profile: configuredProfile().copyWith(
            label: 'Fresh Box',
            host: 'fresh.example.com',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(composerField, 'New draft');
    await tester.pump();

    firstClient.sendUserMessageGate?.complete();
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(composerField).controller?.text,
      'New draft',
    );
    expect(secondClient.sentMessages, isEmpty);
  });

  testWidgets(
    'keeps lane runtime alive when the adapter unmounts and remounts with the same binding',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      final overlayDelegate = FakeChatRootOverlayDelegate();
      final laneBinding = buildLaneBinding(
        appServerClient: appServerClient,
        savedProfile: savedProfile(),
      );
      addTearDown(appServerClient.close);
      addTearDown(laneBinding.dispose);

      await tester.pumpWidget(
        buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
          laneBinding: laneBinding,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('composer_input')),
        'Persistent draft',
      );
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();

      expect(appServerClient.disconnectCalls, 0);

      await tester.pumpWidget(
        buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
          laneBinding: laneBinding,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('composer_input')))
            .controller
            ?.text,
        'Persistent draft',
      );
    },
  );
}
