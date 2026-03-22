import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer.dart';

void main() {
  test('local image text elements use UTF-8 byte offsets', () {
    final draft = const ChatComposerDraft(
      text: 'é [Image #1]',
      localImageAttachments: <ChatComposerLocalImageAttachment>[
        ChatComposerLocalImageAttachment(
          path: '/tmp/reference.png',
          placeholder: '[Image #1]',
        ),
      ],
    ).normalized();

    expect(draft.textElements, const <ChatComposerTextElement>[
      ChatComposerTextElement(start: 3, end: 13, placeholder: '[Image #1]'),
    ]);
  });

  test(
    'normalizes local image placeholders by text order and renumbers them',
    () {
      final draft = const ChatComposerDraft(
        text: '[Image #2] then [Image #1]',
        localImageAttachments: <ChatComposerLocalImageAttachment>[
          ChatComposerLocalImageAttachment(
            path: '/tmp/second.png',
            placeholder: '[Image #1]',
          ),
          ChatComposerLocalImageAttachment(
            path: '/tmp/first.png',
            placeholder: '[Image #2]',
          ),
        ],
      ).normalized();

      expect(draft.text, '[Image #1] then [Image #2]');
      expect(
        draft.localImageAttachments,
        const <ChatComposerLocalImageAttachment>[
          ChatComposerLocalImageAttachment(
            path: '/tmp/first.png',
            placeholder: '[Image #1]',
          ),
          ChatComposerLocalImageAttachment(
            path: '/tmp/second.png',
            placeholder: '[Image #2]',
          ),
        ],
      );
    },
  );

  test(
    'insertLocalImage preserves placeholder order when inserting before an existing image',
    () {
      final insertion =
          const ChatComposerDraft(
            text: 'Before [Image #1]',
            localImageAttachments: <ChatComposerLocalImageAttachment>[
              ChatComposerLocalImageAttachment(
                path: '/tmp/existing.png',
                placeholder: '[Image #1]',
              ),
            ],
          ).insertLocalImage(
            path: '/tmp/earlier.png',
            selectionStart: 0,
            selectionEnd: 0,
          );

      expect(insertion.draft.text, '[Image #1]Before [Image #2]');
      expect(
        insertion.draft.localImageAttachments,
        const <ChatComposerLocalImageAttachment>[
          ChatComposerLocalImageAttachment(
            path: '/tmp/earlier.png',
            placeholder: '[Image #1]',
          ),
          ChatComposerLocalImageAttachment(
            path: '/tmp/existing.png',
            placeholder: '[Image #2]',
          ),
        ],
      );
    },
  );

  testWidgets('resyncs displayed text from the composer contract', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildComposerApp(
        contract: _composerContract(draftText: 'Initial draft'),
      ),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Initial draft',
    );

    await tester.pumpWidget(_buildComposerApp(contract: _composerContract()));

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '',
    );
  });

  testWidgets('forwards text changes without owning draft state', (
    tester,
  ) async {
    ChatComposerDraft? latestDraft;

    await tester.pumpWidget(
      _buildComposerApp(
        contract: _composerContract(),
        onChanged: (draft) {
          latestDraft = draft;
        },
      ),
    );

    await tester.enterText(find.byType(TextField), 'Composer draft');

    expect(latestDraft?.text, 'Composer draft');
  });

  testWidgets(
    'local attach inserts an image placeholder at the current caret position',
    (tester) async {
      ChatComposerDraft? latestDraft;

      await tester.pumpWidget(
        _buildComposerApp(
          platform: TargetPlatform.macOS,
          contract: _composerContract(allowsLocalImageAttachment: true),
          onChanged: (draft) {
            latestDraft = draft;
          },
          localImagePicker: () async => '/tmp/reference.png',
        ),
      );

      final fieldFinder = find.byType(TextField);
      await tester.enterText(fieldFinder, 'See  for details');
      await tester.pump();

      final controller = tester.widget<TextField>(fieldFinder).controller!;
      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('attach_local_image')));
      await tester.pump();

      expect(controller.text, 'See [Image #1] for details');
      expect(find.text('[Image #1] reference.png'), findsOneWidget);
      expect(latestDraft?.text, 'See [Image #1] for details');
      expect(
        latestDraft?.localImageAttachments,
        const <ChatComposerLocalImageAttachment>[
          ChatComposerLocalImageAttachment(
            path: '/tmp/reference.png',
            placeholder: '[Image #1]',
          ),
        ],
      );
      expect(latestDraft?.textElements, const <ChatComposerTextElement>[
        ChatComposerTextElement(start: 4, end: 14, placeholder: '[Image #1]'),
      ]);
    },
  );

  testWidgets('remote composer does not expose the local image attach action', (
    tester,
  ) async {
    await tester.pumpWidget(_buildComposerApp(contract: _composerContract()));

    expect(find.byKey(const ValueKey('attach_local_image')), findsNothing);
  });

  testWidgets(
    'backspace deletes an inline image placeholder atomically and renumbers survivors',
    (tester) async {
      ChatComposerDraft? latestDraft;

      await tester.pumpWidget(
        _buildComposerApp(
          platform: TargetPlatform.macOS,
          contract: ChatComposerContract(
            draft: const ChatComposerDraft(
              text: 'A[Image #1]B[Image #2]C',
              localImageAttachments: <ChatComposerLocalImageAttachment>[
                ChatComposerLocalImageAttachment(
                  path: '/tmp/first.png',
                  placeholder: '[Image #1]',
                ),
                ChatComposerLocalImageAttachment(
                  path: '/tmp/second.png',
                  placeholder: '[Image #2]',
                ),
              ],
            ).normalized(),
            isSendActionEnabled: true,
            allowsLocalImageAttachment: true,
            placeholder: 'Message Codex',
          ),
          onChanged: (draft) {
            latestDraft = draft;
          },
        ),
      );

      final fieldFinder = find.byType(TextField);
      await tester.tap(fieldFinder);
      await tester.pump();

      final controller = tester.widget<TextField>(fieldFinder).controller!;
      controller.selection = const TextSelection.collapsed(offset: 11);
      await tester.pump();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'A[Image #1B[Image #2]C',
          selection: TextSelection.collapsed(offset: 10),
        ),
      );
      await tester.pump();

      expect(controller.text, 'AB[Image #1]C');
      expect(latestDraft?.text, 'AB[Image #1]C');
      expect(
        latestDraft?.localImageAttachments,
        const <ChatComposerLocalImageAttachment>[
          ChatComposerLocalImageAttachment(
            path: '/tmp/second.png',
            placeholder: '[Image #1]',
          ),
        ],
      );
    },
  );

  testWidgets(
    'typing inside an inline image placeholder moves the text insertion outside the placeholder',
    (tester) async {
      ChatComposerDraft? latestDraft;

      await tester.pumpWidget(
        _buildComposerApp(
          platform: TargetPlatform.macOS,
          contract: ChatComposerContract(
            draft: const ChatComposerDraft(
              text: 'A[Image #1]B',
              localImageAttachments: <ChatComposerLocalImageAttachment>[
                ChatComposerLocalImageAttachment(
                  path: '/tmp/first.png',
                  placeholder: '[Image #1]',
                ),
              ],
            ).normalized(),
            isSendActionEnabled: true,
            allowsLocalImageAttachment: true,
            placeholder: 'Message Codex',
          ),
          onChanged: (draft) {
            latestDraft = draft;
          },
        ),
      );

      final fieldFinder = find.byType(TextField);
      await tester.tap(fieldFinder);
      await tester.pump();

      final controller = tester.widget<TextField>(fieldFinder).controller!;
      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'A[Ixmage #1]B',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      await tester.pump();

      expect(controller.text, 'A[Image #1]xB');
      expect(latestDraft?.text, 'A[Image #1]xB');
      expect(
        latestDraft?.localImageAttachments,
        const <ChatComposerLocalImageAttachment>[
          ChatComposerLocalImageAttachment(
            path: '/tmp/first.png',
            placeholder: '[Image #1]',
          ),
        ],
      );
    },
  );

  testWidgets('desktop enter sends the draft', (tester) async {
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildComposerApp(
        platform: TargetPlatform.macOS,
        contract: _composerContract(),
        onSend: () async {
          sendCalls += 1;
        },
      ),
    );

    final fieldFinder = find.byType(TextField);

    await tester.tap(fieldFinder);
    await tester.pump();
    await tester.enterText(fieldFinder, 'Desktop draft');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(sendCalls, 1);
    expect(
      tester.widget<TextField>(fieldFinder).controller?.text,
      'Desktop draft',
    );
  });

  testWidgets('desktop shift+enter inserts a newline', (tester) async {
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildComposerApp(
        platform: TargetPlatform.macOS,
        contract: _composerContract(),
        onSend: () async {
          sendCalls += 1;
        },
      ),
    );

    final fieldFinder = find.byType(TextField);

    await tester.tap(fieldFinder);
    await tester.pump();
    await tester.enterText(fieldFinder, 'Desktop draft');
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(sendCalls, 0);
    expect(
      tester.widget<TextField>(fieldFinder).controller?.text,
      'Desktop draft\n',
    );
  });

  testWidgets('mobile enter does not send and the draft remains multiline', (
    tester,
  ) async {
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildComposerApp(
        platform: TargetPlatform.android,
        contract: _composerContract(),
        onSend: () async {
          sendCalls += 1;
        },
      ),
    );

    final fieldFinder = find.byType(TextField);

    await tester.tap(fieldFinder);
    await tester.pump();
    await tester.enterText(fieldFinder, 'Mobile draft');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(sendCalls, 0);
    expect(
      tester.widget<TextField>(fieldFinder).textInputAction,
      TextInputAction.newline,
    );

    await tester.enterText(fieldFinder, 'Mobile draft\nSecond line');
    await tester.pump();

    expect(
      tester.widget<TextField>(fieldFinder).controller?.text,
      'Mobile draft\nSecond line',
    );
  });

  testWidgets('keeps desktop focus and the send affordance stable while busy', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildComposerApp(
        platform: TargetPlatform.macOS,
        contract: _composerContract(draftText: 'Desktop draft'),
      ),
    );

    final fieldFinder = find.byType(TextField);

    await tester.tap(fieldFinder);
    await tester.pump();

    expect(_editableTextFocusNode(tester).hasFocus, isTrue);
    expect(find.byKey(const ValueKey('send')), findsOneWidget);

    await tester.pumpWidget(
      _buildComposerApp(
        platform: TargetPlatform.macOS,
        contract: _composerContract(
          draftText: 'Desktop draft',
          isSendActionEnabled: false,
        ),
      ),
    );
    await tester.pump();

    expect(_editableTextFocusNode(tester).hasFocus, isTrue);
    expect(find.byKey(const ValueKey('send')), findsOneWidget);
    expect(find.byKey(const ValueKey('stop')), findsNothing);
  });

  testWidgets(
    'does not locally re-enable send when the screen contract disallows sending',
    (tester) async {
      await tester.pumpWidget(
        _buildComposerApp(
          contract: _composerContract(isSendActionEnabled: false),
        ),
      );

      final fieldFinder = find.byType(TextField);
      await tester.enterText(fieldFinder, 'Typed while blocked');
      await tester.pump();

      final sendButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('send')),
      );

      expect(sendButton.onPressed, isNull);
    },
  );

  testWidgets('uses a compact chat-style input shell', (tester) async {
    await tester.pumpWidget(_buildComposerApp(contract: _composerContract()));

    final field = tester.widget<TextField>(find.byType(TextField));
    final sendSize = tester.getSize(find.byKey(const ValueKey('send')));

    expect(field.decoration?.isCollapsed, isTrue);
    expect(
      field.decoration?.contentPadding,
      const EdgeInsets.symmetric(vertical: 4),
    );
    expect(sendSize, const Size(36, 36));
  });

  testWidgets('tapping outside the composer input dismisses focus', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildComposerApp(
        contract: _composerContract(),
        includeOutsideTapTarget: true,
      ),
    );

    final fieldFinder = find.byType(TextField);

    await tester.tap(fieldFinder);
    await tester.pump();

    expect(_editableTextFocusNode(tester).hasFocus, isTrue);

    await tester.tapAt(const Offset(24, 24));
    await tester.pump();

    expect(_editableTextFocusNode(tester).hasFocus, isFalse);
  });

  testWidgets('send dismisses composer focus on mobile', (tester) async {
    await tester.pumpWidget(
      _buildComposerApp(
        platform: TargetPlatform.android,
        contract: _composerContract(),
      ),
    );

    final fieldFinder = find.byType(TextField);

    await tester.tap(fieldFinder);
    await tester.pump();
    await tester.enterText(fieldFinder, 'Mobile draft');
    await tester.pump();

    expect(_editableTextFocusNode(tester).hasFocus, isTrue);

    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pump();

    expect(_editableTextFocusNode(tester).hasFocus, isFalse);
  });
}

Widget _buildComposerApp({
  required ChatComposerContract contract,
  TargetPlatform platform = TargetPlatform.android,
  ValueChanged<ChatComposerDraft>? onChanged,
  Future<void> Function()? onSend,
  Future<String?> Function()? localImagePicker,
  bool includeOutsideTapTarget = false,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light).copyWith(platform: platform),
    home: Scaffold(
      body: Column(
        children: [
          if (includeOutsideTapTarget)
            const Expanded(
              child: SizedBox(
                key: ValueKey('outside_tap_target'),
                width: double.infinity,
              ),
            ),
          ChatComposer(
            platformBehavior: PocketPlatformBehavior.resolve(
              platform: platform,
            ),
            contract: contract,
            onChanged: onChanged ?? (_) {},
            onSend: onSend ?? () async {},
            localImagePicker: localImagePicker,
          ),
        ],
      ),
    ),
  );
}

ChatComposerContract _composerContract({
  String draftText = '',
  bool isSendActionEnabled = true,
  bool allowsLocalImageAttachment = false,
}) {
  return ChatComposerContract(
    draft: ChatComposerDraft(text: draftText),
    isSendActionEnabled: isSendActionEnabled,
    allowsLocalImageAttachment: allowsLocalImageAttachment,
    placeholder: 'Message Codex',
  );
}

FocusNode _editableTextFocusNode(WidgetTester tester) {
  return tester.widget<EditableText>(find.byType(EditableText)).focusNode;
}
