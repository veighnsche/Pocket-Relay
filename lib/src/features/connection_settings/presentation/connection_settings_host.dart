import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_registry.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_errors.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_presenter.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_system_probe.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_system_templates.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_system_template.dart';

part 'host/host_models.dart';
part 'host/model_catalog_refresh.dart';
part 'host/remote_runtime_refresh.dart';
part 'host/state_updates.dart';

typedef ConnectionSettingsHostBuilder =
    Widget Function(
      BuildContext context,
      ConnectionSettingsHostViewModel viewModel,
      ConnectionSettingsHostActions actions,
    );

typedef ConnectionSettingsRemoteRuntimeRefresher =
    Future<ConnectionRemoteRuntimeState> Function(
      ConnectionSettingsSubmitPayload payload,
    );

typedef ConnectionSettingsSystemTester =
    Future<ConnectionSettingsSystemTestResult> Function(
      ConnectionProfile profile,
      ConnectionSecrets secrets,
    );

class ConnectionSettingsHost extends StatefulWidget {
  const ConnectionSettingsHost({
    super.key,
    required this.initialProfile,
    required this.initialSecrets,
    this.isSystemSettings = false,
    this.initialRemoteRuntime,
    this.availableModelCatalog,
    this.availableModelCatalogSource,
    this.availableSystemTemplates = const <ConnectionSettingsSystemTemplate>[],
    this.onRefreshModelCatalog,
    this.onRefreshRemoteRuntime,
    this.onTestSystem,
    required this.onCancel,
    required this.onSubmit,
    required this.builder,
    required this.platformBehavior,
  });

  final ConnectionProfile initialProfile;
  final ConnectionSecrets initialSecrets;
  final bool isSystemSettings;
  final ConnectionRemoteRuntimeState? initialRemoteRuntime;
  final ConnectionModelCatalog? availableModelCatalog;
  final ConnectionSettingsModelCatalogSource? availableModelCatalogSource;
  final List<ConnectionSettingsSystemTemplate> availableSystemTemplates;
  final Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
  onRefreshModelCatalog;
  final ConnectionSettingsRemoteRuntimeRefresher? onRefreshRemoteRuntime;
  final ConnectionSettingsSystemTester? onTestSystem;
  final VoidCallback onCancel;
  final ValueChanged<ConnectionSettingsSubmitPayload> onSubmit;
  final ConnectionSettingsHostBuilder builder;
  final PocketPlatformBehavior platformBehavior;

  @override
  State<ConnectionSettingsHost> createState() => _ConnectionSettingsHostState();
}

class _ConnectionSettingsHostState extends State<ConnectionSettingsHost> {
  final _presenter = const ConnectionSettingsPresenter();
  late final Map<ConnectionSettingsFieldId, TextEditingController> _controllers;
  late ConnectionSettingsFormState _formState;
  ConnectionModelCatalog? _availableModelCatalog;
  ConnectionSettingsModelCatalogSource? _availableModelCatalogSource;
  PocketUserFacingError? _modelCatalogRefreshError;
  bool _isRefreshingModelCatalog = false;
  ConnectionRemoteRuntimeState? _remoteRuntime;
  late List<ConnectionSettingsSystemTemplate> _availableSystemTemplates;
  bool _isTestingSystem = false;
  String? _systemTestFailure;
  Timer? _remoteRuntimeRefreshDebounce;
  int _remoteRuntimeRefreshToken = 0;

  @override
  void initState() {
    super.initState();
    _formState = ConnectionSettingsFormState.initial(
      profile: widget.initialProfile,
      secrets: widget.initialSecrets,
    );
    _remoteRuntime = widget.initialRemoteRuntime;
    _availableModelCatalog = widget.availableModelCatalog;
    _availableModelCatalogSource = widget.availableModelCatalogSource;
    _availableSystemTemplates = widget.availableSystemTemplates;
    final draft = _formState.draft;
    _controllers = <ConnectionSettingsFieldId, TextEditingController>{
      for (final fieldId in ConnectionSettingsFieldId.values)
        fieldId: TextEditingController(text: draft.valueForField(fieldId)),
    };
    _scheduleRemoteRuntimeRefresh(immediate: true);
  }

  @override
  void dispose() {
    _remoteRuntimeRefreshDebounce?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contract = _buildContract();
    return widget.builder(
      context,
      ConnectionSettingsHostViewModel(
        contract: contract,
        fieldControllers: _controllers,
      ),
      ConnectionSettingsHostActions(
        onFieldChanged: _updateField,
        onModelChanged: _updateModel,
        onAgentAdapterChanged: _updateAgentAdapter,
        onConnectionModeChanged: _updateConnectionMode,
        onAuthModeChanged: _updateAuthMode,
        onReasoningEffortChanged: _updateReasoningEffort,
        onRefreshModelCatalog: _refreshModelCatalog,
        onSystemTemplateChanged: _selectSystemTemplate,
        onTestSystem: _testSystem,
        onToggleChanged: _updateToggle,
        onCancel: widget.onCancel,
        onSave: _save,
      ),
    );
  }

  ConnectionSettingsContract _buildContract([
    ConnectionSettingsFormState? formState,
  ]) => _buildConnectionSettingsHostContract(this, formState: formState);

  void _updateField(ConnectionSettingsFieldId fieldId, String value) =>
      _updateConnectionSettingsField(this, fieldId, value);

  void _updateConnectionMode(ConnectionMode connectionMode) =>
      _updateConnectionSettingsConnectionMode(this, connectionMode);

  void _updateAuthMode(AuthMode authMode) =>
      _updateConnectionSettingsAuthMode(this, authMode);

  void _updateToggle(ConnectionSettingsToggleId toggleId, bool value) =>
      _updateConnectionSettingsToggle(this, toggleId, value);

  void _updateReasoningEffort(AgentAdapterReasoningEffort? reasoningEffort) =>
      _updateConnectionSettingsReasoningEffort(this, reasoningEffort);

  void _updateModel(String? modelId) =>
      _updateConnectionSettingsModel(this, modelId);

  void _updateAgentAdapter(AgentAdapterKind agentAdapter) =>
      _updateConnectionSettingsAgentAdapter(this, agentAdapter);

  void _selectSystemTemplate(String? templateId) =>
      _selectConnectionSettingsSystemTemplate(this, templateId);

  Future<void> _testSystem() => _testConnectionSettingsSystem(this);

  bool _shouldRefreshRemoteRuntimeForField(ConnectionSettingsFieldId fieldId) =>
      _shouldRefreshConnectionSettingsRemoteRuntimeForField(fieldId);

  void _scheduleRemoteRuntimeRefresh({bool immediate = false}) =>
      _scheduleConnectionSettingsRemoteRuntimeRefresh(
        this,
        immediate: immediate,
      );

  Future<void> _refreshModelCatalog() =>
      _refreshConnectionSettingsModelCatalog(this);

  void _setStateInternal(VoidCallback fn) {
    setState(fn);
  }

  void _save() => _saveConnectionSettingsHost(this);
}
