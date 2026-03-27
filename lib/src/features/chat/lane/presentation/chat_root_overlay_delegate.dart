import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_work_log_terminal_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/changed_files_surface.dart';
import 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/work_log_terminal_sheet.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_remote_runtime_probe.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_system_probe.dart';
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

  Future<void> openWorkLogTerminal({
    required BuildContext context,
    required ChatWorkLogTerminalContract terminal,
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
      onRefreshModelCatalog: null,
      onRefreshRemoteRuntime: (payload) {
        return probeConnectionSettingsRemoteRuntime(payload: payload);
      },
      onTestSystem: (profile, secrets) {
        return testConnectionSettingsRemoteSystem(
          profile: profile,
          secrets: secrets,
        );
      },
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
  Future<void> openWorkLogTerminal({
    required BuildContext context,
    required ChatWorkLogTerminalContract terminal,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return WorkLogTerminalSheet(terminal: terminal);
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
