part of '../connection_settings_host.dart';

ConnectionSettingsContract _buildConnectionSettingsHostContract(
  _ConnectionSettingsHostState state, {
  ConnectionSettingsFormState? formState,
}) {
  return state._presenter.present(
    initialProfile: state.widget.initialProfile,
    initialSecrets: state.widget.initialSecrets,
    formState: formState ?? state._formState,
    isSystemSettings: state.widget.isSystemSettings,
    remoteRuntime: state._remoteRuntime,
    availableModelCatalog: state._availableModelCatalog,
    availableModelCatalogSource: state._availableModelCatalogSource,
    availableSystemTemplates: state._availableSystemTemplates,
    modelCatalogRefreshError: state._modelCatalogRefreshError,
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

void _updateConnectionSettingsAgentAdapter(
  _ConnectionSettingsHostState state,
  AgentAdapterKind agentAdapter,
) {
  final previousDraft = state._formState.draft;
  if (previousDraft.agentAdapter == agentAdapter) {
    return;
  }

  final previousDefaultCommand = defaultCommandForAgentAdapter(
    previousDraft.agentAdapter,
  );
  final shouldResetCommand =
      previousDraft.agentCommand.trim().isEmpty ||
      previousDraft.agentCommand.trim() == previousDefaultCommand;
  var nextDraft = previousDraft.copyWith(
    agentAdapter: agentAdapter,
    agentCommand: shouldResetCommand
        ? defaultCommandForAgentAdapter(agentAdapter)
        : previousDraft.agentCommand,
  );
  nextDraft = _normalizeConnectionSettingsDraftForAdapter(
    nextDraft,
    supportsLocalConnectionMode:
        state.widget.platformBehavior.supportsLocalConnectionMode,
  );

  state._setStateInternal(() {
    state._formState = state._formState.copyWith(draft: nextDraft);
    state._availableModelCatalog = null;
    state._availableModelCatalogSource = null;
    state._modelCatalogRefreshError = null;
    state._systemTestFailure = null;
  });
  _syncConnectionSettingsControllers(
    state,
    nextDraft,
    fields: const <ConnectionSettingsFieldId>{
      ConnectionSettingsFieldId.hostCommand,
    },
  );
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
  AgentAdapterReasoningEffort? reasoningEffort,
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
  final nextEffort = normalizedReasoningEffortForModel(
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
  final selectedTemplateId = matchingConnectionSettingsSystemTemplateId(
    draft: state._formState.draft,
    templates: state._availableSystemTemplates,
  );
  if (templateId == null) {
    if (selectedTemplateId == null) {
      return;
    }

    final nextDraft = _resetConnectionSettingsSystemDraft(
      state._formState.draft,
    );
    state._setStateInternal(() {
      state._formState = state._formState.copyWith(draft: nextDraft);
      state._systemTestFailure = null;
    });
    _syncConnectionSettingsControllers(
      state,
      nextDraft,
      fields: _systemTemplateControlledFields,
    );
    state._scheduleRemoteRuntimeRefresh();
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
    fields: _systemTemplateControlledFields,
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

  final requestedProfile = _connectionSettingsSystemProfile(state);
  final requestedSecrets = _connectionSettingsSystemSecrets(state);

  state._setStateInternal(() {
    state._isTestingSystem = true;
    state._systemTestFailure = null;
  });

  try {
    final result = await onTestSystem(requestedProfile, requestedSecrets);
    if (!state.mounted) {
      return;
    }
    if (!_matchesConnectionSettingsSystemRequest(
      state._formState.draft,
      requestedProfile: requestedProfile,
      requestedSecrets: requestedSecrets,
    )) {
      state._setStateInternal(() {
        state._isTestingSystem = false;
      });
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
    if (!_matchesConnectionSettingsSystemRequest(
      state._formState.draft,
      requestedProfile: requestedProfile,
      requestedSecrets: requestedSecrets,
    )) {
      state._setStateInternal(() {
        state._isTestingSystem = false;
      });
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
    ConnectionSettingsFieldId.hostCommand ||
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

const Set<ConnectionSettingsFieldId> _systemTemplateControlledFields =
    <ConnectionSettingsFieldId>{
      ConnectionSettingsFieldId.host,
      ConnectionSettingsFieldId.port,
      ConnectionSettingsFieldId.username,
      ConnectionSettingsFieldId.hostFingerprint,
      ConnectionSettingsFieldId.password,
      ConnectionSettingsFieldId.privateKeyPem,
      ConnectionSettingsFieldId.privateKeyPassphrase,
    };

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
      _normalizedRemotePortIdentity(previous.port) !=
          _normalizedRemotePortIdentity(next.port);
}

Object _normalizedRemotePortIdentity(String value) {
  final trimmed = value.trim();
  return int.tryParse(trimmed) ?? trimmed;
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

ConnectionSettingsDraft _resetConnectionSettingsSystemDraft(
  ConnectionSettingsDraft draft,
) {
  final defaults = ConnectionProfile.defaults();
  return draft.copyWith(
    connectionMode: ConnectionMode.remote,
    host: '',
    port: defaults.port.toString(),
    username: '',
    hostFingerprint: '',
    authMode: defaults.authMode,
    password: '',
    privateKeyPem: '',
    privateKeyPassphrase: '',
  );
}

bool _matchesConnectionSettingsSystemRequest(
  ConnectionSettingsDraft draft, {
  required ConnectionProfile requestedProfile,
  required ConnectionSecrets requestedSecrets,
}) {
  return draft.connectionMode == ConnectionMode.remote &&
      draft.host.trim() == requestedProfile.host &&
      int.tryParse(draft.port.trim()) == requestedProfile.port &&
      draft.username.trim() == requestedProfile.username &&
      draft.authMode == requestedProfile.authMode &&
      draft.password == requestedSecrets.password &&
      draft.privateKeyPem == requestedSecrets.privateKeyPem &&
      draft.privateKeyPassphrase == requestedSecrets.privateKeyPassphrase;
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

ConnectionSettingsDraft _normalizeConnectionSettingsDraftForAdapter(
  ConnectionSettingsDraft draft, {
  required bool supportsLocalConnectionMode,
}) {
  final capabilities = agentAdapterCapabilitiesFor(draft.agentAdapter);
  final supportedModes = <ConnectionMode>[
    if (capabilities.supportsRemoteConnections) ConnectionMode.remote,
    if (capabilities.supportsLocalConnections && supportsLocalConnectionMode)
      ConnectionMode.local,
  ];
  if (supportedModes.isEmpty || supportedModes.contains(draft.connectionMode)) {
    return draft;
  }

  return draft.copyWith(connectionMode: supportedModes.first);
}
