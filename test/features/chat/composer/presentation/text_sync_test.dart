import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/features/chat/composer/application/chat_composer_image_attachment_errors.dart';
import 'package:pocket_relay/src/features/chat/composer/application/chat_composer_image_attachment_loader.dart';

import '../support/composer_test_support.dart';

void main() {
  testWidgets('resyncs displayed text from the composer contract', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildComposerApp(contract: composerContract(draftText: 'Initial draft')),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Initial draft',
    );

    await tester.pumpWidget(buildComposerApp(contract: composerContract()));

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
      buildComposerApp(
        contract: composerContract(),
        onChanged: (draft) {
          latestDraft = draft;
        },
      ),
    );

    await tester.enterText(find.byType(TextField), 'Composer draft');

    expect(latestDraft?.text, 'Composer draft');
  });

  testWidgets(
    'attach inserts an image placeholder at the current caret position',
    (tester) async {
      ChatComposerDraft? latestDraft;

      await tester.pumpWidget(
        buildComposerApp(
          platform: TargetPlatform.macOS,
          contract: composerContract(allowsImageAttachment: true),
          onChanged: (draft) {
            latestDraft = draft;
          },
          imageAttachmentPicker: () async => referenceImageAttachment(),
        ),
      );

      final fieldFinder = find.byType(TextField);
      await tester.enterText(fieldFinder, 'See  for details');
      await tester.pump();

      final controller = tester.widget<TextField>(fieldFinder).controller!;
      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('attach_image')));
      await tester.pump();

      expect(controller.text, 'See [Image #1] for details');
      expect(find.text('[Image #1] reference.png'), findsOneWidget);
      expect(latestDraft?.text, 'See [Image #1] for details');
      expect(latestDraft?.imageAttachments, const <ChatComposerImageAttachment>[
        ChatComposerImageAttachment(
          imageUrl: 'data:image/png;base64,cmVmZXJlbmNl',
          displayName: 'reference.png',
          placeholder: '[Image #1]',
        ),
      ]);
      expect(latestDraft?.textElements, const <ChatComposerTextElement>[
        ChatComposerTextElement(start: 4, end: 14, placeholder: '[Image #1]'),
      ]);
    },
  );

  testWidgets('composer hides the image attach action when disallowed', (
    tester,
  ) async {
    await tester.pumpWidget(buildComposerApp(contract: composerContract()));

    expect(find.byKey(const ValueKey('attach_image')), findsNothing);
  });

  testWidgets('attach surfaces a stable coded snackbar for known load errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildComposerApp(
        contract: composerContract(allowsImageAttachment: true),
        imageAttachmentPicker: () async {
          throw ChatComposerImageAttachmentLoadException(
            ChatComposerImageAttachmentErrors.unsupportedType(),
          );
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('attach_image')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        '[${PocketErrorCatalog.chatSessionImageAttachmentUnsupportedType.code}]',
      ),
      findsOneWidget,
    );
  });

  testWidgets('attach surfaces a stable coded snackbar for unexpected failures', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildComposerApp(
        contract: composerContract(allowsImageAttachment: true),
        imageAttachmentPicker: () async => throw StateError('picker exploded'),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('attach_image')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        '[${PocketErrorCatalog.chatSessionImageAttachmentUnexpectedFailure.code}]',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('picker exploded'), findsOneWidget);
  });
}
