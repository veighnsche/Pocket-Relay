import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/composer/domain/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/chat_historical_conversation_restorer.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/codex_historical_conversation.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/codex_historical_conversation_normalizer.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_thread_read_decoder.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';

void main() {
  const restorer = ChatHistoricalConversationRestorer();
  const decoder = CodexAppServerThreadReadDecoder();
  const normalizer = CodexHistoricalConversationNormalizer();

  test('restores a normalized conversation into transcript state', () {
    final conversation = CodexHistoricalConversation(
      threadId: 'thread_saved',
      createdAt: DateTime(2026, 3, 20, 10),
      threadName: 'Saved conversation',
      sourceKind: 'app-server',
      turns: <CodexHistoricalTurn>[
        CodexHistoricalTurn(
          id: 'turn_saved',
          threadId: 'thread_saved',
          createdAt: DateTime(2026, 3, 20, 10, 1),
          completedAt: DateTime(2026, 3, 20, 10, 2),
          state: CodexRuntimeTurnState.completed,
          model: 'gpt-5.4',
          effort: 'high',
          entries: <CodexHistoricalEntry>[
            CodexHistoricalEntry(
              id: 'item_user',
              threadId: 'thread_saved',
              turnId: 'turn_saved',
              createdAt: DateTime(2026, 3, 20, 10, 1),
              itemType: CodexCanonicalItemType.userMessage,
              status: CodexRuntimeItemStatus.completed,
              title: 'You',
              detail: 'Restore this',
              snapshot: const <String, dynamic>{
                'type': 'user_message',
                'content': <Object>[
                  <String, Object?>{'text': 'Restore this'},
                ],
              },
            ),
            CodexHistoricalEntry(
              id: 'item_assistant',
              threadId: 'thread_saved',
              turnId: 'turn_saved',
              createdAt: DateTime(2026, 3, 20, 10, 2),
              itemType: CodexCanonicalItemType.assistantMessage,
              status: CodexRuntimeItemStatus.completed,
              title: 'Codex',
              detail: 'Restored answer',
              snapshot: const <String, dynamic>{
                'type': 'agent_message',
                'content': <Object>[
                  <String, Object?>{'text': 'Restored answer'},
                ],
              },
            ),
          ],
        ),
      ],
    );

    final restoredState = restorer.restore(conversation);

    expect(restoredState.rootThreadId, 'thread_saved');
    expect(restoredState.selectedThreadId, 'thread_saved');
    expect(restoredState.headerMetadata.model, 'gpt-5.4');
    expect(restoredState.headerMetadata.reasoningEffort, 'high');
    expect(
      restoredState.transcriptBlocks
          .whereType<CodexUserMessageBlock>()
          .single
          .text,
      'Restore this',
    );
    expect(
      restoredState.transcriptBlocks.whereType<CodexTextBlock>().single.body,
      'Restored answer',
    );
  });

  test(
    'restores the captured live thread/read fixture into transcript blocks',
    () {
      final thread = decoder.decodeHistoryResponse(
        _loadFixture(
          'test/features/chat/transport/app_server/fixtures/thread_read/live_capture_001.json',
        ),
        fallbackThreadId: 'thread_live',
      );
      final conversation = normalizer.normalize(thread);

      final restoredState = restorer.restore(conversation);

      expect(restoredState.rootThreadId, '<thread_1>');
      expect(restoredState.selectedThreadId, '<thread_1>');
      expect(
        restoredState.transcriptBlocks
            .whereType<CodexUserMessageBlock>()
            .single
            .text,
        '<text_1>',
      );

      final assistantBlocks = restoredState.transcriptBlocks
          .whereType<CodexTextBlock>()
          .toList(growable: false);
      expect(assistantBlocks, hasLength(9));
      expect(assistantBlocks.first.body, '<text_2>');
      expect(assistantBlocks.last.body, '<text_10>');
    },
  );

  test(
    'restores structured remote-image user messages from history snapshots',
    () {
      final conversation = CodexHistoricalConversation(
        threadId: 'thread_images',
        createdAt: DateTime(2026, 3, 20, 10),
        turns: <CodexHistoricalTurn>[
          CodexHistoricalTurn(
            id: 'turn_images',
            threadId: 'thread_images',
            createdAt: DateTime(2026, 3, 20, 10, 1),
            completedAt: DateTime(2026, 3, 20, 10, 2),
            state: CodexRuntimeTurnState.completed,
            entries: <CodexHistoricalEntry>[
              CodexHistoricalEntry(
                id: 'item_user_image',
                threadId: 'thread_images',
                turnId: 'turn_images',
                createdAt: DateTime(2026, 3, 20, 10, 1),
                itemType: CodexCanonicalItemType.userMessage,
                status: CodexRuntimeItemStatus.completed,
                title: 'You',
                detail: 'See [Image #1]',
                snapshot: const <String, dynamic>{
                  'type': 'userMessage',
                  'content': <Object>[
                    <String, Object?>{
                      'type': 'image',
                      'image_url': 'data:image/png;base64,cmVmZXJlbmNl',
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
            ],
          ),
        ],
      );

      final restoredState = restorer.restore(conversation);

      final block = restoredState.transcriptBlocks
          .whereType<CodexUserMessageBlock>()
          .single;
      expect(
        block.draft,
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
              placeholder: '[Image #1]',
            ),
          ],
        ),
      );
    },
  );

  test(
    'restores mixed text and remote-image user messages when history omits placeholder spans',
    () {
      final conversation = CodexHistoricalConversation(
        threadId: 'thread_mixed_remote_images',
        createdAt: DateTime(2026, 3, 20, 10),
        turns: <CodexHistoricalTurn>[
          CodexHistoricalTurn(
            id: 'turn_mixed_remote_images',
            threadId: 'thread_mixed_remote_images',
            createdAt: DateTime(2026, 3, 20, 10, 1),
            completedAt: DateTime(2026, 3, 20, 10, 2),
            state: CodexRuntimeTurnState.completed,
            entries: <CodexHistoricalEntry>[
              CodexHistoricalEntry(
                id: 'item_user_mixed_remote_images',
                threadId: 'thread_mixed_remote_images',
                turnId: 'turn_mixed_remote_images',
                createdAt: DateTime(2026, 3, 20, 10, 1),
                itemType: CodexCanonicalItemType.userMessage,
                status: CodexRuntimeItemStatus.completed,
                title: 'You',
                detail: 'See reference',
                snapshot: const <String, dynamic>{
                  'type': 'userMessage',
                  'content': <Object>[
                    <String, Object?>{
                      'type': 'image',
                      'image_url': 'data:image/png;base64,cmVmZXJlbmNl',
                    },
                    <String, Object?>{'type': 'text', 'text': 'See reference'},
                  ],
                },
              ),
            ],
          ),
        ],
      );

      final restoredState = restorer.restore(conversation);

      final block = restoredState.transcriptBlocks
          .whereType<CodexUserMessageBlock>()
          .single;
      expect(
        block.draft,
        const ChatComposerDraft(
          text: 'See reference\n[Image #1]',
          textElements: <ChatComposerTextElement>[
            ChatComposerTextElement(
              start: 14,
              end: 24,
              placeholder: '[Image #1]',
            ),
          ],
          imageAttachments: <ChatComposerImageAttachment>[
            ChatComposerImageAttachment(
              imageUrl: 'data:image/png;base64,cmVmZXJlbmNl',
              placeholder: '[Image #1]',
            ),
          ],
        ),
      );
    },
  );

  test('restores image-only user messages as inline image placeholders', () {
    final conversation = CodexHistoricalConversation(
      threadId: 'thread_image_only',
      createdAt: DateTime(2026, 3, 20, 10),
      turns: <CodexHistoricalTurn>[
        CodexHistoricalTurn(
          id: 'turn_image_only',
          threadId: 'thread_image_only',
          createdAt: DateTime(2026, 3, 20, 10, 1),
          completedAt: DateTime(2026, 3, 20, 10, 2),
          state: CodexRuntimeTurnState.completed,
          entries: <CodexHistoricalEntry>[
            CodexHistoricalEntry(
              id: 'item_user_image_only',
              threadId: 'thread_image_only',
              turnId: 'turn_image_only',
              createdAt: DateTime(2026, 3, 20, 10, 1),
              itemType: CodexCanonicalItemType.userMessage,
              status: CodexRuntimeItemStatus.completed,
              title: 'You',
              snapshot: const <String, dynamic>{
                'type': 'userMessage',
                'content': <Object>[
                  <String, Object?>{
                    'type': 'image',
                    'url': 'data:image/png;base64,cmFnZQ==',
                  },
                ],
              },
            ),
          ],
        ),
      ],
    );

    final restoredState = restorer.restore(conversation);

    final block = restoredState.transcriptBlocks
        .whereType<CodexUserMessageBlock>()
        .single;
    expect(block.text, '[Image #1]');
    expect(
      block.draft,
      const ChatComposerDraft(
        text: '[Image #1]',
        textElements: <ChatComposerTextElement>[
          ChatComposerTextElement(start: 0, end: 10, placeholder: '[Image #1]'),
        ],
        imageAttachments: <ChatComposerImageAttachment>[
          ChatComposerImageAttachment(
            imageUrl: 'data:image/png;base64,cmFnZQ==',
            placeholder: '[Image #1]',
          ),
        ],
      ),
    );
  });
}

Map<String, dynamic> _loadFixture(String path) {
  final text = File(path).readAsStringSync();
  return jsonDecode(text) as Map<String, dynamic>;
}
