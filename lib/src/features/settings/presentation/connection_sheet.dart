import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_host.dart';

class ConnectionSheet extends StatelessWidget {
  const ConnectionSheet({
    super.key,
    required this.viewModel,
    required this.actions,
  });

  final ConnectionSettingsHostViewModel viewModel;
  final ConnectionSettingsHostActions actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;
    final contract = viewModel.contract;
    final identityFields = viewModel.fieldMap(contract.identitySection.fields);

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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: palette.dragHandle,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  contract.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  contract.description,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                _Section(
                  title: contract.identitySection.title,
                  child: Column(
                    children: [
                      _buildTextField(
                        identityFields[ConnectionSettingsFieldId.label]!,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildTextField(
                              identityFields[ConnectionSettingsFieldId.host]!,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              identityFields[ConnectionSettingsFieldId.port]!,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        identityFields[ConnectionSettingsFieldId.username]!,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: contract.remoteCodexSection.title,
                  child: Column(
                    children: contract.remoteCodexSection.fields.indexed
                        .map((entry) {
                          final index = entry.$1;
                          final field = entry.$2;
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom:
                                  index ==
                                      contract
                                              .remoteCodexSection
                                              .fields
                                              .length -
                                          1
                                  ? 0
                                  : 12,
                            ),
                            child: _buildTextField(field),
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: contract.authenticationSection.title,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<AuthMode>(
                        segments: contract.authenticationSection.options
                            .map(
                              (option) => ButtonSegment<AuthMode>(
                                value: option.mode,
                                label: Text(option.label),
                                icon: Icon(_iconForAuthOption(option)),
                              ),
                            )
                            .toList(growable: false),
                        selected: <AuthMode>{
                          contract.authenticationSection.selectedMode,
                        },
                        onSelectionChanged: (selection) {
                          actions.onAuthModeChanged(selection.first);
                        },
                      ),
                      const SizedBox(height: 14),
                      ...contract.authenticationSection.fields.indexed.map((
                        entry,
                      ) {
                        final index = entry.$1;
                        final field = entry.$2;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom:
                                index ==
                                    contract
                                            .authenticationSection
                                            .fields
                                            .length -
                                        1
                                ? 0
                                : 12,
                          ),
                          child: _buildTextField(field),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: contract.runModeSection.title,
                  child: Column(
                    children: contract.runModeSection.toggles
                        .map(
                          (toggle) => SwitchListTile.adaptive(
                            value: toggle.value,
                            onChanged: (value) {
                              actions.onToggleChanged(toggle.id, value);
                            },
                            contentPadding: EdgeInsets.zero,
                            title: Text(toggle.title),
                            subtitle: Text(toggle.subtitle),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(ConnectionSettingsTextFieldContract field) {
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
}

TextInputType _textInputType(ConnectionSettingsKeyboardType keyboardType) {
  return switch (keyboardType) {
    ConnectionSettingsKeyboardType.text => TextInputType.text,
    ConnectionSettingsKeyboardType.number => TextInputType.number,
  };
}

IconData _iconForAuthOption(ConnectionSettingsAuthOptionContract option) {
  return switch (option.icon) {
    ConnectionSettingsAuthOptionIcon.password => Icons.password,
    ConnectionSettingsAuthOptionIcon.privateKey => Icons.key,
  };
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.surfaceBorder),
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
    );
  }
}
