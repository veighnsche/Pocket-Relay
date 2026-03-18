import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_region_policy.dart';

void main() {
  test('resolves cupertino foundation and mobile behavior from iOS', () {
    final policy = PocketPlatformPolicy.resolve(platform: TargetPlatform.iOS);

    expect(policy.behavior.experience, PocketPlatformExperience.mobile);
    expect(
      policy.regionPolicy.screenShell,
      ChatRootScreenShellRenderer.cupertino,
    );
    expect(
      policy.regionPolicy.rendererFor(ChatRootRegion.composer),
      ChatRootRegionRenderer.cupertino,
    );
    expect(
      policy.regionPolicy.rendererFor(ChatRootRegion.transcript),
      ChatRootRegionRenderer.flutter,
    );
  });

  test('resolves fallback foundation and desktop behavior from windows', () {
    final policy = PocketPlatformPolicy.resolve(
      platform: TargetPlatform.windows,
    );

    expect(policy.behavior.experience, PocketPlatformExperience.desktop);
    expect(policy.supportsLocalConnectionMode, isTrue);
    expect(
      policy.regionPolicy.screenShell,
      ChatRootScreenShellRenderer.flutter,
    );
  });
}
