import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_region_policy.dart';

class PocketPlatformPolicy {
  const PocketPlatformPolicy({
    required this.behavior,
    required this.regionPolicy,
  });

  factory PocketPlatformPolicy.resolve({
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
    ChatRootPlatformPolicy chatRootPlatformPolicy =
        const ChatRootPlatformPolicy.cupertinoFoundation(),
  }) {
    final resolvedPlatform = platform ?? defaultTargetPlatform;
    return PocketPlatformPolicy(
      behavior: PocketPlatformBehavior.resolve(
        platform: resolvedPlatform,
        isWeb: isWeb,
      ),
      regionPolicy: chatRootPlatformPolicy.policyFor(resolvedPlatform),
    );
  }

  final PocketPlatformBehavior behavior;
  final ChatRootRegionPolicy regionPolicy;

  bool get supportsLocalConnectionMode => behavior.supportsLocalConnectionMode;

  bool get supportsWakeLock => behavior.supportsWakeLock;
}
