import 'package:pocket_relay/src/core/errors/pocket_error.dart';

abstract final class ChatComposerErrors {
  static PocketUserFacingError imageAttachmentEmpty() {
    return const PocketUserFacingError(
      definition: PocketErrorCatalog.chatComposerImageAttachmentEmpty,
      title: 'Image attach failed',
      message: 'The selected image was empty.',
    );
  }

  static PocketUserFacingError imageAttachmentTooLarge() {
    return const PocketUserFacingError(
      definition: PocketErrorCatalog.chatComposerImageAttachmentTooLarge,
      title: 'Image attach failed',
      message: 'Images larger than 50 MB are not supported.',
    );
  }

  static PocketUserFacingError imageAttachmentUnsupportedType() {
    return const PocketUserFacingError(
      definition: PocketErrorCatalog.chatComposerImageAttachmentUnsupportedType,
      title: 'Image attach failed',
      message: 'Unsupported image type.',
    );
  }

  static PocketUserFacingError imageAttachmentDecodeFailed() {
    return const PocketUserFacingError(
      definition: PocketErrorCatalog.chatComposerImageAttachmentDecodeFailed,
      title: 'Image attach failed',
      message: 'The selected file could not be decoded as an image.',
    );
  }

  static PocketUserFacingError imageAttachmentTooLargeForRemote() {
    return const PocketUserFacingError(
      definition:
          PocketErrorCatalog.chatComposerImageAttachmentTooLargeForRemote,
      title: 'Image attach failed',
      message:
          'Could not shrink this image enough for remote sending. Choose a smaller image.',
    );
  }

  static PocketUserFacingError imageAttachmentUnexpected({Object? error}) {
    return const PocketUserFacingError(
      definition:
          PocketErrorCatalog.chatComposerImageAttachmentUnexpectedFailure,
      title: 'Image attach failed',
      message: 'Could not attach the selected image.',
    ).withNormalizedUnderlyingError(error);
  }
}
