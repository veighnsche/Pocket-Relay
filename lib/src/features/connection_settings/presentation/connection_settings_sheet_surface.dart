import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_radii.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
import 'package:pocket_relay/src/core/widgets/modal_sheet_scaffold.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_host.dart';

class ConnectionSettingsSheetSurface extends StatelessWidget {
  const ConnectionSettingsSheetSurface({
    super.key,
    required this.viewModel,
    required this.actions,
    this.isDesktopPresentation = false,
  });

  final ConnectionSettingsHostViewModel viewModel;
  final ConnectionSettingsHostActions actions;
  final bool isDesktopPresentation;
  static const _desktopSurfacePadding = 24.0;
  static const _desktopSurfaceVerticalMargin = _desktopSurfacePadding * 2;
  static const _desktopSurfaceMaxWidth = 880.0;
  static const _desktopSurfaceHeaderBottomPadding = 20.0;
  static const _desktopSurfaceContentTopPadding = 20.0;
  static const _desktopSurfaceElevation = 18.0;
  static const _desktopSurfaceRadius = 32.0;

  @override
  Widget build(BuildContext context) {
    final contract = viewModel.contract;
    return isDesktopPresentation
        ? _buildDesktopSurface(context, contract)
        : _buildMaterialSurface(context, contract);
  }

  Widget _buildMaterialSurface(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    return ModalSheetScaffold(
      header: _buildSheetHeader(context, contract),
      body: _buildScrollableContent(context, contract, includeIntro: true),
    );
  }

  Widget _buildDesktopSurface(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    final palette = context.pocketPalette;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _desktopSurfacePadding,
          _desktopSurfacePadding,
          _desktopSurfacePadding,
          _desktopSurfacePadding + viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _desktopSurfaceMaxWidth,
            maxHeight:
                screenHeight -
                _desktopSurfaceVerticalMargin -
                viewInsets.bottom,
          ),
          child: Material(
            key: const ValueKey<String>('desktop_connection_settings_surface'),
            color: palette.sheetBackground,
            elevation: _desktopSurfaceElevation,
            shadowColor: palette.shadowColor.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(_desktopSurfaceRadius),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _desktopSurfacePadding,
                    _desktopSurfacePadding,
                    _desktopSurfacePadding,
                    _desktopSurfaceHeaderBottomPadding,
                  ),
                  child: _buildDesktopHeader(context, contract),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: _desktopSurfacePadding,
                      right: _desktopSurfacePadding,
                      top: _desktopSurfaceContentTopPadding,
                      bottom: _desktopSurfacePadding,
                    ),
                    child: _buildScrollableContent(
                      context,
                      contract,
                      includeIntro: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldColumn(
    BuildContext context,
    List<ConnectionSettingsTextFieldContract> fields,
  ) {
    return Column(
      children: fields.indexed
          .map((entry) {
            final index = entry.$1;
            final field = entry.$2;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == fields.length - 1 ? 0 : 12,
              ),
              child: _buildTextField(context, field),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildRemoteConnectionFields(
    BuildContext context,
    List<ConnectionSettingsTextFieldContract> fields,
  ) {
    final fieldMap = viewModel.fieldMap(fields);
    final hostField = fieldMap[ConnectionSettingsFieldId.host];
    final portField = fieldMap[ConnectionSettingsFieldId.port];
    final usernameField = fieldMap[ConnectionSettingsFieldId.username];
    final fingerprintField =
        fieldMap[ConnectionSettingsFieldId.hostFingerprint];
    if (hostField == null ||
        portField == null ||
        usernameField == null ||
        fingerprintField == null) {
      return _buildFieldColumn(context, fields);
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: 3, child: _buildTextField(context, hostField)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(context, portField)),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextField(context, usernameField),
        const SizedBox(height: 12),
        _buildTextField(context, fingerprintField),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return PocketPanelSurface(
      backgroundColor: context.pocketPalette.surface,
      borderColor: context.pocketPalette.surfaceBorder,
      padding: PocketSpacing.panelPadding,
      radius: PocketRadii.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: PocketSpacing.lg),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    ConnectionSettingsTextFieldContract field,
  ) {
    return TextField(
      key: ValueKey<String>('connection_settings_${field.id.name}'),
      controller: viewModel.controllerForField(field.id),
      obscureText: field.obscureText,
      keyboardType: _textInputType(field.keyboardType),
      minLines: field.minLines,
      maxLines: field.maxLines,
      onChanged: (value) {
        actions.onFieldChanged(field.id, value);
      },
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.hintText,
        helperText: field.helperText,
        errorText: field.errorText,
        alignLabelWithHint: field.alignLabelWithHint,
      ),
    );
  }

  Widget _buildAuthModePicker(
    BuildContext context,
    ConnectionSettingsAuthenticationSectionContract section,
  ) {
    return SegmentedButton<AuthMode>(
      segments: section.options
          .map(
            (option) => ButtonSegment<AuthMode>(
              value: option.mode,
              label: Text(option.label),
              icon: Icon(_materialAuthIcon(option)),
            ),
          )
          .toList(growable: false),
      selected: <AuthMode>{section.selectedMode},
      onSelectionChanged: (selection) {
        actions.onAuthModeChanged(selection.first);
      },
    );
  }

  Widget _buildConnectionModePicker(
    BuildContext context,
    ConnectionSettingsConnectionModeSectionContract section,
  ) {
    return SegmentedButton<ConnectionMode>(
      segments: section.options
          .map(
            (option) => ButtonSegment<ConnectionMode>(
              value: option.mode,
              label: Text(option.label),
              icon: Icon(_materialConnectionModeIcon(option.mode)),
            ),
          )
          .toList(growable: false),
      selected: <ConnectionMode>{section.selectedMode},
      onSelectionChanged: (selection) {
        actions.onConnectionModeChanged(selection.first);
      },
    );
  }

  Widget _buildReasoningEffortPicker(
    BuildContext context,
    ConnectionSettingsModelSectionContract section,
  ) {
    return DropdownButtonFormField<CodexReasoningEffort?>(
      key: const ValueKey<String>('connection_settings_reasoning_effort'),
      initialValue: section.selectedReasoningEffort,
      decoration: InputDecoration(
        labelText: 'Reasoning effort',
        helperText: section.reasoningEffortHelperText,
      ),
      items: section.reasoningEffortOptions
          .map(
            (option) => DropdownMenuItem<CodexReasoningEffort?>(
              value: option.effort,
              child: Text(option.label),
            ),
          )
          .toList(growable: false),
      onChanged: section.isReasoningEffortEnabled
          ? actions.onReasoningEffortChanged
          : null,
    );
  }

  Widget _buildModelPicker(
    BuildContext context,
    ConnectionSettingsModelSectionContract section,
  ) {
    return DropdownButtonFormField<String?>(
      key: const ValueKey<String>('connection_settings_model'),
      initialValue: section.selectedModelId,
      decoration: InputDecoration(
        labelText: 'Model override (optional)',
        helperText: section.modelHelperText,
      ),
      items: section.modelOptions
          .map(
            (option) => DropdownMenuItem<String?>(
              value: option.modelId,
              child: Text(option.label),
            ),
          )
          .toList(growable: false),
      onChanged: section.isModelEnabled ? actions.onModelChanged : null,
    );
  }

  Widget _buildRefreshModelsAction(
    BuildContext context,
    ConnectionSettingsModelSectionContract section,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          key: const ValueKey<String>('connection_settings_refresh_models'),
          onPressed: section.isRefreshActionEnabled
              ? actions.onRefreshModelCatalog
              : null,
          icon: section.isRefreshActionInProgress
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: Text(section.refreshActionLabel),
        ),
        const SizedBox(height: 8),
        Text(
          section.refreshActionHelperText,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildToggle(
    BuildContext context,
    ConnectionSettingsToggleContract toggle,
  ) {
    return SwitchListTile.adaptive(
      value: toggle.value,
      onChanged: (value) {
        actions.onToggleChanged(toggle.id, value);
      },
      contentPadding: EdgeInsets.zero,
      title: Text(toggle.title),
      subtitle: Text(toggle.subtitle),
    );
  }

  Widget _buildSheetHeader(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ModalSheetDragHandle(),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey<String>('connection_settings_cancel_top'),
                onPressed: actions.onCancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const ValueKey<String>('connection_settings_save_top'),
                onPressed: actions.onSave,
                child: Text(contract.saveAction.label),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopHeader(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(contract.title, style: _titleStyle(context)),
              const SizedBox(height: 8),
              Text(contract.description, style: _descriptionStyle(context)),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              key: const ValueKey<String>('connection_settings_cancel_top'),
              onPressed: actions.onCancel,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            FilledButton(
              key: const ValueKey<String>('connection_settings_save_top'),
              onPressed: actions.onSave,
              child: Text(contract.saveAction.label),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScrollableContent(
    BuildContext context,
    ConnectionSettingsContract contract, {
    required bool includeIntro,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (includeIntro) ...[
          Text(contract.title, style: _titleStyle(context)),
          const SizedBox(height: 8),
          Text(contract.description, style: _descriptionStyle(context)),
          const SizedBox(height: 20),
        ],
        _buildSection(
          context,
          title: contract.profileSection.title,
          child: _buildFieldColumn(context, contract.profileSection.fields),
        ),
        if (contract.connectionModeSection case final modeSection?) ...[
          const SizedBox(height: 14),
          _buildSection(
            context,
            title: modeSection.title,
            child: _buildConnectionModePicker(context, modeSection),
          ),
        ],
        if (contract.remoteConnectionSection case final remoteSection?) ...[
          const SizedBox(height: 14),
          _buildSection(
            context,
            title: remoteSection.title,
            child: _buildRemoteConnectionFields(context, remoteSection.fields),
          ),
        ],
        const SizedBox(height: 14),
        _buildSection(
          context,
          title: contract.codexSection.title,
          child: _buildFieldColumn(context, contract.codexSection.fields),
        ),
        const SizedBox(height: 14),
        _buildSection(
          context,
          title: contract.modelSection.title,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModelPicker(context, contract.modelSection),
              const SizedBox(height: 14),
              _buildReasoningEffortPicker(context, contract.modelSection),
              const SizedBox(height: 14),
              _buildRefreshModelsAction(context, contract.modelSection),
            ],
          ),
        ),
        if (contract.authenticationSection case final authSection?) ...[
          const SizedBox(height: 14),
          _buildSection(
            context,
            title: authSection.title,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAuthModePicker(context, authSection),
                const SizedBox(height: 14),
                _buildFieldColumn(context, authSection.fields),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        _buildSection(
          context,
          title: contract.runModeSection.title,
          child: Column(
            children: contract.runModeSection.toggles
                .map((toggle) => _buildToggle(context, toggle))
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  TextStyle _titleStyle(BuildContext context) {
    return const TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
  }

  TextStyle _descriptionStyle(BuildContext context) {
    return TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.45,
    );
  }

  TextInputType _textInputType(ConnectionSettingsKeyboardType keyboardType) {
    return switch (keyboardType) {
      ConnectionSettingsKeyboardType.text => TextInputType.text,
      ConnectionSettingsKeyboardType.number => TextInputType.number,
    };
  }

  IconData _materialAuthIcon(ConnectionSettingsAuthOptionContract option) {
    return switch (option.icon) {
      ConnectionSettingsAuthOptionIcon.password => Icons.password,
      ConnectionSettingsAuthOptionIcon.privateKey => Icons.key,
    };
  }

  IconData _materialConnectionModeIcon(ConnectionMode mode) {
    return switch (mode) {
      ConnectionMode.remote => Icons.cloud_outlined,
      ConnectionMode.local => Icons.laptop_mac_outlined,
    };
  }
}
