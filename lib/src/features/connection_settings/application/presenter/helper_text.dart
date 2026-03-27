part of '../connection_settings_presenter.dart';

String _refreshActionHelperText(_ConnectionSettingsPresentationState state) {
  if (state.isRefreshingModelCatalog) {
    return 'Refreshing available models from the backend.';
  }

  final cachedCatalogStatus = switch (state.availableModelCatalogSource) {
    ConnectionSettingsModelCatalogSource.connectionCache =>
      'Showing models cached for this connection.',
    ConnectionSettingsModelCatalogSource.lastKnownCache =>
      'Showing last-known models from a previous backend refresh. They may not match this connection until it refreshes.',
    null => null,
  };
  final cachedCatalogTimestamp = _catalogRefreshTimestamp(
    state.availableModelCatalogSource,
    state.availableModelCatalog?.fetchedAt,
  );
  final refreshFailureStatus = state.modelCatalogRefreshError?.bodyWithCode;
  final leadingStatus = _joinHelperText(<String?>[
    refreshFailureStatus,
    cachedCatalogStatus,
    cachedCatalogTimestamp,
  ]);

  if (state.draft.workspaceDir.trim().isEmpty) {
    return _joinHelperText(<String?>[
      leadingStatus,
      'Set a workspace directory to enable model refresh.',
    ]);
  }

  if (!state.supportsModelCatalogRefresh) {
    return _joinHelperText(<String?>[
      leadingStatus,
      'Model refresh is available when this settings sheet is opened from a live backend connection.',
    ]);
  }

  return _joinHelperText(<String?>[
    leadingStatus,
    state.modelCatalogRefreshError != null
        ? 'Use Refresh models to try again.'
        : 'Use Refresh models to update from the backend.',
  ]);
}

String? _catalogRefreshTimestamp(
  ConnectionSettingsModelCatalogSource? source,
  DateTime? fetchedAt,
) {
  if (source == null || fetchedAt == null) {
    return null;
  }

  final utc = fetchedAt.toUtc();
  final year = utc.year.toString().padLeft(4, '0');
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  final hour = utc.hour.toString().padLeft(2, '0');
  final minute = utc.minute.toString().padLeft(2, '0');
  return 'Last refreshed $year-$month-$day $hour:$minute UTC.';
}

String _joinHelperText(Iterable<String?> parts) {
  return parts
      .whereType<String>()
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .map(_normalizeHelperSentence)
      .join(' ');
}

String _normalizeHelperSentence(String part) {
  if (part.endsWith('.') || part.endsWith('!') || part.endsWith('?')) {
    return part;
  }
  return '$part.';
}
