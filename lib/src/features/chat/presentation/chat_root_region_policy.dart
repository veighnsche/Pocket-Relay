import 'package:flutter/material.dart';

enum ChatRootRegion {
  appChrome,
  transcript,
  composer,
  settingsOverlay,
  feedbackOverlay,
  emptyState,
}

enum ChatRootScreenShellRenderer { flutter, cupertino }

enum ChatRootRegionRenderer { flutter, cupertino }

class ChatRootRegionPolicy {
  const ChatRootRegionPolicy({
    required this.screenShell,
    required this.appChrome,
    required this.transcript,
    required this.composer,
    required this.settingsOverlay,
    required this.feedbackOverlay,
    required this.emptyState,
  });

  const ChatRootRegionPolicy.allFlutter()
    : this(
        screenShell: ChatRootScreenShellRenderer.flutter,
        appChrome: ChatRootRegionRenderer.flutter,
        transcript: ChatRootRegionRenderer.flutter,
        composer: ChatRootRegionRenderer.flutter,
        settingsOverlay: ChatRootRegionRenderer.flutter,
        feedbackOverlay: ChatRootRegionRenderer.flutter,
        emptyState: ChatRootRegionRenderer.flutter,
      );

  const ChatRootRegionPolicy.cupertinoFoundation()
    : this(
        screenShell: ChatRootScreenShellRenderer.cupertino,
        appChrome: ChatRootRegionRenderer.cupertino,
        transcript: ChatRootRegionRenderer.flutter,
        composer: ChatRootRegionRenderer.cupertino,
        settingsOverlay: ChatRootRegionRenderer.cupertino,
        feedbackOverlay: ChatRootRegionRenderer.cupertino,
        emptyState: ChatRootRegionRenderer.cupertino,
      );

  final ChatRootScreenShellRenderer screenShell;
  final ChatRootRegionRenderer appChrome;
  final ChatRootRegionRenderer transcript;
  final ChatRootRegionRenderer composer;
  final ChatRootRegionRenderer settingsOverlay;
  final ChatRootRegionRenderer feedbackOverlay;
  final ChatRootRegionRenderer emptyState;

  ChatRootRegionRenderer rendererFor(ChatRootRegion region) {
    return switch (region) {
      ChatRootRegion.appChrome => appChrome,
      ChatRootRegion.transcript => transcript,
      ChatRootRegion.composer => composer,
      ChatRootRegion.settingsOverlay => settingsOverlay,
      ChatRootRegion.feedbackOverlay => feedbackOverlay,
      ChatRootRegion.emptyState => emptyState,
    };
  }
}

class ChatRootPlatformPolicy {
  const ChatRootPlatformPolicy({
    required this.fallback,
    required this.iOS,
    required this.macOS,
  });

  const ChatRootPlatformPolicy.allFlutter()
    : this(
        fallback: const ChatRootRegionPolicy.allFlutter(),
        iOS: const ChatRootRegionPolicy.allFlutter(),
        macOS: const ChatRootRegionPolicy.allFlutter(),
      );

  const ChatRootPlatformPolicy.cupertinoFoundation()
    : this(
        fallback: const ChatRootRegionPolicy.allFlutter(),
        iOS: const ChatRootRegionPolicy.cupertinoFoundation(),
        macOS: const ChatRootRegionPolicy.cupertinoFoundation(),
      );

  final ChatRootRegionPolicy fallback;
  final ChatRootRegionPolicy iOS;
  final ChatRootRegionPolicy macOS;

  ChatRootRegionPolicy policyFor(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.iOS => iOS,
      TargetPlatform.macOS => macOS,
      _ => fallback,
    };
  }
}
