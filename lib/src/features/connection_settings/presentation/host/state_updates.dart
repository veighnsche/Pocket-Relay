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
    availableSystemTemplates: state._availableSystemTemplates,
    didModelCatalogRefreshFail: state._didModelCatalogRefreshFail,
    supportsModelCatalogRefresh: state.widget.onRefreshModelCatalog != null,
    isRefreshingModelCatalog: state._isRefreshingModelCatalog,
    isTestingSystem: state._isTestingSystem,
    systemTestFailure: state._systemTestFailure,
    supportsSystemTesting: state.widget.onTestSystem != null,
    supportsLocalConnectionMode:
        state.widget.platformBehavior.supportsLocalConnectionMode,
  );
}

void _updateConnectionSettingsField(
  _ConnectionSettingsHostState state,
  ConnectionSettingsFieldId fieldId,
  String value,
) {
  final previousDraft = state._formState.draft;
  var nextDraft = previousDraft.copyWithField(fieldId, value);
  if (_hostTrustSensitiveFields.contains(fieldId) &&
      _remoteHostIdentityChanged(previousDraft, nextDraft)) {
    nextDraft = nextDraft.copyWith(hostFingerprint: '');
  }

  state._setStateInternal(() {
    state._formState = state._formState.copyWith(draft: nextDraft);
    state._systemTestFailure = null;
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
    state._systemTestFailure = null;
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
    state._systemTestFailure = null;
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

void _selectConnectionSettingsSystemTemplate(
  _ConnectionSettingsHostState state,
  String? templateId,
) {
  if (templateId == null) {
    return;
  }

  ConnectionSettingsSystemTemplate? template;
  for (final candidate in state._availableSystemTemplates) {
    if (candidate.id == templateId) {
      template = candidate;
      break;
    }
  }
  if (template == null) {
    return;
  }

  final nextDraft = applyConnectionSettingsSystemTemplate(
    draft: state._formState.draft,
    template: template,
  );
  state._setStateInternal(() {
    state._formState = state._formState.copyWith(draft: nextDraft);
    state._systemTestFailure = null;
  });
  _syncConnectionSettingsControllers(
    state,
    nextDraft,
    fields: const <ConnectionSettingsFieldId>{
      ConnectionSettingsFieldId.host,
      ConnectionSettingsFieldId.port,
      ConnectionSettingsFieldId.username,
      ConnectionSettingsFieldId.hostFingerprint,
      ConnectionSettingsFieldId.password,
      ConnectionSettingsFieldId.privateKeyPem,
      ConnectionSettingsFieldId.privateKeyPassphrase,
    },
  );
  state._scheduleRemoteRuntimeRefresh();
}

Future<void> _testConnectionSettingsSystem(
  _ConnectionSettingsHostState state,
) async {
  final onTestSystem = state.widget.onTestSystem;
  if (onTestSystem == null || state._isTestingSystem) {
    return;
  }

  state._setStateInternal(() {
    state._isTestingSystem = true;
    state._systemTestFailure = null;
  });

  try {
    final result = await onTestSystem(
      _connectionSettingsSystemProfile(state),
      _connectionSettingsSystemSecrets(state),
    );
    if (!state.mounted) {
      return;
    }

    final nextDraft = state._formState.draft.copyWith(
      hostFingerprint: result.fingerprint,
    );
    state._setStateInternal(() {
      state._isTestingSystem = false;
      state._systemTestFailure = null;
      state._formState = state._formState.copyWith(draft: nextDraft);
    });
    _syncConnectionSettingsControllers(
      state,
      nextDraft,
      fields: const <ConnectionSettingsFieldId>{
        ConnectionSettingsFieldId.hostFingerprint,
      },
    );
    state._scheduleRemoteRuntimeRefresh(immediate: true);
  } catch (error) {
    if (!state.mounted) {
      return;
    }
    state._setStateInternal(() {
      state._isTestingSystem = false;
      state._systemTestFailure = connectionSettingsSystemProbeErrorMessage(
        error,
      );
    });
  }
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

const Set<ConnectionSettingsFieldId> _hostTrustSensitiveFields =
    <ConnectionSettingsFieldId>{
      ConnectionSettingsFieldId.host,
      ConnectionSettingsFieldId.port,
    };

bool _remoteHostIdentityChanged(
  ConnectionSettingsDraft previous,
  ConnectionSettingsDraft next,
) {
  return previous.host.trim().toLowerCase() != next.host.trim().toLowerCase() ||
      previous.port.trim() != next.port.trim();
}

ConnectionProfile _connectionSettingsSystemProfile(
  _ConnectionSettingsHostState state,
) {
  final draft = state._formState.draft;
  return state.widget.initialProfile.copyWith(
    connectionMode: ConnectionMode.remote,
    host: draft.host.trim(),
    port: int.tryParse(draft.port.trim()) ?? state.widget.initialProfile.port,
    username: draft.username.trim(),
    authMode: draft.authMode,
    hostFingerprint: draft.hostFingerprint.trim(),
  );
}

ConnectionSecrets _connectionSettingsSystemSecrets(
  _ConnectionSettingsHostState state,
) {
  final draft = state._formState.draft;
  return state.widget.initialSecrets.copyWith(
    password: draft.password,
    privateKeyPem: draft.privateKeyPem,
    privateKeyPassphrase: draft.privateKeyPassphrase,
  );
}

void _syncConnectionSettingsControllers(
  _ConnectionSettingsHostState state,
  ConnectionSettingsDraft draft, {
  Iterable<ConnectionSettingsFieldId>? fields,
}) {
  for (final fieldId in fields ?? ConnectionSettingsFieldId.values) {
    final controller = state._controllers[fieldId];
    if (controller == null) {
      continue;
    }
    final nextValue = draft.valueForField(fieldId);
    if (controller.text == nextValue) {
      continue;
    }
    controller.value = controller.value.copyWith(
      text: nextValue,
      selection: TextSelection.collapsed(offset: nextValue.length),
      composing: TextRange.empty,
    );
  }
}
