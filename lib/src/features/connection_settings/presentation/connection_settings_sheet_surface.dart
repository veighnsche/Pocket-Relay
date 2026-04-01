import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/widgets/modal_sheet_scaffold.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_host.dart';

enum ConnectionSettingsSurfaceMode { workspace, system }

class ConnectionSettingsSheetSurface extends StatelessWidget {
  const ConnectionSettingsSheetSurface({
    super.key,
    required this.viewModel,
    required this.actions,
    this.isDesktopPresentation = false,
    this.surfaceMode = ConnectionSettingsSurfaceMode.workspace,
  });

  final ConnectionSettingsHostViewModel viewModel;
  final ConnectionSettingsHostActions actions;
  final bool isDesktopPresentation;
  final ConnectionSettingsSurfaceMode surfaceMode;

  static const double _mobileHorizontalPadding = 20;
  static const double _mobileHeaderTopPadding = 16;
  static const double _mobileHeaderBottomPadding = 18;
  static const double _mobileContentTopPadding = 20;
  static const double _mobileFooterBottomPadding = 16;

  static const double _desktopSurfacePadding = 24;
  static const double _desktopSurfaceVerticalMargin =
      _desktopSurfacePadding * 2;
  static const double _desktopSurfaceMaxWidth = 880;
  static const double _desktopSurfaceHeaderBottomPadding = 18;
  static const double _desktopSurfaceContentTopPadding = 20;
  static const double _desktopSurfaceElevation = 18;
  static const double _desktopSurfaceRadius = 32;

  static const double _sectionSpacing = 28;
  static const double _sectionDividerSpacing = 24;
  static const double _fieldSpacing = 12;
  static const double _subsectionSpacing = 14;
  static const double _modelRefreshSpacing = 16;

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
      headerPadding: const EdgeInsets.fromLTRB(
        _mobileHorizontalPadding,
        _mobileHeaderTopPadding,
        _mobileHorizontalPadding,
        _mobileHeaderBottomPadding,
      ),
      bodyPadding: EdgeInsets.zero,
      bodyIsScrollable: false,
      header: _buildMobileHeader(context, contract),
      body: _buildSurfaceBody(context, contract, isDesktop: false),
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
                  child: _buildHeaderContent(
                    context,
                    contract,
                    isDesktop: true,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      _desktopSurfacePadding,
                      _desktopSurfaceContentTopPadding,
                      _desktopSurfacePadding,
                      _desktopSurfacePadding,
                    ),
                    child: _buildScrollableContent(context, contract),
                  ),
                ),
                const Divider(height: 1),
                _buildFooterActionBar(context, contract, isDesktop: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeader(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ModalSheetDragHandle(),
        const SizedBox(height: 18),
        _buildHeaderContent(context, contract, isDesktop: false),
      ],
    );
  }

  Widget _buildHeaderContent(
    BuildContext context,
    ConnectionSettingsContract contract, {
    required bool isDesktop,
  }) {
    final theme = Theme.of(context);
    final summary = _summaryTextFor(contract);
    final badges = _buildHeaderBadges(context, contract);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          surfaceMode == ConnectionSettingsSurfaceMode.system
              ? 'System'
              : contract.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: isDesktop ? 30 : 24,
          ),
        ),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            summary,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (badges.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: badges),
        ],
      ],
    );
  }

  List<Widget> _buildHeaderBadges(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    final theme = Theme.of(context);

    return <Widget>[
      if (contract.saveAction.hasChanges)
        _buildHeaderBadge(
          context,
          label: 'Unsaved changes',
          icon: Icons.edit_outlined,
          foregroundColor: theme.colorScheme.tertiary,
          backgroundColor: theme.colorScheme.tertiary.withValues(alpha: 0.14),
        ),
    ];
  }

  Widget _buildHeaderBadge(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color foregroundColor,
    required Color backgroundColor,
  }) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foregroundColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurfaceBody(
    BuildContext context,
    ConnectionSettingsContract contract, {
    required bool isDesktop,
  }) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              _mobileHorizontalPadding,
              _mobileContentTopPadding,
              _mobileHorizontalPadding,
              _mobileHorizontalPadding,
            ),
            child: _buildScrollableContent(context, contract),
          ),
        ),
        const Divider(height: 1),
        _buildFooterActionBar(context, contract, isDesktop: isDesktop),
      ],
    );
  }

  Widget _buildFooterActionBar(
    BuildContext context,
    ConnectionSettingsContract contract, {
    required bool isDesktop,
  }) {
    final bottomPadding = isDesktop
        ? _desktopSurfacePadding
        : _mobileFooterBottomPadding + MediaQuery.viewInsetsOf(context).bottom;
    final horizontalPadding = isDesktop
        ? _desktopSurfacePadding
        : _mobileHorizontalPadding;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        14,
        horizontalPadding,
        bottomPadding,
      ),
      child: Row(
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
    );
  }

  Widget _buildScrollableContent(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    return surfaceMode == ConnectionSettingsSurfaceMode.system
        ? _buildSystemScrollableContent(context, contract)
        : _buildWorkspaceScrollableContent(context, contract);
  }

  Widget _buildWorkspaceScrollableContent(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    final hasAdvancedToggles = contract.runModeSection.toggles.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          context,
          key: const ValueKey<String>('connection_settings_section_workspace'),
          title: 'Workspace',
          child: _buildWorkspaceSection(context, contract),
        ),
        _buildSectionDivider(),
        _buildSection(
          context,
          key: const ValueKey<String>(
            'connection_settings_section_agent_adapter',
          ),
          title: contract.agentAdapterSection.title,
          child: _buildHostSection(context, contract),
        ),
        if (hasAdvancedToggles) ...[
          _buildSectionDivider(),
          _buildSection(
            context,
            key: const ValueKey<String>('connection_settings_section_advanced'),
            title: 'Advanced',
            child: _buildAdvancedSection(context, contract),
          ),
        ],
      ],
    );
  }

  Widget _buildSystemScrollableContent(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (contract.remoteConnectionSection case final remoteSection?)
          _buildSection(
            context,
            key: const ValueKey<String>('connection_settings_section_system'),
            title: 'System',
            child: _buildRemoteAccessSection(
              context,
              contract,
              remoteSection,
              showSystemPicker: false,
            ),
          ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required Key key,
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);

    return KeyedSubtree(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSectionDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: _sectionDividerSpacing),
      child: Divider(height: 1),
    );
  }

  Widget _buildWorkspaceSection(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    final routeSection = contract.connectionModeSection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldColumn(context, contract.profileSection.fields),
        if (routeSection != null) ...[
          const SizedBox(height: _sectionSpacing),
          _buildSubsectionLabel(context, routeSection.title),
          const SizedBox(height: 12),
          _buildConnectionModePicker(context, routeSection),
        ],
        if (contract.systemPicker case final picker?) ...[
          const SizedBox(height: _sectionSpacing),
          _buildSubsectionLabel(context, 'System'),
          const SizedBox(height: 12),
          _buildSystemPicker(context, picker),
          const SizedBox(height: 10),
          Text(
            picker.helperText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRemoteAccessSection(
    BuildContext context,
    ConnectionSettingsContract contract,
    ConnectionSettingsSectionContract remoteSection, {
    required bool showSystemPicker,
  }) {
    final systemPicker = showSystemPicker ? contract.systemPicker : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (systemPicker != null) ...[
          _buildSubsectionLabel(context, systemPicker.title),
          const SizedBox(height: 12),
          _buildSystemPicker(context, systemPicker),
          const SizedBox(height: 10),
          Text(
            systemPicker.helperText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: _sectionSpacing),
        ],
        if (remoteSection.status case final status?) ...[
          _buildRemoteStatusStrip(context, contract, status),
          const SizedBox(height: _sectionSpacing),
        ],
        _buildSubsectionLabel(context, 'System details'),
        const SizedBox(height: 12),
        _buildRemoteConnectionFields(context, remoteSection.fields),
        if (contract.authenticationSection case final authSection?) ...[
          const SizedBox(height: _sectionSpacing),
          _buildSubsectionLabel(context, authSection.title),
          const SizedBox(height: 12),
          _buildAuthModePicker(context, authSection),
          const SizedBox(height: 14),
          _buildFieldColumn(context, authSection.fields),
        ],
        if (contract.systemTrust case final trustSection?) ...[
          const SizedBox(height: _sectionSpacing),
          _buildSubsectionLabel(context, trustSection.title),
          const SizedBox(height: 12),
          _buildSystemTrustPanel(context, trustSection),
        ],
      ],
    );
  }

  Widget _buildHostSection(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    final agentAdapterSection = contract.agentAdapterSection;
    final hostFields = agentAdapterSection.fields;
    final helperText = agentAdapterSection.helperText.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (agentAdapterSection.options.length > 1) ...[
          _buildSubsectionLabel(context, 'Adapter'),
          const SizedBox(height: 12),
          _buildAgentAdapterPicker(context, agentAdapterSection),
          if (helperText.isNotEmpty) const SizedBox(height: 10),
        ],
        if (helperText.isNotEmpty)
          Text(
            helperText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        if (agentAdapterSection.status case final status?) ...[
          const SizedBox(height: _sectionSpacing),
          _buildInlineStatusStrip(
            context,
            status,
            icon: Icons.error_outline,
            color: Theme.of(context).colorScheme.tertiary,
          ),
        ],
        if (hostFields.isNotEmpty) _buildFieldColumn(context, hostFields),
        if (hostFields.isNotEmpty) const SizedBox(height: _sectionSpacing),
        _buildSubsectionLabel(context, contract.modelSection.title),
        const SizedBox(height: 12),
        _buildModelDefaultsSection(context, contract.modelSection),
      ],
    );
  }

  Widget _buildAdvancedSection(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    final toggles = contract.runModeSection.toggles;
    return Column(
      children: toggles.indexed
          .expand((entry) {
            final index = entry.$1;
            final toggle = entry.$2;
            return <Widget>[
              _buildToggle(context, toggle),
              if (index != toggles.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: _fieldSpacing),
                  child: Divider(height: 1),
                ),
            ];
          })
          .toList(growable: false),
    );
  }

  Widget _buildSubsectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildRemoteStatusStrip(
    BuildContext context,
    ConnectionSettingsContract contract,
    ConnectionSettingsSectionStatusContract status,
  ) {
    final theme = Theme.of(context);
    final visuals = _statusVisuals(context, contract.remoteRuntime);

    return _buildInlineStatusStrip(
      context,
      status,
      icon: visuals.icon,
      color: visuals.color,
    );
  }

  Widget _buildInlineStatusStrip(
    BuildContext context,
    ConnectionSettingsSectionStatusContract status, {
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.only(left: 14),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  status.detail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({IconData icon, Color color}) _statusVisuals(
    BuildContext context,
    ConnectionRemoteRuntimeState? remoteRuntime,
  ) {
    final theme = Theme.of(context);
    if (remoteRuntime == null) {
      return (
        icon: Icons.info_outline,
        color: theme.colorScheme.onSurfaceVariant,
      );
    }

    switch (remoteRuntime.hostCapability.status) {
      case ConnectionRemoteHostCapabilityStatus.checking:
        return (icon: Icons.sync, color: theme.colorScheme.primary);
      case ConnectionRemoteHostCapabilityStatus.probeFailed:
      case ConnectionRemoteHostCapabilityStatus.unsupported:
        return (icon: Icons.error_outline, color: theme.colorScheme.tertiary);
      case ConnectionRemoteHostCapabilityStatus.supported:
        break;
      case ConnectionRemoteHostCapabilityStatus.unknown:
        return (
          icon: Icons.help_outline,
          color: theme.colorScheme.onSurfaceVariant,
        );
    }

    return switch (remoteRuntime.server.status) {
      ConnectionRemoteServerStatus.running => (
        icon: Icons.check_circle_outline,
        color: theme.colorScheme.secondary,
      ),
      ConnectionRemoteServerStatus.checking => (
        icon: Icons.sync,
        color: theme.colorScheme.primary,
      ),
      ConnectionRemoteServerStatus.notRunning ||
      ConnectionRemoteServerStatus.unhealthy => (
        icon: Icons.warning_amber_rounded,
        color: theme.colorScheme.tertiary,
      ),
      ConnectionRemoteServerStatus.unknown => (
        icon: Icons.info_outline,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    };
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
                bottom: index == fields.length - 1 ? 0 : _fieldSpacing,
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
    if (hostField == null || portField == null || usernameField == null) {
      return _buildFieldColumn(context, fields);
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: 3, child: _buildTextField(context, hostField)),
            const SizedBox(width: _fieldSpacing),
            Expanded(child: _buildTextField(context, portField)),
          ],
        ),
        const SizedBox(height: _fieldSpacing),
        _buildTextField(context, usernameField),
      ],
    );
  }

  Widget _buildSystemPicker(
    BuildContext context,
    ConnectionSettingsSystemPickerContract picker,
  ) {
    return DropdownButtonFormField<String?>(
      key: const ValueKey<String>('connection_settings_system_picker'),
      initialValue: picker.selectedSystemId,
      decoration: const InputDecoration(labelText: 'System'),
      isExpanded: true,
      items: <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('No system selected'),
        ),
        ...picker.options.map(
          (option) => DropdownMenuItem<String?>(
            value: option.id,
            child: Text(
              '${option.label} · ${option.description}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      selectedItemBuilder: (context) {
        return <Widget>[
          const Text('No system selected'),
          ...picker.options.map(
            (option) => Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ];
      },
      onChanged: actions.onSystemTemplateChanged,
    );
  }

  Widget _buildSystemTrustPanel(
    BuildContext context,
    ConnectionSettingsSystemTrustContract trust,
  ) {
    final theme = Theme.of(context);
    final color = switch (trust.state) {
      ConnectionSettingsSystemTrustStateKind.ready =>
        theme.colorScheme.secondary,
      ConnectionSettingsSystemTrustStateKind.failed =>
        theme.colorScheme.tertiary,
      ConnectionSettingsSystemTrustStateKind.checking =>
        theme.colorScheme.primary,
      ConnectionSettingsSystemTrustStateKind.needsTest =>
        theme.colorScheme.onSurfaceVariant,
    };
    final icon = switch (trust.state) {
      ConnectionSettingsSystemTrustStateKind.ready => Icons.verified_outlined,
      ConnectionSettingsSystemTrustStateKind.failed => Icons.error_outline,
      ConnectionSettingsSystemTrustStateKind.checking => Icons.sync,
      ConnectionSettingsSystemTrustStateKind.needsTest => Icons.shield_outlined,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trust.statusLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    trust.detail,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (trust.fingerprint case final fingerprint?) ...[
          const SizedBox(height: 12),
          SelectableText(
            fingerprint,
            key: const ValueKey<String>(
              'connection_settings_system_fingerprint',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ],
        const SizedBox(height: 14),
        OutlinedButton.icon(
          key: const ValueKey<String>('connection_settings_test_system'),
          onPressed: trust.isActionEnabled ? actions.onTestSystem : null,
          icon: trust.isActionInProgress
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.router_outlined),
          label: Text(trust.actionLabel),
        ),
      ],
    );
  }

  Widget _buildModelDefaultsSection(
    BuildContext context,
    ConnectionSettingsModelSectionContract section,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSplitLayout = constraints.maxWidth >= 640;
        final pickerContent = useSplitLayout
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildModelPicker(context, section)),
                  const SizedBox(width: _fieldSpacing),
                  Expanded(
                    child: _buildReasoningEffortPicker(context, section),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildModelPicker(context, section),
                  const SizedBox(height: _subsectionSpacing),
                  _buildReasoningEffortPicker(context, section),
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            pickerContent,
            const SizedBox(height: _modelRefreshSpacing),
            _buildRefreshModelsAction(context, section),
          ],
        );
      },
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
      textCapitalization: _textCapitalizationForField(field.id),
      autocorrect: _autocorrectForField(field.id),
      enableSuggestions: _enableSuggestionsForField(field.id),
      smartDashesType: _smartTypingEnabledForField(field.id)
          ? SmartDashesType.enabled
          : SmartDashesType.disabled,
      smartQuotesType: _smartTypingEnabledForField(field.id)
          ? SmartQuotesType.enabled
          : SmartQuotesType.disabled,
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

  TextCapitalization _textCapitalizationForField(
    ConnectionSettingsFieldId fieldId,
  ) {
    return switch (fieldId) {
      ConnectionSettingsFieldId.label => TextCapitalization.words,
      _ => TextCapitalization.none,
    };
  }

  bool _autocorrectForField(ConnectionSettingsFieldId fieldId) {
    return switch (fieldId) {
      ConnectionSettingsFieldId.label => true,
      _ => false,
    };
  }

  bool _enableSuggestionsForField(ConnectionSettingsFieldId fieldId) {
    return switch (fieldId) {
      ConnectionSettingsFieldId.label => true,
      _ => false,
    };
  }

  bool _smartTypingEnabledForField(ConnectionSettingsFieldId fieldId) {
    return switch (fieldId) {
      ConnectionSettingsFieldId.label => true,
      _ => false,
    };
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

  Widget _buildAgentAdapterPicker(
    BuildContext context,
    ConnectionSettingsAgentAdapterSectionContract section,
  ) {
    return DropdownButtonFormField<AgentAdapterKind>(
      key: const ValueKey<String>('connection_settings_agent_adapter'),
      initialValue: section.selectedAdapter,
      decoration: const InputDecoration(labelText: 'Agent adapter'),
      isExpanded: true,
      items: section.options
          .map(
            (option) => DropdownMenuItem<AgentAdapterKind>(
              value: option.kind,
              child: Text(
                '${option.label} · ${option.description}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      selectedItemBuilder: (context) {
        return section.options
            .map(
              (option) => Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
            .toList(growable: false);
      },
      onChanged: (nextAdapter) {
        if (nextAdapter == null) {
          return;
        }
        actions.onAgentAdapterChanged(nextAdapter);
      },
    );
  }

  Widget _buildReasoningEffortPicker(
    BuildContext context,
    ConnectionSettingsModelSectionContract section,
  ) {
    return DropdownButtonFormField<AgentAdapterReasoningEffort?>(
      key: const ValueKey<String>('connection_settings_reasoning_effort'),
      initialValue: section.selectedReasoningEffort,
      decoration: InputDecoration(
        labelText: 'Reasoning effort',
        helperText: section.reasoningEffortHelperText,
      ),
      items: section.reasoningEffortOptions
          .map(
            (option) => DropdownMenuItem<AgentAdapterReasoningEffort?>(
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
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildToggle(
    BuildContext context,
    ConnectionSettingsToggleContract toggle,
  ) {
    final theme = Theme.of(context);

    return SwitchListTile.adaptive(
      value: toggle.value,
      onChanged: (value) {
        actions.onToggleChanged(toggle.id, value);
      },
      contentPadding: EdgeInsets.zero,
      title: Text(
        toggle.title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        toggle.subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.45,
        ),
      ),
    );
  }

  String _summaryTextFor(ConnectionSettingsContract contract) {
    final label = _fieldValueFor(
      contract.profileSection.fields,
      ConnectionSettingsFieldId.label,
    );
    final workspaceDir = _fieldValueFor(
      contract.profileSection.fields,
      ConnectionSettingsFieldId.workspaceDir,
    );
    final host = _fieldValueFor(
      contract.remoteConnectionSection?.fields ?? const [],
      ConnectionSettingsFieldId.host,
    );

    if (host.isNotEmpty && workspaceDir.isNotEmpty) {
      return '$host · $workspaceDir';
    }
    if (workspaceDir.isNotEmpty) {
      return workspaceDir;
    }
    if (host.isNotEmpty) {
      return host;
    }
    if (label.isNotEmpty && label != contract.title) {
      return label;
    }
    return '';
  }

  String _fieldValueFor(
    List<ConnectionSettingsTextFieldContract> fields,
    ConnectionSettingsFieldId fieldId,
  ) {
    for (final field in fields) {
      if (field.id == fieldId) {
        return field.value.trim();
      }
    }
    return '';
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
