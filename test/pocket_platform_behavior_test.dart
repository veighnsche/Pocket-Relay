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
    expect(policy.usesDesktopKeyboardSubmit, isTrue);
  });

  test('resolves mobile behavior from mobile platforms', () {
    final policy = PocketPlatformBehavior.resolve(platform: TargetPlatform.iOS);

    expect(policy.experience, PocketPlatformExperience.mobile);
    expect(policy.supportsLocalConnectionMode, isFalse);
    expect(policy.supportsWakeLock, isTrue);
    expect(policy.usesDesktopKeyboardSubmit, isFalse);
  });

  test('keeps desktop experience separate from desktop-only capabilities', () {
    final policy = PocketPlatformBehavior.resolve(
      platform: TargetPlatform.windows,
      isWeb: true,
    );

    expect(policy.experience, PocketPlatformExperience.desktop);
    expect(policy.supportsLocalConnectionMode, isFalse);
    expect(policy.supportsWakeLock, isFalse);
    expect(policy.usesDesktopKeyboardSubmit, isTrue);
  });
}
