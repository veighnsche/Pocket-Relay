import 'package:pocket_relay/src/core/errors/pocket_error.dart';

abstract final class DeviceCapabilityErrors {
  static PocketUserFacingError foregroundServicePermissionQueryFailed({
    Object? error,
  }) {
    return const PocketUserFacingError(
      definition:
          PocketErrorCatalog.deviceForegroundServicePermissionQueryFailed,
      title: 'Foreground service unavailable',
      message:
          'Pocket Relay could not verify notification permission for Android active-turn continuity. Foreground service continuity will stay off until this succeeds.',
    ).withNormalizedUnderlyingError(error);
  }

  static PocketUserFacingError foregroundServicePermissionRequestFailed({
    Object? error,
  }) {
    return const PocketUserFacingError(
      definition:
          PocketErrorCatalog.deviceForegroundServicePermissionRequestFailed,
      title: 'Foreground service unavailable',
      message:
          'Pocket Relay could not request notification permission for Android active-turn continuity. Foreground service continuity will stay off until this succeeds.',
    ).withNormalizedUnderlyingError(error);
  }

  static PocketUserFacingError foregroundServiceEnableFailed({Object? error}) {
    return const PocketUserFacingError(
      definition: PocketErrorCatalog.deviceForegroundServiceEnableFailed,
      title: 'Foreground service unavailable',
      message:
          'Pocket Relay could not change the Android foreground service state for active-turn continuity.',
    ).withNormalizedUnderlyingError(error);
  }

  static PocketUserFacingError backgroundGraceEnableFailed({Object? error}) {
    return const PocketUserFacingError(
      definition: PocketErrorCatalog.deviceBackgroundGraceEnableFailed,
      title: 'Background grace unavailable',
      message:
          'Pocket Relay could not change the background grace state that protects an active turn while the app is backgrounded.',
    ).withNormalizedUnderlyingError(error);
  }

  static PocketUserFacingError wakeLockEnableFailed({Object? error}) {
    return const PocketUserFacingError(
      definition: PocketErrorCatalog.deviceWakeLockEnableFailed,
      title: 'Wake lock unavailable',
      message:
          'Pocket Relay could not change the display wake lock that protects an active turn while the app stays in the foreground.',
    ).withNormalizedUnderlyingError(error);
  }
}
