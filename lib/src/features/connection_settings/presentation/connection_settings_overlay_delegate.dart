import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';

import '../domain/connection_settings_contract.dart';
import 'connection_settings_host.dart';
import 'connection_sheet.dart';

abstract interface class ConnectionSettingsOverlayDelegate {
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ConnectionProfile initialProfile,
    required ConnectionSecrets initialSecrets,
    required PocketPlatformBehavior platformBehavior,
    ConnectionRemoteRuntimeState? initialRemoteRuntime,
    ConnectionModelCatalog? availableModelCatalog,
    ConnectionSettingsModelCatalogSource? availableModelCatalogSource,
    Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
    onRefreshModelCatalog,
    ConnectionSettingsRemoteRuntimeRefresher? onRefreshRemoteRuntime,
    ConnectionSettingsRemoteServerActionRunner? onStartRemoteServer,
    ConnectionSettingsRemoteServerActionRunner? onStopRemoteServer,
    ConnectionSettingsRemoteServerActionRunner? onRestartRemoteServer,
  });
}

class ModalConnectionSettingsOverlayDelegate
    implements ConnectionSettingsOverlayDelegate {
  const ModalConnectionSettingsOverlayDelegate();

  @override
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ConnectionProfile initialProfile,
    required ConnectionSecrets initialSecrets,
    required PocketPlatformBehavior platformBehavior,
    ConnectionRemoteRuntimeState? initialRemoteRuntime,
    ConnectionModelCatalog? availableModelCatalog,
    ConnectionSettingsModelCatalogSource? availableModelCatalogSource,
    Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
    onRefreshModelCatalog,
    ConnectionSettingsRemoteRuntimeRefresher? onRefreshRemoteRuntime,
    ConnectionSettingsRemoteServerActionRunner? onStartRemoteServer,
    ConnectionSettingsRemoteServerActionRunner? onStopRemoteServer,
    ConnectionSettingsRemoteServerActionRunner? onRestartRemoteServer,
  }) {
    if (platformBehavior.isDesktopExperience) {
      return showDialog<ConnectionSettingsSubmitPayload>(
        context: context,
        builder: (dialogContext) {
          return ConnectionSettingsHost(
            initialProfile: initialProfile,
            initialSecrets: initialSecrets,
            availableModelCatalog: availableModelCatalog,
            availableModelCatalogSource: availableModelCatalogSource,
            onRefreshModelCatalog: onRefreshModelCatalog,
            platformBehavior: platformBehavior,
            onCancel: () => Navigator.of(dialogContext).pop(),
            onSubmit: (payload) {
              Navigator.of(dialogContext).pop(payload);
            },
            builder: (context, viewModel, actions) {
              return ConnectionSheet(
                platformBehavior: platformBehavior,
                viewModel: viewModel,
                actions: actions,
              );
            },
          );
        },
      );
    }

    return showModalBottomSheet<ConnectionSettingsSubmitPayload>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ConnectionSettingsHost(
          initialProfile: initialProfile,
          initialSecrets: initialSecrets,
          initialRemoteRuntime: initialRemoteRuntime,
          availableModelCatalog: availableModelCatalog,
          availableModelCatalogSource: availableModelCatalogSource,
          onRefreshModelCatalog: onRefreshModelCatalog,
          onRefreshRemoteRuntime: onRefreshRemoteRuntime,
          onStartRemoteServer: onStartRemoteServer,
          onStopRemoteServer: onStopRemoteServer,
          onRestartRemoteServer: onRestartRemoteServer,
          platformBehavior: platformBehavior,
          onCancel: () => Navigator.of(sheetContext).pop(),
          onSubmit: (payload) {
            Navigator.of(sheetContext).pop(payload);
          },
          builder: (context, viewModel, actions) {
            return ConnectionSheet(
              platformBehavior: platformBehavior,
              viewModel: viewModel,
              actions: actions,
            );
          },
        );
      },
    );
  }
}
