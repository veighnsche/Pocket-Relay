import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';

part 'connection_settings_presenter_state.dart';
part 'presenter/helper_text.dart';
part 'presenter/section_authentication.dart';
part 'presenter/section_codex.dart';
part 'presenter/section_model.dart';
part 'presenter/section_profile.dart';
part 'presenter/submit_payload.dart';

class ConnectionSettingsPresenter {
  const ConnectionSettingsPresenter();

  ConnectionSettingsContract present({
    required ConnectionProfile initialProfile,
    required ConnectionSecrets initialSecrets,
    required ConnectionSettingsFormState formState,
    ConnectionRemoteRuntimeState? remoteRuntime,
    ConnectionModelCatalog? availableModelCatalog,
    ConnectionSettingsModelCatalogSource? availableModelCatalogSource,
    PocketUserFacingError? modelCatalogRefreshError,
    bool supportsModelCatalogRefresh = false,
    bool isRefreshingModelCatalog = false,
    bool supportsLocalConnectionMode = false,
  }) {
    final presentationState = _ConnectionSettingsPresentationState.fromForm(
      initialProfile: initialProfile,
      initialSecrets: initialSecrets,
      formState: formState,
      availableModelCatalog: availableModelCatalog,
      availableModelCatalogSource: availableModelCatalogSource,
      modelCatalogRefreshError: modelCatalogRefreshError,
      supportsModelCatalogRefresh: supportsModelCatalogRefresh,
      isRefreshingModelCatalog: isRefreshingModelCatalog,
    );

    return ConnectionSettingsContract(
      title: 'Connection',
      description: _descriptionFor(
        connectionMode: presentationState.draft.connectionMode,
        supportsLocalConnectionMode: supportsLocalConnectionMode,
      ),
      profileSection: _buildProfileSection(presentationState.draft),
      connectionModeSection: _buildConnectionModeSection(
        presentationState.draft,
        supportsLocalConnectionMode: supportsLocalConnectionMode,
      ),
      remoteConnectionSection: _buildRemoteConnectionSection(
        presentationState,
        remoteRuntime: remoteRuntime,
      ),
      authenticationSection: _buildAuthenticationSection(presentationState),
      codexSection: _buildCodexSection(presentationState),
      modelSection: _buildModelSection(presentationState),
      runModeSection: ConnectionSettingsRunModeSectionContract(
        title: 'Run mode',
        toggles: <ConnectionSettingsToggleContract>[
          ConnectionSettingsToggleContract(
            id: ConnectionSettingsToggleId.dangerouslyBypassSandbox,
            title: 'Dangerous full access',
            subtitle:
                'Turns off the safer auto sandbox and gives Codex direct unsandboxed execution for this connection.',
            value: presentationState.draft.dangerouslyBypassSandbox,
          ),
          ConnectionSettingsToggleContract(
            id: ConnectionSettingsToggleId.ephemeralSession,
            title: 'Ephemeral turns',
            subtitle: 'Do not keep Codex session history between prompts.',
            value: presentationState.draft.ephemeralSession,
          ),
        ],
      ),
      saveAction: ConnectionSettingsSaveActionContract(
        label: 'Save',
        hasChanges: presentationState.hasChanges,
        requiresValidation: presentationState.hasChanges,
        canSubmit: presentationState.canSubmit,
        submitPayload: !presentationState.canSubmit
            ? null
            : _buildSubmitPayload(
                initialProfile: initialProfile,
                initialSecrets: initialSecrets,
                state: presentationState,
              ),
      ),
      remoteRuntime: presentationState.isRemote ? remoteRuntime : null,
    );
  }

  String _descriptionFor({
    required ConnectionMode connectionMode,
    required bool supportsLocalConnectionMode,
  }) {
    if (!supportsLocalConnectionMode) {
      return 'Set the SSH target and workspace Pocket Relay should use for this connection.';
    }

    return switch (connectionMode) {
      ConnectionMode.remote =>
        'This connection runs Codex on a remote box over SSH. Switch to Local if this device should host the workspace instead.',
      ConnectionMode.local =>
        'This connection runs Codex on this device. Switch to Remote if Codex should stay on a developer box instead.',
    };
  }

  String _normalizedLabel(String label) {
    final trimmed = label.trim();
    return trimmed.isEmpty ? 'Developer Box' : trimmed;
  }
}
