import 'package:flutter/cupertino.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_host.dart';

class CupertinoConnectionSheet extends StatelessWidget {
  const CupertinoConnectionSheet({
    super.key,
    required this.viewModel,
    required this.actions,
  });

  final ConnectionSettingsHostViewModel viewModel;
  final ConnectionSettingsHostActions actions;

  @override
  Widget build(BuildContext context) {
    final contract = viewModel.contract;
    final identityFields = viewModel.fieldMap(contract.identitySection.fields);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, keyboardInset + 12),
          child: CupertinoPopupSurface(
            blurSigma: 18,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xF4F5F5F7),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGrey3,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          contract.title,
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            color: CupertinoColors.label,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          contract.description,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _Section(
                          title: contract.identitySection.title,
                          child: Column(
                            children: [
                              _buildTextField(
                                identityFields[ConnectionSettingsFieldId
                                    .label]!,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _buildTextField(
                                      identityFields[ConnectionSettingsFieldId
                                          .host]!,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTextField(
                                      identityFields[ConnectionSettingsFieldId
                                          .port]!,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                identityFields[ConnectionSettingsFieldId
                                    .username]!,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
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
                        const SizedBox(height: 14),
                        _Section(
                          title: contract.authenticationSection.title,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CupertinoSlidingSegmentedControl<AuthMode>(
                                groupValue:
                                    contract.authenticationSection.selectedMode,
                                children: <AuthMode, Widget>{
                                  for (final option
                                      in contract.authenticationSection.options)
                                    option.mode: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _cupertinoIconForAuthOption(option),
                                            size: 16,
                                          ),
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
                              const SizedBox(height: 14),
                              ...contract.authenticationSection.fields.indexed
                                  .map((entry) {
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
                        const SizedBox(height: 14),
                        _Section(
                          title: contract.runModeSection.title,
                          child: Column(
                            children: contract.runModeSection.toggles
                                .map(
                                  (toggle) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                toggle.title,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: CupertinoColors.label,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                toggle.subtitle,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: CupertinoColors
                                                      .secondaryLabel,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        CupertinoSwitch(
                                          value: toggle.value,
                                          onChanged: (value) {
                                            actions.onToggleChanged(
                                              toggle.id,
                                              value,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: CupertinoButton(
                                color: CupertinoColors.systemGrey5,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                onPressed: actions.onCancel,
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: CupertinoColors.label,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CupertinoButton.filled(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(ConnectionSettingsTextFieldContract field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.secondaryLabel,
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
          onChanged: (value) {
            actions.onFieldChanged(field.id, value);
          },
        ),
        if (field.helperText case final helperText?) ...[
          const SizedBox(height: 6),
          Text(
            helperText,
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
        if (field.errorText case final errorText?) ...[
          const SizedBox(height: 6),
          Text(
            errorText,
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.systemRed,
            ),
          ),
        ],
      ],
    );
  }
}

TextInputType _textInputType(ConnectionSettingsKeyboardType keyboardType) {
  return switch (keyboardType) {
    ConnectionSettingsKeyboardType.text => TextInputType.text,
    ConnectionSettingsKeyboardType.number => TextInputType.number,
  };
}

IconData _cupertinoIconForAuthOption(
  ConnectionSettingsAuthOptionContract option,
) {
  return switch (option.icon) {
    ConnectionSettingsAuthOptionIcon.password => CupertinoIcons.lock_fill,
    ConnectionSettingsAuthOptionIcon.privateKey => CupertinoIcons.lock_shield,
  };
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CupertinoColors.systemGrey4.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: CupertinoColors.label,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
