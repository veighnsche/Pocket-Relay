import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_host.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_renderer.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_sheet.dart';
import 'package:pocket_relay/src/features/settings/presentation/cupertino_connection_sheet.dart';

abstract interface class ChatRootOverlayDelegate {
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ChatConnectionSettingsLaunchContract connectionSettings,
    required ConnectionSettingsRenderer renderer,
  });

  Future<void> openChangedFileDiff({
    required BuildContext context,
    required ChatChangedFileDiffContract diff,
  });

  void showSnackBar({required BuildContext context, required String message});
}

class FlutterChatRootOverlayDelegate implements ChatRootOverlayDelegate {
  const FlutterChatRootOverlayDelegate();

  @override
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ChatConnectionSettingsLaunchContract connectionSettings,
    required ConnectionSettingsRenderer renderer,
  }) {
    return switch (renderer) {
      ConnectionSettingsRenderer.material =>
        showModalBottomSheet<ConnectionSettingsSubmitPayload>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (sheetContext) {
            return ConnectionSettingsHost(
              initialProfile: connectionSettings.initialProfile,
              initialSecrets: connectionSettings.initialSecrets,
              onCancel: () => Navigator.of(sheetContext).pop(),
              onSubmit: (payload) {
                Navigator.of(sheetContext).pop(payload);
              },
              builder: (context, viewModel, actions) {
                return ConnectionSheet(viewModel: viewModel, actions: actions);
              },
            );
          },
        ),
      ConnectionSettingsRenderer.cupertino =>
        showCupertinoModalPopup<ConnectionSettingsSubmitPayload>(
          context: context,
          builder: (sheetContext) {
            return ConnectionSettingsHost(
              initialProfile: connectionSettings.initialProfile,
              initialSecrets: connectionSettings.initialSecrets,
              onCancel: () => Navigator.of(sheetContext).pop(),
              onSubmit: (payload) {
                Navigator.of(sheetContext).pop(payload);
              },
              builder: (context, viewModel, actions) {
                return CupertinoConnectionSheet(
                  viewModel: viewModel,
                  actions: actions,
                );
              },
            );
          },
        ),
    };
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
  void showSnackBar({required BuildContext context, required String message}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
