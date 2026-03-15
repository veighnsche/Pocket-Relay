import 'package:flutter/material.dart';

enum ChatRootRegion { appChrome, transcript, composer, settingsOverlay }

enum ChatRootScreenShellRenderer { flutter, cupertino }

enum ChatRootRegionRenderer { flutter, cupertino }

class ChatRootRegionPolicy {
  const ChatRootRegionPolicy({
    required this.screenShell,
    required this.appChrome,
    required this.transcript,
    required this.composer,
    required this.settingsOverlay,
  });

  const ChatRootRegionPolicy.allFlutter()
    : this(
        screenShell: ChatRootScreenShellRenderer.flutter,
        appChrome: ChatRootRegionRenderer.flutter,
        transcript: ChatRootRegionRenderer.flutter,
        composer: ChatRootRegionRenderer.flutter,
        settingsOverlay: ChatRootRegionRenderer.flutter,
      );

  const ChatRootRegionPolicy.cupertinoFoundation()
    : this(
        screenShell: ChatRootScreenShellRenderer.cupertino,
        appChrome: ChatRootRegionRenderer.cupertino,
        transcript: ChatRootRegionRenderer.flutter,
        composer: ChatRootRegionRenderer.cupertino,
        settingsOverlay: ChatRootRegionRenderer.cupertino,
      );

  final ChatRootScreenShellRenderer screenShell;
  final ChatRootRegionRenderer appChrome;
  final ChatRootRegionRenderer transcript;
  final ChatRootRegionRenderer composer;
  final ChatRootRegionRenderer settingsOverlay;

  ChatRootRegionRenderer rendererFor(ChatRootRegion region) {
    return switch (region) {
      ChatRootRegion.appChrome => appChrome,
      ChatRootRegion.transcript => transcript,
      ChatRootRegion.composer => composer,
      ChatRootRegion.settingsOverlay => settingsOverlay,
    };
  }
}

class ChatRootPlatformPolicy {
  const ChatRootPlatformPolicy({required this.fallback, required this.iOS});

  const ChatRootPlatformPolicy.allFlutter()
    : this(
        fallback: const ChatRootRegionPolicy.allFlutter(),
        iOS: const ChatRootRegionPolicy.allFlutter(),
      );

  const ChatRootPlatformPolicy.cupertinoFoundation()
    : this(
        fallback: const ChatRootRegionPolicy.allFlutter(),
        iOS: const ChatRootRegionPolicy.cupertinoFoundation(),
      );

  final ChatRootRegionPolicy fallback;
  final ChatRootRegionPolicy iOS;

  ChatRootRegionPolicy policyFor(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.iOS => iOS,
      _ => fallback,
    };
  }
}
