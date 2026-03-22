import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';

void main() {
  test('resolves desktop behavior from desktop platforms', () {
    final policy = PocketPlatformBehavior.resolve(
      platform: TargetPlatform.macOS,
    );

    expect(policy.experience, PocketPlatformExperience.desktop);
    expect(policy.supportsLocalConnectionMode, isTrue);
    expect(policy.supportsWakeLock, isFalse);
    expect(policy.supportsFiniteBackgroundGrace, isFalse);
    expect(policy.supportsActiveTurnForegroundService, isFalse);
    expect(policy.usesDesktopKeyboardSubmit, isTrue);
  });

  test('resolves iOS behavior from mobile platforms', () {
    final policy = PocketPlatformBehavior.resolve(platform: TargetPlatform.iOS);

    expect(policy.experience, PocketPlatformExperience.mobile);
    expect(policy.supportsLocalConnectionMode, isFalse);
    expect(policy.supportsWakeLock, isTrue);
    expect(policy.supportsFiniteBackgroundGrace, isTrue);
    expect(policy.supportsActiveTurnForegroundService, isFalse);
    expect(policy.usesDesktopKeyboardSubmit, isFalse);
  });

  test('resolves Android active-turn foreground service support', () {
    final policy = PocketPlatformBehavior.resolve(
      platform: TargetPlatform.android,
    );

    expect(policy.experience, PocketPlatformExperience.mobile);
    expect(policy.supportsWakeLock, isTrue);
    expect(policy.supportsFiniteBackgroundGrace, isFalse);
    expect(policy.supportsActiveTurnForegroundService, isTrue);
  });

  test('keeps desktop experience separate from desktop-only capabilities', () {
    final policy = PocketPlatformBehavior.resolve(
      platform: TargetPlatform.windows,
      isWeb: true,
    );

    expect(policy.experience, PocketPlatformExperience.desktop);
    expect(policy.supportsLocalConnectionMode, isFalse);
    expect(policy.supportsWakeLock, isFalse);
    expect(policy.supportsFiniteBackgroundGrace, isFalse);
    expect(policy.supportsActiveTurnForegroundService, isFalse);
    expect(policy.usesDesktopKeyboardSubmit, isTrue);
  });
}
