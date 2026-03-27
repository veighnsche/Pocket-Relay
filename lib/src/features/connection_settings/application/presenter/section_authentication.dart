part of '../connection_settings_presenter.dart';

ConnectionSettingsAuthenticationSectionContract? _buildAuthenticationSection(
  _ConnectionSettingsPresentationState state,
) {
  if (!state.isRemote) {
    return null;
  }

  final draft = state.draft;
  return ConnectionSettingsAuthenticationSectionContract(
    title: 'System access',
    selectedMode: draft.authMode,
    options: const <ConnectionSettingsAuthOptionContract>[
      ConnectionSettingsAuthOptionContract(
        mode: AuthMode.password,
        label: 'Password',
        icon: ConnectionSettingsAuthOptionIcon.password,
      ),
      ConnectionSettingsAuthOptionContract(
        mode: AuthMode.privateKey,
        label: 'Private key',
        icon: ConnectionSettingsAuthOptionIcon.privateKey,
      ),
    ],
    fields: switch (draft.authMode) {
      AuthMode.password => <ConnectionSettingsTextFieldContract>[
        ConnectionSettingsTextFieldContract(
          id: ConnectionSettingsFieldId.password,
          label: 'Password',
          value: draft.password,
          obscureText: true,
          errorText: state.passwordError,
        ),
      ],
      AuthMode.privateKey => <ConnectionSettingsTextFieldContract>[
        ConnectionSettingsTextFieldContract(
          id: ConnectionSettingsFieldId.privateKeyPem,
          label: 'Private key',
          value: draft.privateKeyPem,
          errorText: state.privateKeyError,
          minLines: 6,
          maxLines: 10,
          alignLabelWithHint: true,
        ),
        ConnectionSettingsTextFieldContract(
          id: ConnectionSettingsFieldId.privateKeyPassphrase,
          label: 'Key passphrase (optional)',
          value: draft.privateKeyPassphrase,
          obscureText: true,
        ),
      ],
    },
  );
}
