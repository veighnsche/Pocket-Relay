import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/errors/pocket_error_detail_formatter.dart';

abstract final class ConnectionSettingsErrors {
  static PocketUserFacingError modelCatalogUnavailable() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.connectionSettingsModelCatalogUnavailable,
      title: 'Model refresh failed',
      message: 'Could not load models from the backend.',
    );
  }

  static PocketUserFacingError modelCatalogRefreshFailed({Object? error}) {
    return PocketUserFacingError(
      definition:
          PocketErrorCatalog.connectionSettingsModelCatalogRefreshFailed,
      title: 'Model refresh failed',
      message: 'Could not load models from the backend.',
    ).withNormalizedUnderlyingError(error);
  }

  static PocketUserFacingError modelCatalogCachePersistenceFailed({
    Object? connectionCacheError,
    Object? lastKnownCacheError,
  }) {
    final connectionDetail = PocketErrorDetailFormatter.normalize(
      connectionCacheError,
    );
    final lastKnownDetail = PocketErrorDetailFormatter.normalize(
      lastKnownCacheError,
    );

    if (connectionDetail != null && lastKnownDetail != null) {
      return const PocketUserFacingError(
        definition: PocketErrorCatalog
            .connectionSettingsModelCatalogCachePersistenceFailed,
        title: 'Model refresh warning',
        message:
            'Fresh models loaded, but Pocket Relay could not save either local model cache.',
      ).withUnderlyingDetail(
        'Connection cache: $connectionDetail\nLast-known cache: $lastKnownDetail',
      );
    }

    if (connectionDetail != null) {
      return const PocketUserFacingError(
        definition: PocketErrorCatalog
            .connectionSettingsModelCatalogConnectionCacheSaveFailed,
        title: 'Model refresh warning',
        message:
            'Fresh models loaded, but Pocket Relay could not save this connection cache.',
      ).withUnderlyingDetail(connectionDetail);
    }

    if (lastKnownDetail != null) {
      return const PocketUserFacingError(
        definition: PocketErrorCatalog
            .connectionSettingsModelCatalogLastKnownCacheSaveFailed,
        title: 'Model refresh warning',
        message:
            'Fresh models loaded, but Pocket Relay could not update the last-known model cache.',
      ).withUnderlyingDetail(lastKnownDetail);
    }

    return const PocketUserFacingError(
      definition: PocketErrorCatalog
          .connectionSettingsModelCatalogCachePersistenceFailed,
      title: 'Model refresh warning',
      message:
          'Fresh models loaded, but Pocket Relay could not save the refreshed model catalog locally.',
    );
  }

  static PocketUserFacingError remoteRuntimeProbeFailed({Object? error}) {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.connectionSettingsRemoteRuntimeProbeFailed,
      title: 'System check failed',
      message: 'Could not verify the remote target.',
    ).withNormalizedUnderlyingError(error);
  }
}
