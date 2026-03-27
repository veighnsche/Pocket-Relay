import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/features/chat/composer/application/chat_composer_errors.dart';
import 'package:pocket_relay/src/features/chat/composer/application/chat_composer_image_attachment_loader.dart';

import '../support/composer_test_support.dart';

void main() {
  testWidgets('shows a typed snackbar for known image attachment failures', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildComposerApp(
        contract: composerContract(allowsImageAttachment: true),
        imageAttachmentPicker: () async {
          throw ChatComposerImageAttachmentLoadException(
            ChatComposerErrors.imageAttachmentUnsupportedType(),
          );
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('attach_image')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        '[${PocketErrorCatalog.chatComposerImageAttachmentUnsupportedType.code}]',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Image attach failed'), findsOneWidget);
    expect(find.textContaining('Unsupported image type.'), findsOneWidget);
  });

  testWidgets('shows a typed snackbar for unexpected image attachment failures', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildComposerApp(
        contract: composerContract(allowsImageAttachment: true),
        imageAttachmentPicker: () async {
          throw StateError('picker bridge failed');
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('attach_image')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        '[${PocketErrorCatalog.chatComposerImageAttachmentUnexpectedFailure.code}]',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Image attach failed'), findsOneWidget);
    expect(
      find.textContaining('Underlying error: picker bridge failed'),
      findsOneWidget,
    );
  });
}
