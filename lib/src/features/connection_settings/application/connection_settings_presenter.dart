import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';

part 'connection_settings_presenter_sections.dart';
part 'connection_settings_presenter_state.dart';

class ConnectionSettingsPresenter {
  const ConnectionSettingsPresenter();

  ConnectionSettingsContract present({
    required ConnectionProfile initialProfile,
    required ConnectionSecrets initialSecrets,
    required ConnectionSettingsFormState formState,
    ConnectionModelCatalog? availableModelCatalog,
    bool supportsModelCatalogRefresh = false,
    bool isRefreshingModelCatalog = false,
    bool supportsLocalConnectionMode = false,
  }) {
    final presentationState = _ConnectionSettingsPresentationState.fromForm(
      initialProfile: initialProfile,
      initialSecrets: initialSecrets,
      formState: formState,
      availableModelCatalog: availableModelCatalog,
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
      remoteConnectionSection: _buildRemoteConnectionSection(presentationState),
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
    );
  }

  String _descriptionFor({
    required ConnectionMode connectionMode,
    required bool supportsLocalConnectionMode,
  }) {
    if (!supportsLocalConnectionMode) {
      return 'Connect to a remote developer box over SSH and keep the Codex session readable on a smaller screen.';
    }

    return switch (connectionMode) {
      ConnectionMode.remote =>
        'Choose whether this desktop should reach Codex on a remote box or run it locally. Remote mode uses SSH and keeps the workspace on your developer box.',
      ConnectionMode.local =>
        'Choose whether this desktop should reach Codex on a remote box or run it locally. Local mode starts Codex app-server on this machine inside the selected workspace.',
    };
  }

  String _normalizedLabel(String label) {
    final trimmed = label.trim();
    return trimmed.isEmpty ? 'Developer Box' : trimmed;
  }
}
