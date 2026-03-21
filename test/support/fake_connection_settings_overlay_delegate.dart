import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
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

  @override
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ConnectionProfile initialProfile,
    required ConnectionSecrets initialSecrets,
    required PocketPlatformBehavior platformBehavior,
  }) async {
    launchedSettings.add((initialProfile, initialSecrets));
    if (_results.isEmpty) {
      return null;
    }
    return _results.removeAt(0);
  }
}
