import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_host.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';

class FakeConnectionSettingsOverlayDelegate
    implements ConnectionSettingsOverlayDelegate {
  FakeConnectionSettingsOverlayDelegate({
    List<ConnectionSettingsSubmitPayload?> results =
        const <ConnectionSettingsSubmitPayload?>[],
  }) : _results = List<ConnectionSettingsSubmitPayload?>.from(results);

  final List<ConnectionSettingsSubmitPayload?> _results;
  final List<(ConnectionProfile, ConnectionSecrets)> launchedSettings =
      <(ConnectionProfile, ConnectionSecrets)>[];
  final List<ConnectionModelCatalog?> launchedModelCatalogs =
      <ConnectionModelCatalog?>[];
  final List<ConnectionRemoteRuntimeState?> launchedInitialRemoteRuntimes =
      <ConnectionRemoteRuntimeState?>[];
  final List<ConnectionSettingsModelCatalogSource?>
  launchedModelCatalogSources = <ConnectionSettingsModelCatalogSource?>[];
  final List<
    Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
  >
  launchedRefreshCallbacks =
      <
        Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
      >[];
  final List<ConnectionSettingsRemoteRuntimeRefresher?>
  launchedRemoteRuntimeCallbacks =
      <ConnectionSettingsRemoteRuntimeRefresher?>[];

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
  }) async {
    launchedSettings.add((initialProfile, initialSecrets));
    launchedModelCatalogs.add(availableModelCatalog);
    launchedInitialRemoteRuntimes.add(initialRemoteRuntime);
    launchedModelCatalogSources.add(availableModelCatalogSource);
    launchedRefreshCallbacks.add(onRefreshModelCatalog);
    launchedRemoteRuntimeCallbacks.add(onRefreshRemoteRuntime);
    if (_results.isEmpty) {
      return null;
    }
    return _results.removeAt(0);
  }
}
