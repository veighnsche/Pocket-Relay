import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/features/chat/application/chat_session_controller.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

import 'support/fake_codex_app_server_client.dart';

void main() {
  test('sendPrompt runs session flow without ChatScreen', () async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    final controller = ChatSessionController(
      profileStore: MemoryCodexProfileStore(
        initialValue: SavedProfile(
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      ),
      appServerClient: appServerClient,
      initialSavedProfile: SavedProfile(
        profile: _configuredProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      ),
    );
    addTearDown(controller.dispose);

    final sent = await controller.sendPrompt('Hello controller');

    expect(sent, isTrue);
    expect(appServerClient.connectCalls, 1);
    expect(appServerClient.startSessionCalls, 1);
    expect(appServerClient.sentMessages, <String>['Hello controller']);
    expect(controller.transcriptBlocks.length, 1);
    expect(controller.transcriptBlocks.first, isA<CodexUserMessageBlock>());
    final messageBlock =
        controller.transcriptBlocks.first as CodexUserMessageBlock;
    expect(messageBlock.text, 'Hello controller');
    expect(messageBlock.deliveryState, CodexUserMessageDeliveryState.sent);
  });

  test('invalid prompt submission emits snackbar feedback', () async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    final controller = ChatSessionController(
      profileStore: MemoryCodexProfileStore(
        initialValue: SavedProfile(
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(),
        ),
      ),
      appServerClient: appServerClient,
      initialSavedProfile: SavedProfile(
        profile: _configuredProfile(),
        secrets: const ConnectionSecrets(),
      ),
    );
    addTearDown(controller.dispose);

    final snackBarMessage = controller.snackBarMessages.first.timeout(
      const Duration(seconds: 1),
    );

    final sent = await controller.sendPrompt('Needs credentials');

    expect(sent, isFalse);
    expect(await snackBarMessage, 'This profile needs an SSH password.');
    expect(appServerClient.sentMessages, isEmpty);
  });

  test(
    'local mode is rejected when desktop-local support is unavailable',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final localProfile = _configuredProfile().copyWith(
        connectionMode: ConnectionMode.local,
        host: '',
        username: '',
      );
      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: localProfile,
            secrets: const ConnectionSecrets(),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: localProfile,
          secrets: const ConnectionSecrets(),
        ),
        supportsLocalConnectionMode: false,
      );
      addTearDown(controller.dispose);

      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(seconds: 1),
      );

      final sent = await controller.sendPrompt('Hello local');

      expect(sent, isFalse);
      expect(
        await snackBarMessage,
        'Local Codex is only available on desktop.',
      );
      expect(appServerClient.connectCalls, 0);
    },
  );

  test(
    'sendPrompt clears local prompt correlation state when sending fails before a turn starts',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..sendUserMessageError = StateError('transport broke');
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(seconds: 1),
      );

      final sent = await controller.sendPrompt('Hello controller');

      expect(sent, isFalse);
      expect(controller.transcriptBlocks.first, isA<CodexUserMessageBlock>());
      expect(controller.sessionState.pendingLocalUserMessageBlockIds, isEmpty);
      expect(controller.sessionState.localUserMessageProviderBindings, isEmpty);
      expect(
        await snackBarMessage,
        'Could not send the prompt to the remote Codex session.',
      );
    },
  );

  test(
    'sendPrompt reuses the response-owned thread before thread notifications arrive',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      expect(await controller.sendPrompt('First prompt'), isTrue);
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turn': <String, Object?>{'id': 'turn_1', 'status': 'completed'},
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(await controller.sendPrompt('Second prompt'), isTrue);
      expect(appServerClient.startSessionCalls, 1);
      expect(appServerClient.sentMessages, <String>[
        'First prompt',
        'Second prompt',
      ]);
    },
  );

  test(
    'startFreshConversation clears the response-owned resume thread',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      expect(await controller.sendPrompt('First prompt'), isTrue);
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turn': <String, Object?>{'id': 'turn_1', 'status': 'completed'},
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      controller.startFreshConversation();

      expect(await controller.sendPrompt('Second prompt'), isTrue);
      expect(appServerClient.startSessionCalls, 2);
    },
  );

  test(
    'saveObservedHostFingerprint persists the prompt without disconnecting the active session',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);
      final profileStore = MemoryCodexProfileStore(
        initialValue: SavedProfile(
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );

      final controller = ChatSessionController(
        profileStore: profileStore,
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      expect(await controller.sendPrompt('Hello controller'), isTrue);

      appServerClient.emit(
        const CodexAppServerUnpinnedHostKeyEvent(
          host: 'example.com',
          port: 22,
          keyType: 'ssh-ed25519',
          fingerprint: '7a:9f:d7:dc:2e:f2',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final block = controller.transcriptBlocks
          .whereType<CodexSshUnpinnedHostKeyBlock>()
          .single;

      await controller.saveObservedHostFingerprint(block.id);

      expect(appServerClient.isConnected, isTrue);
      expect(controller.profile.hostFingerprint, '7a:9f:d7:dc:2e:f2');
      expect(
        (await profileStore.load()).profile.hostFingerprint,
        '7a:9f:d7:dc:2e:f2',
      );
      expect(
        controller.transcriptBlocks
            .whereType<CodexSshUnpinnedHostKeyBlock>()
            .single
            .isSaved,
        isTrue,
      );
    },
  );

  test(
    'sendPrompt suppresses duplicate generic transcript errors when SSH bootstrap already surfaced a typed failure',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..connectEventsBeforeThrow.add(
          const CodexAppServerSshConnectFailedEvent(
            host: 'example.com',
            port: 22,
            message: 'Connection refused',
          ),
        )
        ..connectError = StateError('connect failed after transport event');
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(seconds: 1),
      );

      final sent = await controller.sendPrompt('Hello controller');

      expect(sent, isFalse);
      final errors = controller.transcriptBlocks
          .whereType<CodexSshConnectFailedBlock>()
          .toList(growable: false);
      expect(errors, hasLength(1));
      expect(errors.single.message, contains('Connection refused'));
      expect(
        await snackBarMessage,
        'Could not send the prompt to the remote Codex session.',
      );
    },
  );
}

ConnectionProfile _configuredProfile() {
  return ConnectionProfile.defaults().copyWith(
    host: 'example.com',
    username: 'vince',
  );
}
