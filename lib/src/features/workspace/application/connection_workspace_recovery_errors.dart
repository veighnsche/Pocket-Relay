import 'package:pocket_relay/src/core/errors/pocket_error.dart';

abstract final class ConnectionWorkspaceRecoveryErrors {
  static PocketUserFacingError recoveryStateLoadFailed({Object? error}) {
    return const PocketUserFacingError(
      definition: PocketErrorCatalog.appBootstrapRecoveryStateLoadFailed,
      title: 'Local recovery unavailable',
      message:
          'Pocket Relay could not restore the previous lane state from this device. Startup continued without local recovery data.',
    ).withNormalizedUnderlyingError(error);
  }
}
