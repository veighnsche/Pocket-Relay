part of '../connection_settings_host.dart';

Future<void> _refreshConnectionSettingsModelCatalog(
  _ConnectionSettingsHostState state,
) async {
  final onRefreshModelCatalog = state.widget.onRefreshModelCatalog;
  if (onRefreshModelCatalog == null || state._isRefreshingModelCatalog) {
    return;
  }

  state._setStateInternal(() {
    state._isRefreshingModelCatalog = true;
    state._modelCatalogRefreshError = null;
  });

  try {
    final refreshedCatalog = await onRefreshModelCatalog(
      state._formState.draft,
    );
    if (!state.mounted) {
      return;
    }
    if (refreshedCatalog == null) {
      state._setStateInternal(() {
        state._modelCatalogRefreshError =
            ConnectionSettingsErrors.modelCatalogUnavailable();
      });
      return;
    }

    final selectedModelId = state._formState.draft.model.trim().isEmpty
        ? null
        : state._formState.draft.model.trim();
    final nextEffort = codexNormalizedReasoningEffortForModel(
      selectedModelId,
      state._formState.draft.reasoningEffort,
      availableModelCatalog: refreshedCatalog,
    );
    state._setStateInternal(() {
      state._availableModelCatalog = refreshedCatalog;
      state._availableModelCatalogSource =
          ConnectionSettingsModelCatalogSource.connectionCache;
      state._modelCatalogRefreshError = null;
      state._formState = state._formState.copyWith(
        draft: state._formState.draft.copyWith(reasoningEffort: nextEffort),
      );
    });
  } catch (error) {
    if (state.mounted) {
      state._setStateInternal(() {
        state._modelCatalogRefreshError =
            ConnectionSettingsErrors.modelCatalogRefreshFailed(error: error);
      });
    }
  } finally {
    if (state.mounted) {
      state._setStateInternal(() {
        state._isRefreshingModelCatalog = false;
      });
    }
  }
}
