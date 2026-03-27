import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/features/chat/composer/application/chat_composer_errors.dart';

void main() {
  test(
    'unexpected image attachment failures keep a stable code and detail',
    () {
      final error = ChatComposerErrors.imageAttachmentUnexpected(
        error: StateError('picker bridge failed'),
      );

      expect(
        error.definition,
        PocketErrorCatalog.chatComposerImageAttachmentUnexpectedFailure,
      );
      expect(error.inlineMessage, contains('picker bridge failed'));
    },
  );
}
