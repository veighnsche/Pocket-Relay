import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/changed_files_surface.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';

abstract interface class ChatRootOverlayDelegate {
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ChatConnectionSettingsLaunchContract connectionSettings,
    required PocketPlatformBehavior platformBehavior,
  });

  Future<void> openChangedFileDiff({
    required BuildContext context,
    required ChatChangedFileDiffContract diff,
  });

  void showTransientFeedback({
    required BuildContext context,
    required String message,
  });
}

class FlutterChatRootOverlayDelegate implements ChatRootOverlayDelegate {
  const FlutterChatRootOverlayDelegate({
    ConnectionSettingsOverlayDelegate settingsOverlayDelegate =
        const ModalConnectionSettingsOverlayDelegate(),
  }) : _settingsOverlayDelegate = settingsOverlayDelegate;

  final ConnectionSettingsOverlayDelegate _settingsOverlayDelegate;

  @override
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ChatConnectionSettingsLaunchContract connectionSettings,
    required PocketPlatformBehavior platformBehavior,
  }) {
    return _settingsOverlayDelegate.openConnectionSettings(
      context: context,
      initialProfile: connectionSettings.initialProfile,
      initialSecrets: connectionSettings.initialSecrets,
      platformBehavior: platformBehavior,
      availableModelCatalog: null,
      allowReferenceModelFallback: false,
      onRefreshModelCatalog: null,
    );
  }

  @override
  Future<void> openChangedFileDiff({
    required BuildContext context,
    required ChatChangedFileDiffContract diff,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ChangedFileDiffSheet(diff: diff);
      },
    );
  }

  @override
  void showTransientFeedback({
    required BuildContext context,
    required String message,
  }) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
