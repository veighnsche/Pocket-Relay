part of '../connection_settings_host.dart';

class ConnectionSettingsHostViewModel {
  const ConnectionSettingsHostViewModel({
    required this.contract,
    required this.fieldControllers,
  });

  final ConnectionSettingsContract contract;
  final Map<ConnectionSettingsFieldId, TextEditingController> fieldControllers;

  TextEditingController controllerForField(ConnectionSettingsFieldId fieldId) {
    return fieldControllers[fieldId]!;
  }

  Map<ConnectionSettingsFieldId, ConnectionSettingsTextFieldContract> fieldMap(
    Iterable<ConnectionSettingsTextFieldContract> fields,
  ) {
    return <ConnectionSettingsFieldId, ConnectionSettingsTextFieldContract>{
      for (final field in fields) field.id: field,
    };
  }
}

class ConnectionSettingsHostActions {
  const ConnectionSettingsHostActions({
    required this.onFieldChanged,
    required this.onModelChanged,
    required this.onConnectionModeChanged,
    required this.onAuthModeChanged,
    required this.onReasoningEffortChanged,
    required this.onRefreshModelCatalog,
    required this.onSystemTemplateChanged,
    required this.onTestSystem,
    required this.onToggleChanged,
    required this.onCancel,
    required this.onSave,
  });

  final void Function(ConnectionSettingsFieldId fieldId, String value)
  onFieldChanged;
  final ValueChanged<String?> onModelChanged;
  final ValueChanged<ConnectionMode> onConnectionModeChanged;
  final ValueChanged<AuthMode> onAuthModeChanged;
  final ValueChanged<CodexReasoningEffort?> onReasoningEffortChanged;
  final Future<void> Function() onRefreshModelCatalog;
  final ValueChanged<String?> onSystemTemplateChanged;
  final Future<void> Function() onTestSystem;
  final void Function(ConnectionSettingsToggleId toggleId, bool value)
  onToggleChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;
}
