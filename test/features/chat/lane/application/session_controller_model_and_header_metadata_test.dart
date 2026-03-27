import 'session_controller_test_support.dart';

void main() {
  test(
    'sendPrompt forwards profile model and reasoning effort overrides',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final selectedProfile = configuredProfile().copyWith(
        model: 'gpt-5.4',
        reasoningEffort: CodexReasoningEffort.high,
      );
      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: selectedProfile,
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: selectedProfile,
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      expect(await controller.sendPrompt('Use the configured model'), isTrue);
      expect(appServerClient.startSessionRequests.single.model, 'gpt-5.4');
      expect(
        appServerClient.startSessionRequests.single.reasoningEffort,
        CodexReasoningEffort.high,
      );
      expect(appServerClient.sentTurns.single.model, 'gpt-5.4');
      expect(
        appServerClient.sentTurns.single.effort,
        CodexReasoningEffort.high,
      );
    },
  );

  test(
    'turn started notifications update live header effort for the root lane',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..startSessionModel = 'gpt-5.4';
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

      expect(await controller.sendPrompt('Observe live effort'), isTrue);

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

      await Future<void>.delayed(Duration.zero);

      expect(controller.sessionState.headerMetadata.model, 'gpt-5.4');
      expect(controller.sessionState.headerMetadata.reasoningEffort, 'high');
    },
  );

  test(
    'turn started notifications keep header effort in sync for reasoningEffort payloads',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..startSessionModel = 'gpt-5.4'
        ..startSessionReasoningEffort = 'medium';
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

      expect(await controller.sendPrompt('Observe live effort'), isTrue);
      expect(controller.sessionState.headerMetadata.reasoningEffort, 'medium');

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/started',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turn': <String, Object?>{
              'id': 'turn_1',
              'status': 'running',
              'model': 'gpt-5.4',
              'reasoningEffort': 'xhigh',
            },
          },
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(controller.sessionState.headerMetadata.model, 'gpt-5.4');
      expect(controller.sessionState.headerMetadata.reasoningEffort, 'xhigh');
    },
  );
}
