import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';

void main() {
  test('resolves mobile behavior from iOS', () {
    final policy = PocketPlatformPolicy.resolve(platform: TargetPlatform.iOS);

    expect(policy.behavior.experience, PocketPlatformExperience.mobile);
    expect(policy.supportsFiniteBackgroundGrace, isTrue);
    expect(policy.supportsActiveTurnForegroundService, isFalse);
  });

  test('resolves active-turn foreground service support from Android', () {
    final policy = PocketPlatformPolicy.resolve(
      platform: TargetPlatform.android,
    );

    expect(policy.behavior.experience, PocketPlatformExperience.mobile);
    expect(policy.supportsFiniteBackgroundGrace, isFalse);
    expect(policy.supportsActiveTurnForegroundService, isTrue);
  });

  test('resolves desktop behavior from windows', () {
    final policy = PocketPlatformPolicy.resolve(
      platform: TargetPlatform.windows,
    );

    expect(policy.behavior.experience, PocketPlatformExperience.desktop);
    expect(policy.supportsLocalConnectionMode, isTrue);
    expect(policy.supportsFiniteBackgroundGrace, isFalse);
    expect(policy.supportsActiveTurnForegroundService, isFalse);
  });
}
