import 'reducer_test_support.dart';

void main() {
  var monotonicNow = Duration.zero;

  setUp(() {
    monotonicNow = Duration.zero;
    CodexMonotonicClock.debugSetNowProvider(() => monotonicNow);
  });

  tearDown(() {
    CodexMonotonicClock.debugSetNowProvider(null);
  });

  test(
    'keeps the local user prompt immutable when provider user-message events arrive later',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.addUserMessage(
        TranscriptSessionState.initial(),
        text: 'Ship the fix',
        createdAt: now,
      );
      final localBlockId =
          (state.blocks.single as TranscriptUserMessageBlock).id;

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeWarningEvent(
          createdAt: now.add(const Duration(milliseconds: 5)),
          summary: 'Connected to the remote session.',
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeItemCompletedEvent(
          createdAt: now.add(const Duration(milliseconds: 10)),
          itemType: TranscriptCanonicalItemType.userMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_user',
          status: TranscriptRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{'text': 'Ship the fix'},
        ),
      );

      final committedUserMessages = state.blocks
          .whereType<TranscriptUserMessageBlock>()
          .toList(growable: false);
      expect(committedUserMessages, hasLength(1));
      expect(committedUserMessages.single.id, localBlockId);
      expect(
        committedUserMessages.single.deliveryState,
        TranscriptUserMessageDeliveryState.sent,
      );

      final userMessages = state.transcriptBlocks
          .whereType<TranscriptUserMessageBlock>()
          .toList(growable: false);
      expect(userMessages, hasLength(1));
      expect(userMessages.single.id, localBlockId);
      expect(userMessages.single.text, 'Ship the fix');
      expect(
        userMessages.single.deliveryState,
        TranscriptUserMessageDeliveryState.sent,
      );
      expect(userMessages.single.providerItemId, isNull);
      expect(state.localUserMessageProviderBindings['item_user'], localBlockId);
      expect(state.pendingLocalUserMessageBlockIds, isEmpty);
      expect(
        state.transcriptBlocks.whereType<TranscriptStatusBlock>(),
        hasLength(1),
      );
    },
  );

  test(
    'suppresses the provider echo while keeping the local prompt surface stable at the tail',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.addUserMessage(
        TranscriptSessionState.initial(),
        text: 'Ship the fix',
        createdAt: now,
      );
      final localBlockId =
          (state.blocks.single as TranscriptUserMessageBlock).id;

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeItemCompletedEvent(
          createdAt: now.add(const Duration(milliseconds: 10)),
          itemType: TranscriptCanonicalItemType.userMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_user_tail',
          status: TranscriptRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{'text': 'Ship the fix'},
        ),
      );

      final userMessages = state.transcriptBlocks
          .whereType<TranscriptUserMessageBlock>()
          .toList(growable: false);
      expect(userMessages, hasLength(1));
      expect(userMessages.single.id, localBlockId);
      expect(
        userMessages.single.deliveryState,
        TranscriptUserMessageDeliveryState.sent,
      );
      expect(userMessages.single.providerItemId, isNull);
      expect(
        state.localUserMessageProviderBindings['item_user_tail'],
        localBlockId,
      );
      expect(state.pendingLocalUserMessageBlockIds, isEmpty);
    },
  );

  test(
    'keeps a single local user block when the same provider user-message item updates and completes',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.addUserMessage(
        TranscriptSessionState.initial(),
        text: 'this is a second test',
        createdAt: now,
      );
      final localBlockId =
          (state.blocks.single as TranscriptUserMessageBlock).id;

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeItemUpdatedEvent(
          createdAt: now.add(const Duration(milliseconds: 5)),
          itemType: TranscriptCanonicalItemType.userMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_user_2',
          status: TranscriptRuntimeItemStatus.inProgress,
          snapshot: const <String, Object?>{'text': 'this is a second test'},
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeItemCompletedEvent(
          createdAt: now.add(const Duration(milliseconds: 10)),
          itemType: TranscriptCanonicalItemType.userMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_user_2',
          status: TranscriptRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{'text': 'this is a second test'},
        ),
      );

      final userMessages = state.transcriptBlocks
          .whereType<TranscriptUserMessageBlock>()
          .toList(growable: false);
      expect(userMessages, hasLength(1));
      expect(userMessages.single.id, localBlockId);
      expect(userMessages.single.text, 'this is a second test');
      expect(
        userMessages.single.deliveryState,
        TranscriptUserMessageDeliveryState.sent,
      );
      expect(userMessages.single.providerItemId, isNull);
      expect(
        state.localUserMessageProviderBindings['item_user_2'],
        localBlockId,
      );
      expect(state.pendingLocalUserMessageBlockIds, isEmpty);
    },
  );

  test(
    'matches provider user-message echoes against the pending local prompt queue in order',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.addUserMessage(
        TranscriptSessionState.initial(),
        text: 'First prompt',
        createdAt: now,
      );
      final firstBlockId =
          (state.blocks.single as TranscriptUserMessageBlock).id;

      state = reducer.addUserMessage(
        state,
        text: 'Second prompt',
        createdAt: now.add(const Duration(milliseconds: 1)),
      );
      final secondBlockId =
          (state.blocks.last as TranscriptUserMessageBlock).id;

      expect(state.pendingLocalUserMessageBlockIds, <String>[
        firstBlockId,
        secondBlockId,
      ]);

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeItemCompletedEvent(
          createdAt: now.add(const Duration(milliseconds: 2)),
          itemType: TranscriptCanonicalItemType.userMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_user_first',
          status: TranscriptRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{'text': 'First prompt'},
        ),
      );

      expect(
        state.localUserMessageProviderBindings['item_user_first'],
        firstBlockId,
      );
      expect(state.pendingLocalUserMessageBlockIds, <String>[secondBlockId]);
      expect(
        state.transcriptBlocks.whereType<TranscriptUserMessageBlock>(),
        hasLength(2),
      );
    },
  );

  test(
    'matches same-text provider echoes by structured image content instead of text alone',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.addUserMessage(
        TranscriptSessionState.initial(),
        text: 'See [Image #1]',
        draft: imageDraft(
          imageUrl: 'data:image/png;base64,Zmlyc3Q=',
          displayName: 'first.png',
        ),
        createdAt: now,
      );
      final firstBlockId =
          (state.blocks.single as TranscriptUserMessageBlock).id;

      state = reducer.addUserMessage(
        state,
        text: 'See [Image #1]',
        draft: imageDraft(
          imageUrl: 'data:image/png;base64,c2Vjb25k',
          displayName: 'second.png',
        ),
        createdAt: now.add(const Duration(milliseconds: 1)),
      );
      final secondBlockId =
          (state.blocks.last as TranscriptUserMessageBlock).id;

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeItemCompletedEvent(
          createdAt: now.add(const Duration(milliseconds: 2)),
          itemType: TranscriptCanonicalItemType.userMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_user_second',
          status: TranscriptRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{
            'type': 'userMessage',
            'content': <Object>[
              <String, Object?>{
                'type': 'image',
                'url': 'data:image/png;base64,c2Vjb25k',
              },
              <String, Object?>{
                'type': 'text',
                'text': 'See [Image #1]',
                'text_elements': <Object>[
                  <String, Object?>{
                    'byteRange': <String, Object?>{'start': 4, 'end': 14},
                    'placeholder': '[Image #1]',
                  },
                ],
              },
            ],
          },
        ),
      );

      expect(
        state.localUserMessageProviderBindings['item_user_second'],
        secondBlockId,
      );
      expect(state.pendingLocalUserMessageBlockIds, <String>[firstBlockId]);
      final userMessages = state.transcriptBlocks
          .whereType<TranscriptUserMessageBlock>()
          .toList(growable: false);
      expect(userMessages, hasLength(2));
      expect(userMessages.last.id, secondBlockId);
      expect(
        userMessages.last.draft.imageAttachments.single.imageUrl,
        'data:image/png;base64,c2Vjb25k',
      );
    },
  );

  test(
    'clears local prompt correlation state after turn completion before the next same-text echo',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.addUserMessage(
        TranscriptSessionState.initial(),
        text: 'Repeat prompt',
        createdAt: now,
      );
      final firstBlockId =
          (state.blocks.single as TranscriptUserMessageBlock).id;

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeItemCompletedEvent(
          createdAt: now.add(const Duration(milliseconds: 10)),
          itemType: TranscriptCanonicalItemType.userMessage,
          threadId: 'thread_123',
          turnId: 'turn_1',
          itemId: 'item_user',
          status: TranscriptRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{'text': 'Repeat prompt'},
        ),
      );

      expect(state.localUserMessageProviderBindings['item_user'], firstBlockId);
      expect(state.pendingLocalUserMessageBlockIds, isEmpty);

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeTurnCompletedEvent(
          createdAt: now.add(const Duration(milliseconds: 20)),
          threadId: 'thread_123',
          turnId: 'turn_1',
          state: TranscriptRuntimeTurnState.completed,
        ),
      );

      expect(state.localUserMessageProviderBindings, isEmpty);
      expect(state.pendingLocalUserMessageBlockIds, isEmpty);

      state = reducer.addUserMessage(
        state,
        text: 'Repeat prompt',
        createdAt: now.add(const Duration(seconds: 1)),
      );
      final secondBlockId =
          (state.blocks.last as TranscriptUserMessageBlock).id;

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeItemCompletedEvent(
          createdAt: now.add(const Duration(seconds: 1, milliseconds: 10)),
          itemType: TranscriptCanonicalItemType.userMessage,
          threadId: 'thread_123',
          turnId: 'turn_2',
          itemId: 'item_user',
          status: TranscriptRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{'text': 'Repeat prompt'},
        ),
      );

      final userMessages = state.transcriptBlocks
          .whereType<TranscriptUserMessageBlock>()
          .toList(growable: false);
      expect(userMessages, hasLength(2));
      expect(userMessages.map((block) => block.id), <String>[
        firstBlockId,
        secondBlockId,
      ]);
      expect(
        state.localUserMessageProviderBindings['item_user'],
        secondBlockId,
      );
      expect(state.pendingLocalUserMessageBlockIds, isEmpty);
    },
  );

  test(
    'suppressed provider echoes discard stale empty user-message lifecycle state',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.addUserMessage(
        TranscriptSessionState.initial(),
        text: 'Ship the fix',
        createdAt: now,
      );
      final localBlockId =
          (state.blocks.single as TranscriptUserMessageBlock).id;

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeItemStartedEvent(
          createdAt: now.add(const Duration(milliseconds: 5)),
          itemType: TranscriptCanonicalItemType.userMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_user',
          status: TranscriptRuntimeItemStatus.inProgress,
        ),
      );

      expect(state.activeTurn?.itemsById.containsKey('item_user'), isTrue);
      expect(state.activeTurn?.artifacts, isEmpty);

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeItemCompletedEvent(
          createdAt: now.add(const Duration(milliseconds: 10)),
          itemType: TranscriptCanonicalItemType.userMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_user',
          status: TranscriptRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{'text': 'Ship the fix'},
        ),
      );

      expect(state.activeTurn?.itemsById.containsKey('item_user'), isFalse);
      expect(
        state.activeTurn?.itemArtifactIds.containsKey('item_user'),
        isFalse,
      );

      final userMessages = state.transcriptBlocks
          .whereType<TranscriptUserMessageBlock>()
          .toList(growable: false);
      expect(userMessages, hasLength(1));
      expect(userMessages.single.id, localBlockId);
      expect(userMessages.single.text, 'Ship the fix');
    },
  );
}
