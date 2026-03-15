import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_draft.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_presenter.dart';

void main() {
  group('ConnectionSettingsPresenter', () {
    const presenter = ConnectionSettingsPresenter();

    test(
      'derives validation from form state instead of widget-local validators',
      () {
        final initialProfile = _configuredProfile();
        final initialSecrets = const ConnectionSecrets(password: 'secret');
        final formState =
            ConnectionSettingsFormState.initial(
              profile: initialProfile,
              secrets: initialSecrets,
            ).copyWith(
              draft: ConnectionSettingsDraft.fromConnection(
                profile: initialProfile,
                secrets: initialSecrets,
              ).copyWith(host: '', port: '70000', password: ''),
            );

        final hiddenErrors = presenter.present(
          initialProfile: initialProfile,
          initialSecrets: initialSecrets,
          formState: formState,
        );
        final visibleErrors = presenter.present(
          initialProfile: initialProfile,
          initialSecrets: initialSecrets,
          formState: formState.revealValidationErrors(),
        );

        expect(
          _field(
            hiddenErrors.identitySection,
            ConnectionSettingsFieldId.host,
          ).errorText,
          isNull,
        );
        expect(
          _field(
            hiddenErrors.identitySection,
            ConnectionSettingsFieldId.port,
          ).errorText,
          isNull,
        );
        expect(
          _field(
            hiddenErrors.authenticationSection,
            ConnectionSettingsFieldId.password,
          ).errorText,
          isNull,
        );
        expect(hiddenErrors.saveAction.canSubmit, isFalse);
        expect(
          _field(
            visibleErrors.identitySection,
            ConnectionSettingsFieldId.host,
          ).errorText,
          'Host is required',
        );
        expect(
          _field(
            visibleErrors.identitySection,
            ConnectionSettingsFieldId.port,
          ).errorText,
          'Bad port',
        );
        expect(
          _field(
            visibleErrors.authenticationSection,
            ConnectionSettingsFieldId.password,
          ).errorText,
          'Password is required',
        );
        expect(visibleErrors.saveAction.canSubmit, isFalse);
        expect(visibleErrors.saveAction.submitPayload, isNull);
      },
    );

    test('derives auth visibility and validation from the selected mode', () {
      final initialProfile = _configuredProfile();
      const initialSecrets = ConnectionSecrets(password: 'secret');
      final formState =
          ConnectionSettingsFormState.initial(
            profile: initialProfile,
            secrets: initialSecrets,
          ).copyWith(
            draft: ConnectionSettingsDraft.fromConnection(
              profile: initialProfile,
              secrets: initialSecrets,
            ).copyWith(authMode: AuthMode.privateKey, privateKeyPem: ''),
            showValidationErrors: true,
          );

      final contract = presenter.present(
        initialProfile: initialProfile,
        initialSecrets: initialSecrets,
        formState: formState,
      );

      expect(contract.authenticationSection.selectedMode, AuthMode.privateKey);
      expect(
        contract.authenticationSection.fields.map((field) => field.id),
        <ConnectionSettingsFieldId>[
          ConnectionSettingsFieldId.privateKeyPem,
          ConnectionSettingsFieldId.privateKeyPassphrase,
        ],
      );
      expect(
        _field(
          contract.authenticationSection,
          ConnectionSettingsFieldId.privateKeyPem,
        ).errorText,
        'Private key is required',
      );
    });

    test(
      'derives dirty state and normalized save payload in the presenter',
      () {
        final initialProfile = _configuredProfile();
        const initialSecrets = ConnectionSecrets(password: 'secret');
        final formState =
            ConnectionSettingsFormState.initial(
              profile: initialProfile,
              secrets: initialSecrets,
            ).copyWith(
              draft:
                  ConnectionSettingsDraft.fromConnection(
                    profile: initialProfile,
                    secrets: initialSecrets,
                  ).copyWith(
                    label: '',
                    codexPath: 'codex-mcp',
                    dangerouslyBypassSandbox: true,
                  ),
              showValidationErrors: true,
            );

        final contract = presenter.present(
          initialProfile: initialProfile,
          initialSecrets: initialSecrets,
          formState: formState,
        );
        final payload = contract.saveAction.submitPayload;

        expect(contract.saveAction.hasChanges, isTrue);
        expect(contract.saveAction.requiresValidation, isTrue);
        expect(contract.saveAction.canSubmit, isTrue);
        expect(payload, isNotNull);
        expect(payload!.profile.label, 'Developer Box');
        expect(payload.profile.codexPath, 'codex-mcp');
        expect(payload.profile.dangerouslyBypassSandbox, isTrue);
        expect(payload.secrets.password, 'secret');
      },
    );
  });
}

ConnectionSettingsTextFieldContract _field(
  Object section,
  ConnectionSettingsFieldId fieldId,
) {
  final fields = switch (section) {
    ConnectionSettingsFieldSectionContract(:final fields) => fields,
    ConnectionSettingsAuthenticationSectionContract(:final fields) => fields,
    _ => throw ArgumentError.value(section, 'section'),
  };

  return fields.singleWhere((field) => field.id == fieldId);
}

ConnectionProfile _configuredProfile() {
  return ConnectionProfile.defaults().copyWith(
    label: 'Dev Box',
    host: 'devbox.local',
    username: 'vince',
    workspaceDir: '/workspace',
    codexPath: 'codex',
  );
}
