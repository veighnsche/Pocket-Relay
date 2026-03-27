import 'package:pocket_relay/src/core/errors/pocket_error.dart';

abstract final class PocketRelayBootstrapErrors {
  static PocketUserFacingError workspaceInitializationFailed({Object? error}) {
    return const PocketUserFacingError(
      definition: PocketErrorCatalog.appBootstrapWorkspaceInitializationFailed,
      title: 'Workspace load failed',
      message: 'Pocket Relay could not finish loading your workspace.',
    ).withNormalizedUnderlyingError(error);
  }
}
