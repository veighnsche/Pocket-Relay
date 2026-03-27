import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_errors.dart';

void main() {
  test('model catalog unavailable maps to a stable connection-settings code', () {
    final error = ConnectionSettingsErrors.modelCatalogUnavailable();

    expect(
      error.definition,
      PocketErrorCatalog.connectionSettingsModelCatalogUnavailable,
    );
    expect(
      error.bodyWithCode,
      '[${PocketErrorCatalog.connectionSettingsModelCatalogUnavailable.code}] Could not load models from the backend.',
    );
  });

  test('thrown model refresh failures keep the stable code and detail', () {
    final error = ConnectionSettingsErrors.modelCatalogRefreshFailed(
      error: StateError('backend unavailable'),
    );

    expect(
      error.definition,
      PocketErrorCatalog.connectionSettingsModelCatalogRefreshFailed,
    );
    expect(
      error.inlineMessage,
      contains('Underlying error: backend unavailable'),
    );
  });

  test('remote runtime probe failures keep the stable code and detail', () {
    final error = ConnectionSettingsErrors.remoteRuntimeProbeFailed(
      error: StateError('ssh failed'),
    );

    expect(
      error.definition,
      PocketErrorCatalog.connectionSettingsRemoteRuntimeProbeFailed,
    );
    expect(error.bodyWithCode, contains('ssh failed'));
  });

  test(
    'connection cache persistence warnings keep the stable code and detail',
    () {
      final error = ConnectionSettingsErrors.modelCatalogCachePersistenceFailed(
        connectionCacheError: StateError('connection cache failed'),
      );

      expect(
        error.definition,
        PocketErrorCatalog
            .connectionSettingsModelCatalogConnectionCacheSaveFailed,
      );
      expect(error.inlineMessage, contains('connection cache failed'));
    },
  );

  test(
    'combined cache persistence warnings keep the combined code and both details',
    () {
      final error = ConnectionSettingsErrors.modelCatalogCachePersistenceFailed(
        connectionCacheError: StateError('connection cache failed'),
        lastKnownCacheError: StateError('last-known cache failed'),
      );

      expect(
        error.definition,
        PocketErrorCatalog.connectionSettingsModelCatalogCachePersistenceFailed,
      );
      expect(error.inlineMessage, contains('connection cache failed'));
      expect(error.inlineMessage, contains('last-known cache failed'));
    },
  );
}
