part of 'chat_session_controller.dart';

extension _ChatSessionControllerModelCapabilities on ChatSessionController {
  Future<void> _refreshModelCatalogAfterConnect() async {
    if (!agentAdapterCapabilities.supportsModelCatalogRefresh) {
      return;
    }
    if (!agentAdapterClient.isConnected) {
      return;
    }
    if (_didAttemptModelCatalogHydration) {
      if (_modelCatalogHydrationFuture case final hydration?) {
        await hydration;
      }
      return;
    }

    final hydration = _hydrateModelCatalog();
    _modelCatalogHydrationFuture = hydration;
    try {
      await hydration;
    } catch (_) {
      if (identical(_modelCatalogHydrationFuture, hydration)) {
        _didAttemptModelCatalogHydration = false;
        _modelCatalogHydrationFuture = null;
      }
      rethrow;
    } finally {
      if (identical(_modelCatalogHydrationFuture, hydration)) {
        _modelCatalogHydrationFuture = null;
      }
    }
  }

  Future<bool> _ensureImageInputsSupportedForDraft(
    ChatComposerDraft draft,
  ) async {
    if (!draft.hasImageAttachments) {
      return true;
    }
    if (!agentAdapterCapabilities.supportsImageInput) {
      _emitUserFacingError(_imageInputsNotSupportedError());
      return false;
    }

    try {
      await _ensureChatSessionAppServerConnected(this);
    } catch (error) {
      final userFacingError = ChatSessionErrors.imageSupportCheckFailed();
      _reportAppServerFailure(
        userFacingError: userFacingError,
        runtimeErrorMessage: ChatSessionErrors.runtimeMessage(
          userFacingError,
          error: error,
        ),
      );
      return false;
    }

    if (_currentModelSupportsImageInput()) {
      return true;
    }

    _emitUserFacingError(_imageInputsNotSupportedError());
    return false;
  }

  bool _currentModelSupportsImageInput() {
    if (!agentAdapterCapabilities.supportsImageInput) {
      return false;
    }
    final catalog = _modelCatalog;
    final effectiveModel = _effectiveModelForCapabilities(catalog);
    if (effectiveModel == null || catalog == null) {
      return true;
    }

    for (final model in catalog) {
      if (model.model == effectiveModel) {
        return model.supportsImageInput;
      }
    }
    return true;
  }

  void _resetModelCatalogHydration() {
    final hadState =
        _modelCatalog != null ||
        _didAttemptModelCatalogHydration ||
        _modelCatalogHydrationFuture != null;
    _modelCatalog = null;
    _didAttemptModelCatalogHydration = false;
    _modelCatalogHydrationFuture = null;
    if (hadState) {
      _notifyListenersIfMounted();
    }
  }

  Future<void> _hydrateModelCatalog() async {
    _didAttemptModelCatalogHydration = true;
    String? cursor;
    final models = <AgentAdapterModel>[];
    do {
      final page = await agentAdapterClient.listModels(
        cursor: cursor,
        includeHidden: true,
      );
      models.addAll(page.models);
      cursor = page.nextCursor?.trim();
      if (cursor != null && cursor.isEmpty) {
        cursor = null;
      }
    } while (cursor != null);

    if (_isDisposed) {
      return;
    }
    if (listEquals(_modelCatalog, models)) {
      return;
    }
    _modelCatalog = List<AgentAdapterModel>.unmodifiable(models);
    _notifyListenersIfMounted();
  }

  PocketUserFacingError _imageInputsNotSupportedError() {
    return ChatSessionGuardrailErrors.imageInputUnsupported(
      model: _effectiveModelForCapabilities(_modelCatalog),
    );
  }

  String? _effectiveModelForCapabilities([List<AgentAdapterModel>? catalog]) {
    final configuredModel = _profile.model.trim();
    if (configuredModel.isNotEmpty) {
      return configuredModel;
    }
    final liveModel = _sessionState.headerMetadata.model?.trim();
    if (liveModel != null && liveModel.isNotEmpty) {
      return liveModel;
    }

    final effectiveCatalog = catalog ?? _modelCatalog;
    if (effectiveCatalog == null) {
      return null;
    }
    for (final model in effectiveCatalog) {
      if (model.isDefault) {
        final modelName = model.model.trim();
        if (modelName.isNotEmpty) {
          return modelName;
        }
      }
    }
    return null;
  }
}
