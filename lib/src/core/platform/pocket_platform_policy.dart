import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';

class PocketPlatformPolicy {
  const PocketPlatformPolicy({required this.behavior});

  factory PocketPlatformPolicy.resolve({
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
  }) {
    final resolvedPlatform = platform ?? defaultTargetPlatform;
    return PocketPlatformPolicy(
      behavior: PocketPlatformBehavior.resolve(
        platform: resolvedPlatform,
        isWeb: isWeb,
      ),
    );
  }

  final PocketPlatformBehavior behavior;

  bool get supportsLocalConnectionMode => behavior.supportsLocalConnectionMode;

  bool get supportsWakeLock => behavior.supportsWakeLock;

  bool get supportsFiniteBackgroundGrace =>
      behavior.supportsFiniteBackgroundGrace;
}
