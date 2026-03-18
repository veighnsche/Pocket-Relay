import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';

class ConnectionWorkspaceState {
  const ConnectionWorkspaceState({
    required this.isLoading,
    required this.catalog,
    required this.liveConnectionIds,
    required this.selectedConnectionId,
  });

  const ConnectionWorkspaceState.initial()
    : isLoading = true,
      catalog = const ConnectionCatalogState.empty(),
      liveConnectionIds = const <String>[],
      selectedConnectionId = null;

  final bool isLoading;
  final ConnectionCatalogState catalog;
  final List<String> liveConnectionIds;
  final String? selectedConnectionId;

  List<String> get dormantConnectionIds {
    return <String>[
      for (final connectionId in catalog.orderedConnectionIds)
        if (!liveConnectionIds.contains(connectionId)) connectionId,
    ];
  }

  bool isConnectionLive(String connectionId) {
    return liveConnectionIds.contains(connectionId);
  }

  ConnectionWorkspaceState copyWith({
    bool? isLoading,
    ConnectionCatalogState? catalog,
    List<String>? liveConnectionIds,
    String? selectedConnectionId,
    bool clearSelectedConnectionId = false,
  }) {
    return ConnectionWorkspaceState(
      isLoading: isLoading ?? this.isLoading,
      catalog: catalog ?? this.catalog,
      liveConnectionIds: liveConnectionIds ?? this.liveConnectionIds,
      selectedConnectionId: clearSelectedConnectionId
          ? null
          : (selectedConnectionId ?? this.selectedConnectionId),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionWorkspaceState &&
        other.isLoading == isLoading &&
        other.catalog == catalog &&
        listEquals(other.liveConnectionIds, liveConnectionIds) &&
        other.selectedConnectionId == selectedConnectionId;
  }

  @override
  int get hashCode => Object.hash(
    isLoading,
    catalog,
    Object.hashAll(liveConnectionIds),
    selectedConnectionId,
  );
}
