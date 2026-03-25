import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_controller.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';

import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';

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
    expect(appServerClient.startSessionRequests.single.model, isNull);
    expect(appServerClient.startSessionRequests.single.reasoningEffort, isNull);
    expect(appServerClient.sentMessages, <String>['Hello controller']);
    expect(controller.transcriptBlocks.length, 1);
    expect(controller.transcriptBlocks.first, isA<CodexUserMessageBlock>());
    expect(controller.sessionState.headerMetadata.cwd, '/workspace');
    expect(controller.sessionState.headerMetadata.model, 'gpt-5.3-codex');
    final messageBlock =
        controller.transcriptBlocks.first as CodexUserMessageBlock;
    expect(messageBlock.text, 'Hello controller');
    expect(messageBlock.deliveryState, CodexUserMessageDeliveryState.sent);
  });

  test('sendPrompt allows steering while a turn is already running', () async {
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

    final sentWhileRunning = await controller.sendPrompt('Steer the agent');

    expect(sentWhileRunning, isTrue);
    expect(appServerClient.startSessionCalls, 1);
    expect(appServerClient.sentMessages, <String>[
      'First prompt',
      'Steer the agent',
    ]);
  });

  test('sendDraft forwards structured image input to the app server', () async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    final profile = _configuredProfile();
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
    expect(controller.transcriptBlocks.first, isA<CodexUserMessageBlock>());
    final messageBlock =
        controller.transcriptBlocks.first as CodexUserMessageBlock;
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

      final profile = _configuredProfile().copyWith(model: 'gpt-text-only');
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
        'Model gpt-text-only does not support image inputs. Remove images or switch models.',
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

      final profile = _configuredProfile().copyWith(model: '');
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
        'Model gpt-default-text-only does not support image inputs. Remove images or switch models.',
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

      expect(await controller.sendPrompt('Warm up the lane'), isTrue);
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
        'Model gpt-5.3-codex does not support image inputs. Remove images or switch models.',
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

      final profile = _configuredProfile().copyWith(model: 'gpt-text-only');
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
        'Model gpt-text-only does not support image inputs. Remove images or switch models.',
      );
    },
  );

  test(
    'sendPrompt starts a fresh conversation after controller restart until history is explicitly picked',
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

      expect(await controller.sendPrompt('Continue after restart'), isTrue);
      expect(appServerClient.startSessionCalls, 1);
      expect(appServerClient.sentTurns, <
        ({
          String threadId,
          CodexAppServerTurnInput input,
          String text,
          String? model,
          CodexReasoningEffort? effort,
        })
      >[
        (
          threadId: 'thread_123',
          input: const CodexAppServerTurnInput.text('Continue after restart'),
          text: 'Continue after restart',
          model: null,
          effort: null,
        ),
      ]);
      expect(
        appServerClient.startSessionRequests.single.resumeThreadId,
        isNull,
      );
    },
  );

  test(
    'initialize keeps a fresh lane empty until history is explicitly picked',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = _savedConversationThread(
          threadId: 'thread_saved',
        );
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

      await controller.initialize();

      expect(appServerClient.startSessionCalls, 0);
      expect(appServerClient.connectCalls, 0);
      expect(appServerClient.readThreadCalls, isEmpty);
      expect(controller.transcriptBlocks, isEmpty);
      expect(controller.sessionState.rootThreadId, isNull);
      expect(controller.historicalConversationRestoreState, isNull);
    },
  );

  test(
    'sendPrompt stays fresh after initialize until history is explicitly picked',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = _savedConversationThread(
          threadId: 'thread_saved',
        );
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

      await controller.initialize();

      expect(
        await controller.sendPrompt('Continue restored startup lane'),
        isTrue,
      );
      expect(appServerClient.startSessionCalls, 1);
      expect(
        appServerClient.startSessionRequests.single.resumeThreadId,
        isNull,
      );
      expect(appServerClient.sentTurns.single, (
        threadId: 'thread_123',
        input: const CodexAppServerTurnInput.text(
          'Continue restored startup lane',
        ),
        text: 'Continue restored startup lane',
        model: null,
        effort: null,
      ));
    },
  );

  test(
    'continueFromUserMessage rolls back the active conversation and returns the selected prompt text',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = _savedConversationThread(
          threadId: 'thread_saved',
        );
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

      await controller.initialize();
      await controller.selectConversationForResume('thread_saved');
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>().map(
          (b) => b.text,
        ),
        <String>['Restore this', 'Second prompt'],
      );

      appServerClient.threadHistoriesById['thread_saved'] =
          _rewoundConversationThread(threadId: 'thread_saved');

      final selectedBlock = controller.transcriptBlocks
          .whereType<CodexUserMessageBlock>()
          .firstWhere((block) => block.text == 'Restore this');

      final draft = await controller.continueFromUserMessage(selectedBlock.id);

      expect(draft?.text, 'Restore this');
      expect(
        appServerClient.rollbackThreadCalls,
        <({String threadId, int numTurns})>[
          (threadId: 'thread_saved', numTurns: 2),
        ],
      );
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>(),
        isEmpty,
      );
      expect(
        controller.transcriptBlocks.whereType<CodexTextBlock>().map(
          (b) => b.body,
        ),
        <String>['Earlier answer only'],
      );
      expect(controller.sessionState.rootThreadId, 'thread_saved');
      expect(controller.historicalConversationRestoreState, isNull);
    },
  );

  test(
    'continueFromUserMessage refuses to rewind while a turn is active',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = _savedConversationThread(
          threadId: 'thread_saved',
        );
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

      await controller.initialize();
      await controller.selectConversationForResume('thread_saved');
      expect(await controller.sendPrompt('Keep running'), isTrue);

      final selectedBlock = controller.transcriptBlocks
          .whereType<CodexUserMessageBlock>()
          .firstWhere((block) => block.text == 'Restore this');

      final draft = await controller.continueFromUserMessage(selectedBlock.id);

      expect(draft, isNull);
      expect(appServerClient.rollbackThreadCalls, isEmpty);
    },
  );

  test(
    'continueFromUserMessage keeps the transcript intact and reports feedback when rollback fails',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = _savedConversationThread(
          threadId: 'thread_saved',
        )
        ..rollbackThreadError = StateError('transport broke');
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

      await controller.initialize();
      await controller.selectConversationForResume('thread_saved');
      final originalUserTexts = controller.transcriptBlocks
          .whereType<CodexUserMessageBlock>()
          .map((block) => block.text)
          .toList(growable: false);
      final originalAssistantTexts = controller.transcriptBlocks
          .whereType<CodexTextBlock>()
          .map((block) => block.body)
          .toList(growable: false);
      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(seconds: 1),
      );

      final selectedBlock = controller.transcriptBlocks
          .whereType<CodexUserMessageBlock>()
          .firstWhere((block) => block.text == 'Restore this');

      final draft = await controller.continueFromUserMessage(selectedBlock.id);

      expect(draft, isNull);
      expect(
        appServerClient.rollbackThreadCalls,
        <({String threadId, int numTurns})>[
          (threadId: 'thread_saved', numTurns: 2),
        ],
      );
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>().map(
          (block) => block.text,
        ),
        originalUserTexts,
      );
      expect(
        controller.transcriptBlocks.whereType<CodexTextBlock>().map(
          (block) => block.body,
        ),
        originalAssistantTexts,
      );
      expect(
        await snackBarMessage,
        'Could not rewind this conversation to the selected prompt.',
      );
    },
  );

  test('continueFromUserMessage restores a structured image draft', () async {
    final appServerClient = FakeCodexAppServerClient()
      ..threadHistoriesById['thread_123'] = _rewoundConversationThread(
        threadId: 'thread_123',
      );
    addTearDown(appServerClient.close);

    final profile = _configuredProfile();
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

    expect(
      await controller.sendDraft(
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
      ),
      isTrue,
    );

    final selectedBlock = controller.transcriptBlocks
        .whereType<CodexUserMessageBlock>()
        .single;
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

    final draft = await controller.continueFromUserMessage(selectedBlock.id);

    expect(
      draft,
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
  });

  test(
    'branchSelectedConversation forks the selected conversation and restores the forked history',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = _savedConversationThread(
          threadId: 'thread_saved',
        )
        ..forkThreadId = 'thread_forked'
        ..threadHistoriesById['thread_forked'] = _savedConversationThread(
          threadId: 'thread_forked',
        );
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

      await controller.initialize();
      await controller.selectConversationForResume('thread_saved');

      final branched = await controller.branchSelectedConversation();

      expect(branched, isTrue);
      expect(appServerClient.forkThreadRequests.single, (
        threadId: 'thread_saved',
        path: null,
        cwd: null,
        model: null,
        modelProvider: null,
        ephemeral: null,
        persistExtendedHistory: true,
      ));
      expect(appServerClient.readThreadCalls.last, 'thread_forked');
      expect(controller.sessionState.rootThreadId, 'thread_forked');
      expect(controller.sessionState.currentThreadId, 'thread_forked');
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>().map(
          (block) => block.text,
        ),
        <String>['Restore this', 'Second prompt'],
      );
    },
  );

  test(
    'branchSelectedConversation refuses to fork while a turn is active',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = _savedConversationThread(
          threadId: 'thread_saved',
        );
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

      await controller.initialize();
      await controller.selectConversationForResume('thread_saved');
      expect(await controller.sendPrompt('Keep running'), isTrue);

      final branched = await controller.branchSelectedConversation();

      expect(branched, isFalse);
      expect(appServerClient.forkThreadRequests, isEmpty);
    },
  );

  test(
    'branchSelectedConversation keeps the transcript intact and reports feedback when fork fails',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = _savedConversationThread(
          threadId: 'thread_saved',
        )
        ..forkThreadError = StateError('fork broke');
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

      await controller.initialize();
      await controller.selectConversationForResume('thread_saved');
      final originalUserTexts = controller.transcriptBlocks
          .whereType<CodexUserMessageBlock>()
          .map((block) => block.text)
          .toList(growable: false);
      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(seconds: 1),
      );

      final branched = await controller.branchSelectedConversation();

      expect(branched, isFalse);
      expect(appServerClient.forkThreadRequests, isEmpty);
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>().map(
          (block) => block.text,
        ),
        originalUserTexts,
      );
      expect(
        await snackBarMessage,
        'Could not branch this conversation from Codex.',
      );
    },
  );

  test(
    'initialize ignores unavailable history until the user explicitly resumes',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_empty'] =
            const CodexAppServerThreadHistory(
              id: 'thread_empty',
              name: 'Empty conversation',
              sourceKind: 'app-server',
              turns: <CodexAppServerHistoryTurn>[],
            );
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

      await controller.initialize();

      expect(appServerClient.startSessionCalls, 0);
      expect(appServerClient.connectCalls, 0);
      expect(appServerClient.readThreadCalls, isEmpty);
      expect(controller.historicalConversationRestoreState, isNull);
      expect(controller.sessionState.rootThreadId, isNull);
      expect(controller.transcriptBlocks, isEmpty);
      expect(await controller.sendPrompt('stay fresh after startup'), isTrue);
      expect(
        appServerClient.startSessionRequests.single.resumeThreadId,
        isNull,
      );
      expect(appServerClient.sentTurns.single, (
        threadId: 'thread_123',
        input: const CodexAppServerTurnInput.text('stay fresh after startup'),
        text: 'stay fresh after startup',
        model: null,
        effort: null,
      ));
    },
  );

  test(
    'selectConversationForResume hydrates the saved conversation transcript',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadsById['thread_saved'] = _savedConversationThread(
          threadId: 'thread_saved',
        );
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

      await controller.selectConversationForResume('thread_saved');

      expect(appServerClient.connectCalls, 1);
      expect(appServerClient.readThreadCalls, <String>['thread_saved']);
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>().map(
          (block) => block.text,
        ),
        contains('Restore this'),
      );
      expect(
        controller.transcriptBlocks.whereType<CodexTextBlock>().map(
          (block) => block.body,
        ),
        contains('Restored answer'),
      );
      expect(controller.sessionState.rootThreadId, 'thread_saved');
    },
  );

  test(
    'reattachConversation resumes the same thread without rereading transcript history',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = _savedConversationThread(
          threadId: 'thread_saved',
        );
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

      await controller.selectConversationForResume('thread_saved');
      final restoredUserTexts = controller.transcriptBlocks
          .whereType<CodexUserMessageBlock>()
          .map((block) => block.text)
          .toList(growable: false);
      final restoredAssistantTexts = controller.transcriptBlocks
          .whereType<CodexTextBlock>()
          .map((block) => block.body)
          .toList(growable: false);

      appServerClient.readThreadCalls.clear();
      appServerClient.startSessionCalls = 0;
      appServerClient.startSessionRequests.clear();

      await controller.reattachConversation('thread_saved');

      expect(appServerClient.readThreadCalls, isEmpty);
      expect(appServerClient.startSessionCalls, 1);
      expect(
        appServerClient.startSessionRequests.single.resumeThreadId,
        'thread_saved',
      );
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>().map(
          (block) => block.text,
        ),
        restoredUserTexts,
      );
      expect(
        controller.transcriptBlocks.whereType<CodexTextBlock>().map(
          (block) => block.body,
        ),
        restoredAssistantTexts,
      );
      expect(controller.sessionState.rootThreadId, 'thread_saved');
      expect(controller.historicalConversationRestoreState, isNull);
    },
  );

  test(
    'reattachConversation seeds live thread identity without hydrating transcript history when the lane is empty',
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

      await controller.initialize();
      await controller.reattachConversation('thread_live');

      expect(appServerClient.connectCalls, 1);
      expect(appServerClient.readThreadCalls, <String>['thread_live']);
      expect(appServerClient.startSessionCalls, 1);
      expect(
        appServerClient.startSessionRequests.single.resumeThreadId,
        'thread_live',
      );
      expect(controller.sessionState.rootThreadId, 'thread_live');
      expect(controller.sessionState.currentThreadId, 'thread_live');
      expect(controller.transcriptBlocks, isEmpty);
      expect(controller.historicalConversationRestoreState, isNull);
    },
  );

  test(
    'reattachConversation replays pending user input requests so they remain actionable after reconnect',
    () async {
      const replayedRequest = CodexAppServerRequestEvent(
        requestId: 'input_1',
        method: 'item/tool/requestUserInput',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'itemId': 'item_1',
          'questions': <Object?>[
            <String, Object?>{
              'id': 'q1',
              'header': 'Name',
              'question': 'What is your name?',
            },
          ],
        },
      );
      final appServerClient = FakeCodexAppServerClient()
        ..resumeThreadReplayEventsByThreadId['thread_123'] =
            <CodexAppServerEvent>[replayedRequest];
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
      appServerClient.emit(replayedRequest);
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.sessionState.pendingUserInputRequests.containsKey('input_1'),
        isTrue,
      );

      await appServerClient.disconnect();
      await controller.reattachConversation('thread_123');
      await controller.submitUserInput('input_1', const <String, List<String>>{
        'q1': <String>['Vince'],
      });

      expect(
        appServerClient.userInputResponses,
        <({String requestId, Map<String, List<String>> answers})>[
          (
            requestId: 'input_1',
            answers: const <String, List<String>>{
              'q1': <String>['Vince'],
            },
          ),
        ],
      );
    },
  );

  test(
    'reattachConversation replays pending approval requests so they remain actionable after reconnect',
    () async {
      const replayedRequest = CodexAppServerRequestEvent(
        requestId: 'approval_1',
        method: 'item/permissions/requestApproval',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'itemId': 'item_approval_1',
          'message': 'Need permission to continue.',
        },
      );
      final appServerClient = FakeCodexAppServerClient()
        ..resumeThreadReplayEventsByThreadId['thread_123'] =
            <CodexAppServerEvent>[replayedRequest];
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
      appServerClient.emit(replayedRequest);
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.sessionState.pendingApprovalRequests.containsKey(
          'approval_1',
        ),
        isTrue,
      );

      await appServerClient.disconnect();
      await controller.reattachConversation('thread_123');
      await controller.approveRequest('approval_1');

      expect(
        appServerClient.approvalDecisions,
        <({String requestId, bool approved})>[
          (requestId: 'approval_1', approved: true),
        ],
      );
    },
  );

  test(
    'sendPrompt resumes the restored conversation after selectConversationForResume',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = _savedConversationThread(
          threadId: 'thread_saved',
        );
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

      await controller.selectConversationForResume('thread_saved');

      expect(
        await controller.sendPrompt('Continue restored conversation'),
        isTrue,
      );
      expect(appServerClient.startSessionCalls, 1);
      expect(
        appServerClient.startSessionRequests.single.resumeThreadId,
        'thread_saved',
      );
      expect(appServerClient.sentTurns, <
        ({
          String threadId,
          CodexAppServerTurnInput input,
          String text,
          String? model,
          CodexReasoningEffort? effort,
        })
      >[
        (
          threadId: 'thread_saved',
          input: const CodexAppServerTurnInput.text(
            'Continue restored conversation',
          ),
          text: 'Continue restored conversation',
          model: null,
          effort: null,
        ),
      ]);
    },
  );

  test(
    'selectConversationForResume exposes restore loading while transcript history is still in flight',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = _savedConversationThread(
          threadId: 'thread_saved',
        )
        ..readThreadWithTurnsGate = Completer<void>();
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

      final loadingReached = Completer<void>();
      controller.addListener(() {
        if (controller.historicalConversationRestoreState?.phase ==
                ChatHistoricalConversationRestorePhase.loading &&
            !loadingReached.isCompleted) {
          loadingReached.complete();
        }
      });

      final restoreFuture = controller.selectConversationForResume(
        'thread_saved',
      );
      await loadingReached.future.timeout(const Duration(seconds: 1));

      expect(
        controller.historicalConversationRestoreState?.phase,
        ChatHistoricalConversationRestorePhase.loading,
      );
      expect(await controller.sendPrompt('blocked while restoring'), isFalse);

      appServerClient.readThreadWithTurnsGate!.complete();
      await restoreFuture;

      expect(controller.historicalConversationRestoreState, isNull);
    },
  );

  test(
    'the latest explicit history selection wins if an earlier restore completes later',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_old'] = _savedConversationThread(
          threadId: 'thread_old',
        )
        ..threadHistoriesById['thread_new'] = _savedConversationThread(
          threadId: 'thread_new',
        )
        ..readThreadWithTurnsGatesByThreadId['thread_old'] = Completer<void>()
        ..readThreadWithTurnsGatesByThreadId['thread_new'] = Completer<void>();
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

      final firstRestore = controller.selectConversationForResume('thread_old');
      await Future<void>.delayed(Duration.zero);

      final secondRestore = controller.selectConversationForResume(
        'thread_new',
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.historicalConversationRestoreState?.threadId,
        'thread_new',
      );

      appServerClient.readThreadWithTurnsGatesByThreadId['thread_new']!
          .complete();
      await secondRestore;

      expect(controller.sessionState.rootThreadId, 'thread_new');
      expect(controller.historicalConversationRestoreState, isNull);

      appServerClient.readThreadWithTurnsGatesByThreadId['thread_old']!
          .complete();
      await firstRestore;

      expect(controller.sessionState.rootThreadId, 'thread_new');
      expect(controller.historicalConversationRestoreState, isNull);
    },
  );

  test(
    'startFreshConversation invalidates an in-flight history restore',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = _savedConversationThread(
          threadId: 'thread_saved',
        )
        ..readThreadWithTurnsGatesByThreadId['thread_saved'] =
            Completer<void>();
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

      final restoreFuture = controller.selectConversationForResume(
        'thread_saved',
      );
      await Future<void>.delayed(Duration.zero);

      controller.startFreshConversation();

      expect(controller.historicalConversationRestoreState, isNull);
      expect(controller.sessionState.rootThreadId, isNull);

      appServerClient.readThreadWithTurnsGatesByThreadId['thread_saved']!
          .complete();
      await restoreFuture;

      expect(controller.historicalConversationRestoreState, isNull);
      expect(controller.sessionState.rootThreadId, isNull);

      expect(
        await controller.sendPrompt('Fresh after cancelled restore'),
        isTrue,
      );
      expect(
        appServerClient.startSessionRequests.single.resumeThreadId,
        isNull,
      );
    },
  );

  test(
    'startFreshConversation refuses to reset while a turn is active',
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

      expect(await controller.sendPrompt('Keep running'), isTrue);
      final originalRootThreadId = controller.sessionState.rootThreadId;
      final originalUserTexts = controller.transcriptBlocks
          .whereType<CodexUserMessageBlock>()
          .map((block) => block.text)
          .toList(growable: false);
      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(seconds: 1),
      );

      controller.startFreshConversation();

      expect(controller.sessionState.rootThreadId, originalRootThreadId);
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>().map(
          (block) => block.text,
        ),
        originalUserTexts,
      );
      expect(
        controller.transcriptBlocks.whereType<CodexStatusBlock>(),
        isEmpty,
      );
      expect(
        await snackBarMessage,
        'Stop the active turn before starting a new thread.',
      );
    },
  );

  test(
    'selectConversationForResume surfaces unavailable transcript history instead of silently restoring an empty lane',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_empty'] =
            const CodexAppServerThreadHistory(
              id: 'thread_empty',
              name: 'Empty conversation',
              sourceKind: 'app-server',
              turns: <CodexAppServerHistoryTurn>[],
            );
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

      await controller.selectConversationForResume('thread_empty');

      expect(
        controller.historicalConversationRestoreState?.phase,
        ChatHistoricalConversationRestorePhase.unavailable,
      );
      expect(controller.sessionState.rootThreadId, 'thread_empty');
      expect(controller.transcriptBlocks, isEmpty);
      expect(
        await controller.sendPrompt('blocked after empty restore'),
        isFalse,
      );
    },
  );

  test(
    'sendPrompt forwards profile model and reasoning effort overrides',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final configuredProfile = _configuredProfile().copyWith(
        model: 'gpt-5.4',
        reasoningEffort: CodexReasoningEffort.high,
      );
      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile,
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile,
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
    'sendPrompt resumes the root thread after the transport drops the tracked thread',
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

      await appServerClient.disconnect();

      expect(await controller.sendPrompt('Resume after reconnect'), isTrue);
      expect(appServerClient.connectCalls, 2);
      expect(appServerClient.startSessionCalls, 2);
      expect(
        appServerClient.startSessionRequests.last.resumeThreadId,
        'thread_123',
      );
      expect(appServerClient.sentTurns.last, (
        threadId: 'thread_123',
        input: const CodexAppServerTurnInput.text('Resume after reconnect'),
        text: 'Resume after reconnect',
        model: null,
        effort: null,
      ));
    },
  );

  test(
    'sendPrompt stays blocked after missing conversation recovery becomes active',
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
      appServerClient.sendUserMessageError = const CodexAppServerException(
        'turn/start failed: thread not found',
      );

      expect(await controller.sendPrompt('Second prompt'), isFalse);
      expect(
        controller.conversationRecoveryState?.reason,
        ChatConversationRecoveryReason.missingRemoteConversation,
      );

      appServerClient.sendUserMessageError = null;

      expect(await controller.sendPrompt('Third prompt'), isFalse);
      expect(appServerClient.startSessionCalls, 1);
      expect(appServerClient.sentMessages, <String>['First prompt']);
    },
  );

  test(
    'sendPrompt surfaces a missing conversation explicitly instead of silently starting fresh',
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
      appServerClient.sendUserMessageError = const CodexAppServerException(
        'turn/start failed: thread not found',
      );

      final sent = await controller.sendPrompt('Second prompt');

      expect(sent, isFalse);
      expect(appServerClient.startSessionCalls, 1);
      expect(
        controller.conversationRecoveryState?.reason,
        ChatConversationRecoveryReason.missingRemoteConversation,
      );
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>().map(
          (block) => block.text,
        ),
        <String>['First prompt', 'Second prompt'],
      );
      expect(
        controller.transcriptBlocks.whereType<CodexErrorBlock>().last.body,
        'Could not continue this conversation because the remote conversation was not found. Start a fresh conversation to continue.',
      );
    },
  );

  test(
    'sendPrompt surfaces an explicit recovery state when thread/resume returns a different thread id',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..startSessionError = const CodexAppServerException(
          'thread/resume returned a different thread id than requested.',
          data: <String, Object?>{
            'expectedThreadId': 'thread_old',
            'actualThreadId': 'thread_new',
          },
        );
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

      final sent = await controller.sendPrompt('Second prompt');

      expect(sent, isFalse);
      expect(
        controller.conversationRecoveryState?.reason,
        ChatConversationRecoveryReason.unexpectedRemoteConversation,
      );
      expect(
        controller.conversationRecoveryState?.expectedThreadId,
        'thread_old',
      );
      expect(
        controller.conversationRecoveryState?.actualThreadId,
        'thread_new',
      );
      expect(
        controller.transcriptBlocks.whereType<CodexErrorBlock>().last.body,
        'Pocket Relay expected remote conversation "thread_old", but the remote session returned "thread_new". Sending is blocked to avoid attaching your draft to a different conversation.',
      );
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
    'startFreshConversation clears the in-memory resume target before the next send',
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
      expect(appServerClient.startSessionRequests.last.resumeThreadId, isNull);
    },
  );

  test(
    'clearTranscript prevents reusing a previously tracked live thread',
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
      controller.clearTranscript();

      expect(await controller.sendPrompt('Second prompt'), isTrue);
      expect(appServerClient.startSessionCalls, 2);
    },
  );

  test('clearTranscript refuses to reset while a turn is active', () async {
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

    expect(await controller.sendPrompt('Keep running'), isTrue);
    final originalRootThreadId = controller.sessionState.rootThreadId;
    final originalUserTexts = controller.transcriptBlocks
        .whereType<CodexUserMessageBlock>()
        .map((block) => block.text)
        .toList(growable: false);
    final snackBarMessage = controller.snackBarMessages.first.timeout(
      const Duration(seconds: 1),
    );

    controller.clearTranscript();

    expect(controller.sessionState.rootThreadId, originalRootThreadId);
    expect(
      controller.transcriptBlocks.whereType<CodexUserMessageBlock>().map(
        (block) => block.text,
      ),
      originalUserTexts,
    );
    expect(
      await snackBarMessage,
      'Stop the active turn before clearing the transcript.',
    );
  });

  test(
    'sendPrompt reselects the root timeline before sending from a child timeline',
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
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'thread/started',
          params: <String, Object?>{
            'thread': <String, Object?>{
              'id': 'thread_child',
              'agentNickname': 'Reviewer',
            },
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      controller.selectTimeline('thread_child');
      expect(controller.sessionState.currentThreadId, 'thread_child');

      expect(await controller.sendPrompt('Second prompt'), isTrue);

      expect(controller.sessionState.currentThreadId, 'thread_123');
      expect(appServerClient.sentMessages, <String>[
        'First prompt',
        'Second prompt',
      ]);
    },
  );

  test(
    'submitUserInput resolves a child-owned request even when another timeline is selected',
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
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'thread/started',
          params: <String, Object?>{
            'thread': <String, Object?>{
              'id': 'thread_child',
              'agentNickname': 'Reviewer',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 'input_child_1',
          method: 'item/tool/requestUserInput',
          params: <String, Object?>{
            'threadId': 'thread_child',
            'turnId': 'turn_child_1',
            'itemId': 'item_child_1',
            'questions': <Object?>[
              <String, Object?>{
                'id': 'q1',
                'header': 'Name',
                'question': 'What is your name?',
              },
            ],
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.sessionState.currentThreadId, 'thread_123');
      expect(
        controller.sessionState.requestOwnerById['input_child_1'],
        'thread_child',
      );

      await controller.submitUserInput(
        'input_child_1',
        const <String, List<String>>{
          'q1': <String>['Vince'],
        },
      );

      expect(
        appServerClient.userInputResponses,
        <({String requestId, Map<String, List<String>> answers})>[
          (
            requestId: 'input_child_1',
            answers: const <String, List<String>>{
              'q1': <String>['Vince'],
            },
          ),
        ],
      );
    },
  );

  test('hydrates missing child thread metadata through thread/read', () async {
    final appServerClient = FakeCodexAppServerClient()
      ..threadsById['thread_child'] = const CodexAppServerThreadSummary(
        id: 'thread_child',
        name: 'Review Branch',
        agentNickname: 'Reviewer',
        agentRole: 'Code review',
        sourceKind: 'spawned',
      );
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
        method: 'thread/started',
        params: <String, Object?>{
          'thread': <String, Object?>{'id': 'thread_child'},
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final entry = controller.sessionState.threadRegistry['thread_child'];
    expect(appServerClient.readThreadCalls, contains('thread_child'));
    expect(entry?.threadName, 'Review Branch');
    expect(entry?.agentNickname, 'Reviewer');
    expect(entry?.agentRole, 'Code review');
    expect(entry?.sourceKind, 'spawned');
  });

  test(
    'stopActiveTurn targets the selected timeline turn explicitly',
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
          method: 'thread/started',
          params: <String, Object?>{
            'thread': <String, Object?>{
              'id': 'thread_child',
              'agentNickname': 'Reviewer',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/started',
          params: <String, Object?>{
            'threadId': 'thread_child',
            'turn': <String, Object?>{
              'id': 'turn_child_1',
              'status': 'running',
            },
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      controller.selectTimeline('thread_child');
      await controller.stopActiveTurn();

      expect(
        appServerClient.abortTurnCalls,
        <({String? threadId, String? turnId})>[
          (threadId: 'thread_child', turnId: 'turn_child_1'),
        ],
      );
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
    workspaceDir: '/workspace',
  );
}

CodexAppServerThreadHistory _savedConversationThread({
  required String threadId,
}) {
  return CodexAppServerThreadHistory(
    id: threadId,
    name: 'Saved conversation',
    sourceKind: 'app-server',
    turns: const <CodexAppServerHistoryTurn>[
      CodexAppServerHistoryTurn(
        id: 'turn_saved',
        status: 'completed',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_user',
            type: 'user_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
          ),
          CodexAppServerHistoryItem(
            id: 'item_assistant',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_saved',
          'status': 'completed',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
            <String, Object?>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ],
        },
      ),
      CodexAppServerHistoryTurn(
        id: 'turn_second',
        status: 'completed',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_user_second',
            type: 'user_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_user_second',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Second prompt'},
              ],
            },
          ),
          CodexAppServerHistoryItem(
            id: 'item_assistant_second',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant_second',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Second answer'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_second',
          'status': 'completed',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_user_second',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Second prompt'},
              ],
            },
            <String, Object?>{
              'id': 'item_assistant_second',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Second answer'},
              ],
            },
          ],
        },
      ),
    ],
  );
}

CodexAppServerThreadHistory _rewoundConversationThread({
  required String threadId,
}) {
  return CodexAppServerThreadHistory(
    id: threadId,
    name: 'Saved conversation',
    sourceKind: 'app-server',
    turns: const <CodexAppServerHistoryTurn>[
      CodexAppServerHistoryTurn(
        id: 'turn_before_restore_this',
        status: 'completed',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_assistant_earlier',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant_earlier',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Earlier answer only'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_before_restore_this',
          'status': 'completed',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_assistant_earlier',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Earlier answer only'},
              ],
            },
          ],
        },
      ),
    ],
  );
}
