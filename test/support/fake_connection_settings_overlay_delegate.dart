import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_renderer.dart';

class FakeConnectionSettingsOverlayDelegate
    implements ConnectionSettingsOverlayDelegate {
  FakeConnectionSettingsOverlayDelegate({
    List<ConnectionSettingsSubmitPayload?> results =
        const <ConnectionSettingsSubmitPayload?>[],
  }) : _results = List<ConnectionSettingsSubmitPayload?>.from(results);

  final List<ConnectionSettingsSubmitPayload?> _results;
  final List<(ConnectionProfile, ConnectionSecrets)> launchedSettings =
      <(ConnectionProfile, ConnectionSecrets)>[];
  final List<ConnectionSettingsRenderer> renderers =
      <ConnectionSettingsRenderer>[];

  @override
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ConnectionProfile initialProfile,
    required ConnectionSecrets initialSecrets,
    required PocketPlatformBehavior platformBehavior,
    required ConnectionSettingsRenderer renderer,
  }) async {
    launchedSettings.add((initialProfile, initialSecrets));
    renderers.add(renderer);
    if (_results.isEmpty) {
      return null;
    }
    return _results.removeAt(0);
  }
}
