import 'session_controller_test_support.dart';

void main() {
  test(
    'saveObservedHostFingerprint persists the prompt without disconnecting the active session',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);
      final profileStore = MemoryCodexProfileStore(
        initialValue: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );

      final controller = ChatSessionController(
        profileStore: profileStore,
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile(),
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
    'saveObservedHostFingerprint reports feedback when the prompt is no longer available',
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

      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(seconds: 1),
      );

      await controller.saveObservedHostFingerprint('missing_block');

      expect(
        await snackBarMessage,
        '[${PocketErrorCatalog.chatSessionHostFingerprintPromptUnavailable.code}] Host fingerprint unavailable. This host fingerprint prompt is no longer available.',
      );
      expect(controller.profile.hostFingerprint, isEmpty);
    },
  );

  test(
    'saveObservedHostFingerprint reports feedback when persisting the prompt fails',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: _FailingCodexProfileStore(
          SavedProfile(
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
      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(seconds: 1),
      );

      await controller.saveObservedHostFingerprint(block.id);

      expect(
        await snackBarMessage,
        '[${PocketErrorCatalog.chatSessionHostFingerprintSaveFailed.code}] Host fingerprint save failed. Could not save the host fingerprint to this profile.',
      );
      expect(controller.profile.hostFingerprint, isEmpty);
      expect(
        controller.transcriptBlocks
            .whereType<CodexSshUnpinnedHostKeyBlock>()
            .single
            .isSaved,
        isFalse,
      );
    },
  );

  test(
    'sendPrompt suppresses duplicate generic failures when an unpinned host key prompt already surfaced',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..connectEventsBeforeThrow.add(
          const CodexAppServerUnpinnedHostKeyEvent(
            host: 'example.com',
            port: 22,
            keyType: 'ssh-ed25519',
            fingerprint: '7a:9f:d7:dc:2e:f2',
          ),
        )
        ..connectError = StateError('connect failed after host key prompt');
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

      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(milliseconds: 100),
      );

      final sent = await controller.sendPrompt('Hello controller');

      expect(sent, isFalse);
      expect(
        controller.transcriptBlocks.whereType<CodexSshUnpinnedHostKeyBlock>(),
        hasLength(1),
      );
      expect(controller.transcriptBlocks.whereType<CodexErrorBlock>(), isEmpty);
      await expectLater(snackBarMessage, throwsA(isA<TimeoutException>()));
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
        '[${PocketErrorCatalog.chatSessionSendFailed.code}] Send failed. Could not send the prompt to the remote Codex session.',
      );
    },
  );

  test(
    'reopens changed-files output as a new transcript block after approval resolves',
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
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'file_change_1',
              'type': 'fileChange',
              'status': 'inProgress',
              'changes': <Object?>[
                <String, Object?>{
                  'path': 'README.md',
                  'kind': <String, Object?>{'type': 'add'},
                  'diff': 'first line\n',
                },
              ],
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 'i:99',
          method: 'item/fileChange/requestApproval',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'file_change_1',
            'reason': 'Write files',
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'serverRequest/resolved',
          params: <String, Object?>{'threadId': 'thread_123', 'requestId': 99},
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
                  'diff': 'first line\n',
                },
                <String, Object?>{
                  'path': 'lib/app.dart',
                  'kind': <String, Object?>{'type': 'update'},
                  'diff':
                      '--- a/lib/app.dart\n'
                      '+++ b/lib/app.dart\n'
                      '@@ -1 +1 @@\n'
                      '-old\n'
                      '+new\n',
                },
              ],
            },
          },
        ),
      );

      await Future<void>.delayed(Duration.zero);

      final changedFilesBlocks = controller.transcriptBlocks
          .whereType<CodexChangedFilesBlock>()
          .toList(growable: false);

      expect(changedFilesBlocks, hasLength(2));
      expect(
        changedFilesBlocks.map((block) => block.id).toList(growable: false),
        <String>[
          'changed_files_group_item_file_change_1',
          'changed_files_group_item_file_change_1-2',
        ],
      );
      expect(changedFilesBlocks.first.files.single.path, 'README.md');
      expect(changedFilesBlocks.last.files, hasLength(2));
      expect(
        controller.transcriptBlocks.whereType<CodexApprovalRequestBlock>(),
        isNotEmpty,
      );
    },
  );
}

final class _FailingCodexProfileStore implements CodexProfileStore {
  _FailingCodexProfileStore(this.initialValue);

  final SavedProfile initialValue;

  @override
  Future<SavedProfile> load() async => initialValue;

  @override
  Future<void> save(
    ConnectionProfile profile,
    ConnectionSecrets secrets,
  ) async {
    throw StateError('profile save failed');
  }
}
