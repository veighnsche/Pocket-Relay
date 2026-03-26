part of '../connection_settings_host.dart';

ConnectionSettingsContract _buildConnectionSettingsHostContract(
  _ConnectionSettingsHostState state, {
  ConnectionSettingsFormState? formState,
}) {
  return state._presenter.present(
    initialProfile: state.widget.initialProfile,
    initialSecrets: state.widget.initialSecrets,
    formState: formState ?? state._formState,
    remoteRuntime: state._remoteRuntime,
    availableModelCatalog: state._availableModelCatalog,
    availableModelCatalogSource: state._availableModelCatalogSource,
    didModelCatalogRefreshFail: state._didModelCatalogRefreshFail,
    supportsModelCatalogRefresh: state.widget.onRefreshModelCatalog != null,
    isRefreshingModelCatalog: state._isRefreshingModelCatalog,
    supportsLocalConnectionMode:
        state.widget.platformBehavior.supportsLocalConnectionMode,
  );
}

void _updateConnectionSettingsField(
  _ConnectionSettingsHostState state,
  ConnectionSettingsFieldId fieldId,
  String value,
) {
  state._setStateInternal(() {
    state._formState = state._formState.copyWith(
      draft: state._formState.draft.copyWithField(fieldId, value),
    );
  });
  if (state._shouldRefreshRemoteRuntimeForField(fieldId)) {
    state._scheduleRemoteRuntimeRefresh();
  }
}

void _updateConnectionSettingsConnectionMode(
  _ConnectionSettingsHostState state,
  ConnectionMode connectionMode,
) {
  state._setStateInternal(() {
    state._formState = state._formState.copyWith(
      draft: state._formState.draft.copyWithConnectionMode(connectionMode),
    );
  });
  state._scheduleRemoteRuntimeRefresh();
}

void _updateConnectionSettingsAuthMode(
  _ConnectionSettingsHostState state,
  AuthMode authMode,
) {
  state._setStateInternal(() {
    state._formState = state._formState.copyWith(
      draft: state._formState.draft.copyWith(authMode: authMode),
    );
  });
  state._scheduleRemoteRuntimeRefresh();
}

void _updateConnectionSettingsToggle(
  _ConnectionSettingsHostState state,
  ConnectionSettingsToggleId toggleId,
  bool value,
) {
  state._setStateInternal(() {
    state._formState = state._formState.copyWith(
      draft: state._formState.draft.copyWithToggle(toggleId, value),
    );
  });
}

void _updateConnectionSettingsReasoningEffort(
  _ConnectionSettingsHostState state,
  CodexReasoningEffort? reasoningEffort,
) {
  state._setStateInternal(() {
    state._formState = state._formState.copyWith(
      draft: state._formState.draft.copyWith(reasoningEffort: reasoningEffort),
    );
  });
}

void _updateConnectionSettingsModel(
  _ConnectionSettingsHostState state,
  String? modelId,
) {
  final normalizedModel = modelId?.trim() ?? '';
  final nextEffort = codexNormalizedReasoningEffortForModel(
    normalizedModel.isEmpty ? null : normalizedModel,
    state._formState.draft.reasoningEffort,
    availableModelCatalog: state._availableModelCatalog,
  );
  state._setStateInternal(() {
    state._formState = state._formState.copyWith(
      draft: state._formState.draft.copyWith(
        model: normalizedModel,
        reasoningEffort: nextEffort,
      ),
    );
  });
}

bool _shouldRefreshConnectionSettingsRemoteRuntimeForField(
  ConnectionSettingsFieldId fieldId,
) {
  return switch (fieldId) {
    ConnectionSettingsFieldId.host ||
    ConnectionSettingsFieldId.port ||
    ConnectionSettingsFieldId.username ||
    ConnectionSettingsFieldId.workspaceDir ||
    ConnectionSettingsFieldId.codexPath ||
    ConnectionSettingsFieldId.hostFingerprint ||
    ConnectionSettingsFieldId.password ||
    ConnectionSettingsFieldId.privateKeyPem ||
    ConnectionSettingsFieldId.privateKeyPassphrase => true,
    _ => false,
  };
}

void _saveConnectionSettingsHost(_ConnectionSettingsHostState state) {
  final nextState = state._formState.revealValidationErrors();
  final contract = state._buildContract(nextState);
  state._setStateInternal(() {
    state._formState = nextState;
  });

  final payload = contract.saveAction.submitPayload;
  if (!contract.saveAction.canSubmit || payload == null) {
    return;
  }

  state.widget.onSubmit(payload);
}
