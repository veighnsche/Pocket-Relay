import 'root_adapter_test_support.dart';

void main() {
  testWidgets('forwards connection settings requests through the callback', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    final requestedSettings = <ChatConnectionSettingsLaunchContract>[];
    final overlayDelegate = FakeChatRootOverlayDelegate();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(
      buildAdapterApp(
        appServerClient: appServerClient,
        overlayDelegate: overlayDelegate,
        onConnectionSettingsRequested: (payload) async {
          requestedSettings.add(payload);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Connection settings'));
    await tester.pumpAndSettle();

    expect(requestedSettings, hasLength(1));
    expect(requestedSettings.single.initialProfile, configuredProfile());
    expect(
      requestedSettings.single.initialSecrets,
      const ConnectionSecrets(password: 'secret'),
    );
    expect(appServerClient.disconnectCalls, 0);
  });

  testWidgets('routes feedback effects through the overlay delegate', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient()
      ..sendUserMessageError = StateError('transport broke');
    final overlayDelegate = FakeChatRootOverlayDelegate();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(
      buildAdapterApp(
        appServerClient: appServerClient,
        overlayDelegate: overlayDelegate,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('composer_input')),
      'Hello Codex',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pumpAndSettle();

    expect(overlayDelegate.transientFeedbackMessages, hasLength(1));
    expect(
      overlayDelegate.transientFeedbackMessages.single,
      contains('Could not send the prompt'),
    );
  });

  testWidgets(
    'sends prompts through the material composer path and clears the draft on success',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      final overlayDelegate = FakeChatRootOverlayDelegate();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      final composerField = find.byKey(const ValueKey('composer_input'));
      await tester.enterText(composerField, 'Hello Codex');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      expect(appServerClient.sentMessages, <String>['Hello Codex']);
      expect(tester.widget<TextField>(composerField).controller?.text, isEmpty);
    },
  );

  testWidgets(
    'retains the draft when sending fails through the material composer path',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient()
        ..sendUserMessageError = StateError('transport broke');
      final overlayDelegate = FakeChatRootOverlayDelegate();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      final composerField = find.byKey(const ValueKey('composer_input'));
      await tester.enterText(composerField, 'Hello Codex');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      expect(appServerClient.sentMessages, isEmpty);
      expect(
        tester.widget<TextField>(composerField).controller?.text,
        'Hello Codex',
      );
      expect(overlayDelegate.transientFeedbackMessages, hasLength(1));
    },
  );

  testWidgets('renders the material first-launch empty state on iOS', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(
      buildAdapterApp(
        appServerClient: appServerClient,
        overlayDelegate: const FlutterChatRootOverlayDelegate(),
        savedProfile: SavedProfile(
          profile: ConnectionProfile.defaults(),
          secrets: const ConnectionSecrets(),
        ),
        platformBehavior: PocketPlatformBehavior.resolve(
          platform: TargetPlatform.iOS,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Configure remote'),
      findsOneWidget,
    );
  });

  testWidgets(
    'renders supplemental empty-state content through the root adapter',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: const FlutterChatRootOverlayDelegate(),
          supplementalEmptyStateContent: const Text('Workspace controls'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workspace controls'), findsOneWidget);
    },
  );

  testWidgets(
    'desktop empty-state route selection seeds the settings payload',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final appServerClient = FakeCodexAppServerClient();
      final requestedConnectionSettings =
          <ChatConnectionSettingsLaunchContract>[];
      final overlayDelegate = FakeChatRootOverlayDelegate();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
          onConnectionSettingsRequested: (payload) async {
            requestedConnectionSettings.add(payload);
          },
          savedProfile: SavedProfile(
            profile: ConnectionProfile.defaults(),
            secrets: const ConnectionSecrets(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Local'));
      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();
      final configureButton = find.widgetWithText(
        FilledButton,
        'Configure connection',
      );
      await tester.ensureVisible(configureButton);
      await tester.tap(configureButton);
      await tester.pumpAndSettle();

      expect(requestedConnectionSettings, hasLength(1));
      expect(
        requestedConnectionSettings.single.initialProfile.connectionMode,
        ConnectionMode.local,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'routes changed-file diff openings through the overlay delegate',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      final overlayDelegate = FakeChatRootOverlayDelegate();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
        ),
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
              ],
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/diff/updated',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'diff':
                'diff --git a/README.md b/README.md\n'
                'new file mode 100644\n'
                '--- /dev/null\n'
                '+++ b/README.md\n'
                '@@ -0,0 +1,2 @@\n'
                '+first line\n'
                '+second line\n',
          },
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('README.md'));
      await tester.pump();

      expect(overlayDelegate.changedFileDiffs, hasLength(1));
      expect(
        overlayDelegate.changedFileDiffs.single.displayPathLabel,
        'README.md',
      );
    },
  );

  testWidgets('routes command terminal openings through the overlay delegate', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    final overlayDelegate = FakeChatRootOverlayDelegate();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(
      buildAdapterApp(
        appServerClient: appServerClient,
        overlayDelegate: overlayDelegate,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

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
            'command': 'pwd',
            'processId': 'proc_1',
            'aggregatedOutput': '/repo\n',
            'exitCode': 0,
          },
        },
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('pwd'));
    await tester.pump();

    expect(overlayDelegate.workLogTerminals, hasLength(1));
    expect(overlayDelegate.workLogTerminals.single.commandText, 'pwd');
    expect(overlayDelegate.workLogTerminals.single.processId, 'proc_1');
    expect(overlayDelegate.workLogTerminals.single.terminalOutput, '/repo\n');
  });

  testWidgets(
    'renders through the material shell foundation on every platform',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      final overlayDelegate = FakeChatRootOverlayDelegate();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterChatScreenRenderer), findsOneWidget);
      expect(find.byType(FlutterChatAppChrome), findsOneWidget);
      expect(find.byType(FlutterChatTranscriptRegion), findsOneWidget);
      expect(find.byType(FlutterChatComposerRegion), findsOneWidget);
    },
  );
}
