import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';

bool supportsLocalAgentAdapterConnection([TargetPlatform? platform]) {
  return PocketPlatformBehavior.resolve(
    platform: platform,
    isWeb: kIsWeb,
  ).supportsLocalConnectionMode;
}

@Deprecated('Use supportsLocalAgentAdapterConnection instead.')
bool supportsLocalCodexConnection([TargetPlatform? platform]) {
  return supportsLocalAgentAdapterConnection(platform);
}
