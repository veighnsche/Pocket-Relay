import 'package:flutter/foundation.dart';

bool supportsLocalCodexConnection([TargetPlatform? platform]) {
  if (kIsWeb) {
    return false;
  }

  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    _ => false,
  };
}
