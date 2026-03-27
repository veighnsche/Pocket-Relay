import 'package:pocket_relay/src/core/errors/pocket_error.dart';

abstract final class ChatComposerImageAttachmentErrors {
  static PocketUserFacingError emptyImage() {
    return const PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionImageAttachmentEmpty,
      title: 'Image attach failed',
      message: 'The selected image was empty.',
    );
  }

  static PocketUserFacingError sourceTooLarge() {
    return const PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionImageAttachmentTooLarge,
      title: 'Image attach failed',
      message: 'Images larger than 50 MB are not supported.',
    );
  }

  static PocketUserFacingError unsupportedType() {
    return const PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionImageAttachmentUnsupportedType,
      title: 'Image attach failed',
      message: 'Unsupported image type.',
    );
  }

  static PocketUserFacingError decodeFailed() {
    return const PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionImageAttachmentDecodeFailed,
      title: 'Image attach failed',
      message: 'The selected file could not be decoded as an image.',
    );
  }

  static PocketUserFacingError tooLargeForRemote() {
    return const PocketUserFacingError(
      definition:
          PocketErrorCatalog.chatSessionImageAttachmentTooLargeForRemote,
      title: 'Image attach failed',
      message:
          'Could not shrink this image enough for remote sending. Choose a smaller image.',
    );
  }

  static PocketUserFacingError unexpected() {
    return const PocketUserFacingError(
      definition:
          PocketErrorCatalog.chatSessionImageAttachmentUnexpectedFailure,
      title: 'Image attach failed',
      message: 'Could not attach the selected image.',
    );
  }
}
