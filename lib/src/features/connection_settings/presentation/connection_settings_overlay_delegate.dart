import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_system_template.dart';

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
    List<ConnectionSettingsSystemTemplate> availableSystemTemplates =
        const <ConnectionSettingsSystemTemplate>[],
    Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
    onRefreshModelCatalog,
    ConnectionSettingsRemoteRuntimeRefresher? onRefreshRemoteRuntime,
    ConnectionSettingsSystemTester? onTestSystem,
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
    List<ConnectionSettingsSystemTemplate> availableSystemTemplates =
        const <ConnectionSettingsSystemTemplate>[],
    Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
    onRefreshModelCatalog,
    ConnectionSettingsRemoteRuntimeRefresher? onRefreshRemoteRuntime,
    ConnectionSettingsSystemTester? onTestSystem,
  }) {
    if (platformBehavior.isDesktopExperience) {
      return showDialog<ConnectionSettingsSubmitPayload>(
        context: context,
        builder: (dialogContext) {
          return ConnectionSettingsHost(
            initialProfile: initialProfile,
            initialSecrets: initialSecrets,
            initialRemoteRuntime: initialRemoteRuntime,
            availableModelCatalog: availableModelCatalog,
            availableModelCatalogSource: availableModelCatalogSource,
            availableSystemTemplates: availableSystemTemplates,
            onRefreshModelCatalog: onRefreshModelCatalog,
            onRefreshRemoteRuntime: onRefreshRemoteRuntime,
            onTestSystem: onTestSystem,
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
          availableSystemTemplates: availableSystemTemplates,
          onRefreshModelCatalog: onRefreshModelCatalog,
          onRefreshRemoteRuntime: onRefreshRemoteRuntime,
          onTestSystem: onTestSystem,
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
