import 'package:flutter/foundation.dart';

enum PocketPlatformExperience { mobile, desktop }

class PocketPlatformBehavior {
  const PocketPlatformBehavior({
    required this.experience,
    required this.supportsLocalConnectionMode,
    required this.supportsWakeLock,
    required this.supportsFiniteBackgroundGrace,
    required this.supportsActiveTurnForegroundService,
    required this.usesDesktopKeyboardSubmit,
    required this.supportsCollapsibleDesktopSidebar,
  });

  factory PocketPlatformBehavior.resolve({
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
  }) {
    final resolvedPlatform = platform ?? defaultTargetPlatform;
    final isDesktopExperience = switch (resolvedPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };

    return PocketPlatformBehavior(
      experience: isDesktopExperience
          ? PocketPlatformExperience.desktop
          : PocketPlatformExperience.mobile,
      supportsLocalConnectionMode: !isWeb && isDesktopExperience,
      supportsWakeLock:
          !isWeb &&
          switch (resolvedPlatform) {
            TargetPlatform.android || TargetPlatform.iOS => true,
            _ => false,
          },
      supportsFiniteBackgroundGrace:
          !isWeb && resolvedPlatform == TargetPlatform.iOS,
      supportsActiveTurnForegroundService:
          !isWeb && resolvedPlatform == TargetPlatform.android,
      usesDesktopKeyboardSubmit: isDesktopExperience,
      supportsCollapsibleDesktopSidebar:
          !isWeb && resolvedPlatform == TargetPlatform.macOS,
    );
  }

  final PocketPlatformExperience experience;
  final bool supportsLocalConnectionMode;
  final bool supportsWakeLock;
  final bool supportsFiniteBackgroundGrace;
  final bool supportsActiveTurnForegroundService;
  final bool usesDesktopKeyboardSubmit;
  final bool supportsCollapsibleDesktopSidebar;

  bool get isDesktopExperience =>
      experience == PocketPlatformExperience.desktop;

  bool get isMobileExperience => experience == PocketPlatformExperience.mobile;
}
