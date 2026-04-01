import 'session_controller_test_support.dart';

void main() {
  test('sendDraft forwards structured image input to the app server', () async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    final profile = configuredProfile();
    final controller = ChatSessionController(
      profileStore: MemoryCodexProfileStore(
        initialValue: SavedProfile(
          profile: profile,
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      ),
      appServerClient: appServerClient,
      initialSavedProfile: SavedProfile(
        profile: profile,
        secrets: const ConnectionSecrets(password: 'secret'),
      ),
    );
    addTearDown(controller.dispose);

    final sent = await controller.sendDraft(
      const ChatComposerDraft(
        text: 'See [Image #1]',
        textElements: <ChatComposerTextElement>[
          ChatComposerTextElement(start: 4, end: 14, placeholder: '[Image #1]'),
        ],
        imageAttachments: <ChatComposerImageAttachment>[
          ChatComposerImageAttachment(
            imageUrl: 'data:image/png;base64,cmVmZXJlbmNl',
            displayName: 'reference.png',
            placeholder: '[Image #1]',
          ),
        ],
      ),
    );

    expect(sent, isTrue);
    expect(appServerClient.startSessionCalls, 1);
    expect(
      controller.transcriptBlocks.first,
      isA<TranscriptUserMessageBlock>(),
    );
    final messageBlock =
        controller.transcriptBlocks.first as TranscriptUserMessageBlock;
    expect(
      messageBlock.draft,
      const ChatComposerDraft(
        text: 'See [Image #1]',
        textElements: <ChatComposerTextElement>[
          ChatComposerTextElement(start: 4, end: 14, placeholder: '[Image #1]'),
        ],
        imageAttachments: <ChatComposerImageAttachment>[
          ChatComposerImageAttachment(
            imageUrl: 'data:image/png;base64,cmVmZXJlbmNl',
            displayName: 'reference.png',
            placeholder: '[Image #1]',
          ),
        ],
      ),
    );
    expect(appServerClient.sentTurns.single, (
      threadId: 'thread_123',
      input: const CodexAppServerTurnInput(
        text: 'See [Image #1]',
        textElements: <CodexAppServerTextElement>[
          CodexAppServerTextElement(
            start: 4,
            end: 14,
            placeholder: '[Image #1]',
          ),
        ],
        images: <CodexAppServerImageInput>[
          CodexAppServerImageInput(url: 'data:image/png;base64,cmVmZXJlbmNl'),
        ],
      ),
      text: 'See [Image #1]',
      model: null,
      effort: null,
    ));
  });

  test(
    'sendDraft preserves image drafts when the selected model rejects image input',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);
      appServerClient.listedModels.add(
        const CodexAppServerModel(
          id: 'preset_text_only',
          model: 'gpt-text-only',
          displayName: 'GPT Text Only',
          description: '',
          hidden: false,
          supportedReasoningEfforts: <CodexAppServerReasoningEffortOption>[],
          defaultReasoningEffort: CodexReasoningEffort.medium,
          inputModalities: <String>['text'],
          supportsPersonality: false,
          isDefault: false,
        ),
      );

      final profile = configuredProfile().copyWith(model: 'gpt-text-only');
      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: profile,
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: profile,
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(seconds: 1),
      );
      final sent = await controller.sendDraft(
        const ChatComposerDraft(
          text: 'See [Image #1]',
          textElements: <ChatComposerTextElement>[
            ChatComposerTextElement(
              start: 4,
              end: 14,
              placeholder: '[Image #1]',
            ),
          ],
          imageAttachments: <ChatComposerImageAttachment>[
            ChatComposerImageAttachment(
              imageUrl: 'data:image/png;base64,cmVmZXJlbmNl',
              displayName: 'reference.png',
              placeholder: '[Image #1]',
            ),
          ],
        ),
      );

      expect(sent, isFalse);
      expect(appServerClient.connectCalls, 1);
      expect(appServerClient.listModelCalls, hasLength(1));
      expect(appServerClient.startSessionCalls, 0);
      expect(appServerClient.sentTurns, isEmpty);
      expect(controller.transcriptBlocks, isEmpty);
      expect(controller.currentModelSupportsImageInput, isFalse);
      expect(
        await snackBarMessage,
        '[${PocketErrorCatalog.chatSessionImageInputUnsupported.code}] Image input unsupported. Model gpt-text-only does not support image inputs. Remove images or switch models.',
      );
    },
  );

  test(
    'sendDraft blocks image input when the default catalog model is text-only',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);
      appServerClient.listedModels.add(
        const CodexAppServerModel(
          id: 'preset_default_text_only',
          model: 'gpt-default-text-only',
          displayName: 'GPT Default Text Only',
          description: '',
          hidden: false,
          supportedReasoningEfforts: <CodexAppServerReasoningEffortOption>[],
          defaultReasoningEffort: CodexReasoningEffort.medium,
          inputModalities: <String>['text'],
          supportsPersonality: false,
          isDefault: true,
        ),
      );

      final profile = configuredProfile().copyWith(model: '');
      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: profile,
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: profile,
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(seconds: 1),
      );
      final sent = await controller.sendDraft(
        const ChatComposerDraft(
          text: 'See [Image #1]',
          textElements: <ChatComposerTextElement>[
            ChatComposerTextElement(
              start: 4,
              end: 14,
              placeholder: '[Image #1]',
            ),
          ],
          imageAttachments: <ChatComposerImageAttachment>[
            ChatComposerImageAttachment(
              imageUrl: 'data:image/png;base64,cmVmZXJlbmNl',
              displayName: 'reference.png',
              placeholder: '[Image #1]',
            ),
          ],
        ),
      );

      expect(sent, isFalse);
      expect(appServerClient.connectCalls, 1);
      expect(appServerClient.listModelCalls, hasLength(1));
      expect(appServerClient.startSessionCalls, 0);
      expect(appServerClient.sentTurns, isEmpty);
      expect(controller.currentModelSupportsImageInput, isFalse);
      expect(
        await snackBarMessage,
        '[${PocketErrorCatalog.chatSessionImageInputUnsupported.code}] Image input unsupported. Model gpt-default-text-only does not support image inputs. Remove images or switch models.',
      );
    },
  );

  test(
    'sendDraft retries model catalog hydration after a transient listModels failure',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..listModelsError = StateError('temporary model list failure');
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

      expect(await controller.sendPrompt('Warm up the lane'), isTrue);
      final hydrationWarning = controller.transcriptBlocks
          .whereType<TranscriptStatusBlock>()
          .single;
      expect(hydrationWarning.statusKind, TranscriptStatusBlockKind.warning);
      expect(
        hydrationWarning.body,
        contains(
          '[${PocketErrorCatalog.chatSessionModelCatalogHydrationFailed.code}]',
        ),
      );
      expect(hydrationWarning.body, contains('temporary model list failure'));
      expect(appServerClient.listModelCalls, isEmpty);

      appServerClient.listModelsError = null;
      appServerClient.listedModels.add(
        const CodexAppServerModel(
          id: 'preset_session_text_only',
          model: 'gpt-5.3-codex',
          displayName: 'GPT Session Text Only',
          description: '',
          hidden: false,
          supportedReasoningEfforts: <CodexAppServerReasoningEffortOption>[],
          defaultReasoningEffort: CodexReasoningEffort.medium,
          inputModalities: <String>['text'],
          supportsPersonality: false,
          isDefault: false,
        ),
      );

      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(seconds: 1),
      );
      final sent = await controller.sendDraft(
        const ChatComposerDraft(
          text: 'See [Image #1]',
          textElements: <ChatComposerTextElement>[
            ChatComposerTextElement(
              start: 4,
              end: 14,
              placeholder: '[Image #1]',
            ),
          ],
          imageAttachments: <ChatComposerImageAttachment>[
            ChatComposerImageAttachment(
              imageUrl: 'data:image/png;base64,cmVmZXJlbmNl',
              displayName: 'reference.png',
              placeholder: '[Image #1]',
            ),
          ],
        ),
      );

      expect(sent, isFalse);
      expect(appServerClient.listModelCalls, hasLength(1));
      expect(appServerClient.startSessionCalls, 1);
      expect(appServerClient.sentTurns, hasLength(1));
      expect(controller.currentModelSupportsImageInput, isFalse);
      expect(
        await snackBarMessage,
        '[${PocketErrorCatalog.chatSessionImageInputUnsupported.code}] Image input unsupported. Model gpt-5.3-codex does not support image inputs. Remove images or switch models.',
      );
    },
  );

  test(
    'sendDraft gates image input against the configured model after a live session model mismatch',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..startSessionModel = 'gpt-5.4';
      addTearDown(appServerClient.close);
      appServerClient.listedModels.addAll(<CodexAppServerModel>[
        const CodexAppServerModel(
          id: 'preset_live_multimodal',
          model: 'gpt-5.4',
          displayName: 'GPT-5.4',
          description: '',
          hidden: false,
          supportedReasoningEfforts: <CodexAppServerReasoningEffortOption>[],
          defaultReasoningEffort: CodexReasoningEffort.medium,
          inputModalities: <String>['text', 'image'],
          supportsPersonality: false,
          isDefault: false,
        ),
        const CodexAppServerModel(
          id: 'preset_text_only',
          model: 'gpt-text-only',
          displayName: 'GPT Text Only',
          description: '',
          hidden: false,
          supportedReasoningEfforts: <CodexAppServerReasoningEffortOption>[],
          defaultReasoningEffort: CodexReasoningEffort.medium,
          inputModalities: <String>['text'],
          supportsPersonality: false,
          isDefault: false,
        ),
      ]);

      final profile = configuredProfile().copyWith(model: 'gpt-text-only');
      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: profile,
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: profile,
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      expect(await controller.sendPrompt('Warm up the lane'), isTrue);
      expect(controller.sessionState.headerMetadata.model, 'gpt-5.4');
      expect(controller.currentModelSupportsImageInput, isFalse);

      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(seconds: 1),
      );
      final sent = await controller.sendDraft(
        const ChatComposerDraft(
          text: 'See [Image #1]',
          textElements: <ChatComposerTextElement>[
            ChatComposerTextElement(
              start: 4,
              end: 14,
              placeholder: '[Image #1]',
            ),
          ],
          imageAttachments: <ChatComposerImageAttachment>[
            ChatComposerImageAttachment(
              imageUrl: 'data:image/png;base64,cmVmZXJlbmNl',
              displayName: 'reference.png',
              placeholder: '[Image #1]',
            ),
          ],
        ),
      );

      expect(sent, isFalse);
      expect(appServerClient.startSessionCalls, 1);
      expect(appServerClient.listModelCalls, hasLength(1));
      expect(appServerClient.sentTurns, hasLength(1));
      expect(appServerClient.sentTurns.single.model, 'gpt-text-only');
      expect(
        await snackBarMessage,
        '[${PocketErrorCatalog.chatSessionImageInputUnsupported.code}] Image input unsupported. Model gpt-text-only does not support image inputs. Remove images or switch models.',
      );
    },
  );
}
