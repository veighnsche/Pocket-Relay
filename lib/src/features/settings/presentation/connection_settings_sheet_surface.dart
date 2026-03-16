import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_host.dart';

enum ConnectionSettingsSheetStyle { material, cupertino }

class ConnectionSettingsSheetSurface extends StatelessWidget {
  const ConnectionSettingsSheetSurface({
    super.key,
    required this.viewModel,
    required this.actions,
    required this.style,
  });

  final ConnectionSettingsHostViewModel viewModel;
  final ConnectionSettingsHostActions actions;
  final ConnectionSettingsSheetStyle style;

  @override
  Widget build(BuildContext context) {
    final contract = viewModel.contract;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDragHandle(context),
        const SizedBox(height: 18),
        Text(contract.title, style: _titleStyle(context)),
        const SizedBox(height: 8),
        Text(contract.description, style: _descriptionStyle(context)),
        const SizedBox(height: 20),
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
        const SizedBox(height: 18),
        _buildFooter(context, contract),
      ],
    );

    return switch (style) {
      ConnectionSettingsSheetStyle.material => _buildMaterialSurface(
        context,
        content,
      ),
      ConnectionSettingsSheetStyle.cupertino => _buildCupertinoSurface(
        context,
        content,
      ),
    };
  }

  Widget _buildMaterialSurface(BuildContext context, Widget content) {
    final palette = context.pocketPalette;

    return Material(
      color: palette.sheetBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(child: content),
        ),
      ),
    );
  }

  Widget _buildCupertinoSurface(BuildContext context, Widget content) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final cupertinoTheme = MaterialBasedCupertinoThemeData(
      materialTheme: Theme.of(context),
    );

    return CupertinoTheme(
      data: cupertinoTheme,
      child: Builder(
        builder: (context) {
          return DefaultTextStyle(
            style: CupertinoTheme.of(context).textTheme.textStyle,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, keyboardInset + 12),
                  child: CupertinoPopupSurface(
                    blurSigma: 18,
                    child: DecoratedBox(
                      key: const ValueKey('cupertino_settings_surface'),
                      decoration: BoxDecoration(
                        color: _cupertinoSheetSurfaceColor(context),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        border: Border.all(
                          color: _cupertinoSeparatorColor(
                            context,
                          ).withValues(alpha: 0.18),
                        ),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                            child: content,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDragHandle(BuildContext context) {
    return Center(
      child: Container(
        width: style == ConnectionSettingsSheetStyle.material ? 48 : 44,
        height: 5,
        decoration: BoxDecoration(
          color: switch (style) {
            ConnectionSettingsSheetStyle.material =>
              context.pocketPalette.dragHandle,
            ConnectionSettingsSheetStyle.cupertino =>
              CupertinoColors.systemGrey3,
          },
          borderRadius: BorderRadius.circular(999),
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
    return switch (style) {
      ConnectionSettingsSheetStyle.material => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.pocketPalette.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: context.pocketPalette.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
      ConnectionSettingsSheetStyle.cupertino => DecoratedBox(
        decoration: BoxDecoration(
          color: _cupertinoSectionColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _cupertinoSeparatorColor(context).withValues(alpha: 0.18),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _cupertinoLabelColor(context),
                ),
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    };
  }

  Widget _buildTextField(
    BuildContext context,
    ConnectionSettingsTextFieldContract field,
  ) {
    return switch (style) {
      ConnectionSettingsSheetStyle.material => TextField(
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
      ),
      ConnectionSettingsSheetStyle.cupertino => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _cupertinoSecondaryLabelColor(context),
            ),
          ),
          const SizedBox(height: 6),
          CupertinoTextField(
            key: ValueKey<String>('connection_settings_${field.id.name}'),
            controller: viewModel.controllerForField(field.id),
            placeholder: field.hintText,
            obscureText: field.obscureText,
            keyboardType: _textInputType(field.keyboardType),
            minLines: field.minLines,
            maxLines: field.maxLines,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            style: TextStyle(color: _cupertinoLabelColor(context)),
            placeholderStyle: TextStyle(
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.placeholderText,
                context,
              ),
            ),
            decoration: BoxDecoration(
              color: _cupertinoFieldColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _cupertinoSeparatorColor(
                  context,
                ).withValues(alpha: 0.14),
              ),
            ),
            onChanged: (value) {
              actions.onFieldChanged(field.id, value);
            },
          ),
          if (field.helperText case final helperText?) ...[
            const SizedBox(height: 6),
            Text(
              helperText,
              style: TextStyle(
                fontSize: 12,
                color: _cupertinoSecondaryLabelColor(context),
              ),
            ),
          ],
          if (field.errorText case final errorText?) ...[
            const SizedBox(height: 6),
            Text(
              errorText,
              style: TextStyle(
                fontSize: 12,
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.systemRed,
                  context,
                ),
              ),
            ),
          ],
        ],
      ),
    };
  }

  Widget _buildAuthModePicker(
    BuildContext context,
    ConnectionSettingsAuthenticationSectionContract section,
  ) {
    return switch (style) {
      ConnectionSettingsSheetStyle.material => SegmentedButton<AuthMode>(
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
      ),
      ConnectionSettingsSheetStyle.cupertino =>
        CupertinoSlidingSegmentedControl<AuthMode>(
          groupValue: section.selectedMode,
          children: <AuthMode, Widget>{
            for (final option in section.options)
              option.mode: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_cupertinoAuthIcon(option), size: 16),
                    const SizedBox(width: 6),
                    Text(option.label),
                  ],
                ),
              ),
          },
          onValueChanged: (value) {
            if (value != null) {
              actions.onAuthModeChanged(value);
            }
          },
        ),
    };
  }

  Widget _buildConnectionModePicker(
    BuildContext context,
    ConnectionSettingsConnectionModeSectionContract section,
  ) {
    return switch (style) {
      ConnectionSettingsSheetStyle.material => SegmentedButton<ConnectionMode>(
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
      ),
      ConnectionSettingsSheetStyle.cupertino =>
        CupertinoSlidingSegmentedControl<ConnectionMode>(
          groupValue: section.selectedMode,
          children: <ConnectionMode, Widget>{
            for (final option in section.options)
              option.mode: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_cupertinoConnectionModeIcon(option.mode), size: 16),
                    const SizedBox(width: 6),
                    Text(option.label),
                  ],
                ),
              ),
          },
          onValueChanged: (value) {
            if (value != null) {
              actions.onConnectionModeChanged(value);
            }
          },
        ),
    };
  }

  Widget _buildToggle(
    BuildContext context,
    ConnectionSettingsToggleContract toggle,
  ) {
    return switch (style) {
      ConnectionSettingsSheetStyle.material => SwitchListTile.adaptive(
        value: toggle.value,
        onChanged: (value) {
          actions.onToggleChanged(toggle.id, value);
        },
        contentPadding: EdgeInsets.zero,
        title: Text(toggle.title),
        subtitle: Text(toggle.subtitle),
      ),
      ConnectionSettingsSheetStyle.cupertino => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    toggle.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _cupertinoLabelColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    toggle.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: _cupertinoSecondaryLabelColor(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CupertinoSwitch(
              value: toggle.value,
              onChanged: (value) {
                actions.onToggleChanged(toggle.id, value);
              },
            ),
          ],
        ),
      ),
    };
  }

  Widget _buildFooter(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    return switch (style) {
      ConnectionSettingsSheetStyle.material => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: actions.onCancel,
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: actions.onSave,
              child: Text(contract.saveAction.label),
            ),
          ),
        ],
      ),
      ConnectionSettingsSheetStyle.cupertino => Row(
        children: [
          Expanded(
            child: CupertinoButton(
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.secondarySystemFill,
                context,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              onPressed: actions.onCancel,
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: _cupertinoLabelColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(vertical: 14),
              onPressed: actions.onSave,
              child: Text(contract.saveAction.label),
            ),
          ),
        ],
      ),
    };
  }

  TextStyle _titleStyle(BuildContext context) {
    return switch (style) {
      ConnectionSettingsSheetStyle.material => const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
      ),
      ConnectionSettingsSheetStyle.cupertino => TextStyle(
        fontSize: 27,
        fontWeight: FontWeight.w700,
        color: _cupertinoLabelColor(context),
      ),
    };
  }

  TextStyle _descriptionStyle(BuildContext context) {
    return switch (style) {
      ConnectionSettingsSheetStyle.material => TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.45,
      ),
      ConnectionSettingsSheetStyle.cupertino => TextStyle(
        fontSize: 14,
        height: 1.35,
        color: _cupertinoSecondaryLabelColor(context),
      ),
    };
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

  IconData _cupertinoAuthIcon(ConnectionSettingsAuthOptionContract option) {
    return switch (option.icon) {
      ConnectionSettingsAuthOptionIcon.password => CupertinoIcons.lock_fill,
      ConnectionSettingsAuthOptionIcon.privateKey => CupertinoIcons.lock_shield,
    };
  }

  IconData _cupertinoConnectionModeIcon(ConnectionMode mode) {
    return switch (mode) {
      ConnectionMode.remote => CupertinoIcons.cloud,
      ConnectionMode.local => CupertinoIcons.desktopcomputer,
    };
  }

  Color _cupertinoSheetSurfaceColor(BuildContext context) {
    return CupertinoDynamicColor.resolve(
      CupertinoColors.systemGroupedBackground,
      context,
    ).withValues(alpha: 0.92);
  }

  Color _cupertinoSectionColor(BuildContext context) {
    return CupertinoDynamicColor.resolve(
      CupertinoColors.secondarySystemGroupedBackground,
      context,
    );
  }

  Color _cupertinoFieldColor(BuildContext context) {
    return CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemGroupedBackground,
      context,
    );
  }

  Color _cupertinoSeparatorColor(BuildContext context) {
    return CupertinoDynamicColor.resolve(CupertinoColors.separator, context);
  }

  Color _cupertinoLabelColor(BuildContext context) {
    return CupertinoDynamicColor.resolve(CupertinoColors.label, context);
  }

  Color _cupertinoSecondaryLabelColor(BuildContext context) {
    return CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
  }
}
