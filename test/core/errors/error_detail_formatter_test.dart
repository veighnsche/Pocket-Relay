import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/errors/pocket_error_detail_formatter.dart';

void main() {
  test('normalizer strips known exception wrappers', () {
    expect(
      PocketErrorDetailFormatter.normalize(
        const _StringLikeError('CodexAppServerException: transport broke'),
      ),
      'transport broke',
    );
  });

  test('normalizer optionally strips remote owner control prefixes', () {
    expect(
      PocketErrorDetailFormatter.normalize(
        const _StringLikeError(
          'Remote owner control command failed: exit 1 | tmux is not available on the remote host.',
        ),
        stripRemoteOwnerControlFailure: true,
      ),
      'exit 1 | tmux is not available on the remote host.',
    );
  });

  test('typed errors append unique underlying detail once', () {
    final error =
        PocketUserFacingError(
          definition: PocketErrorCatalog.chatSessionSendFailed,
          title: 'Send failed',
          message: 'Could not send the prompt to the remote Codex session.',
        ).withNormalizedUnderlyingError(
          const _StringLikeError('CodexAppServerException: transport broke'),
        );

    expect(error.inlineMessage, contains('Underlying error: transport broke'));
    expect(error.bodyWithCode, contains('Underlying error: transport broke'));
  });

  test('typed errors suppress duplicate underlying detail', () {
    const message = 'Could not send the prompt to the remote Codex session.';
    final error = PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionSendFailed,
      title: 'Send failed',
      message: message,
    ).withNormalizedUnderlyingError(const _StringLikeError(message));

    expect(
      error.inlineMessage,
      '[${PocketErrorCatalog.chatSessionSendFailed.code}] Send failed. $message',
    );
    expect(error.inlineMessage, isNot(contains('Underlying error:')));
  });
}

final class _StringLikeError {
  const _StringLikeError(this.value);

  final String value;

  @override
  String toString() => value;
}
