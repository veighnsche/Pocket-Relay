import 'package:pocket_relay/src/agent_adapters/agent_adapter_capabilities.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_registry.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_system_templates.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_system_template.dart';

part 'connection_settings_presenter_state.dart';
part 'presenter/helper_text.dart';
part 'presenter/section_authentication.dart';
part 'presenter/section_host.dart';
part 'presenter/section_model.dart';
part 'presenter/section_profile.dart';
part 'presenter/section_system.dart';
part 'presenter/submit_payload.dart';

class ConnectionSettingsPresenter {
  const ConnectionSettingsPresenter();

  ConnectionSettingsContract present({
    required ConnectionProfile initialProfile,
    required ConnectionSecrets initialSecrets,
    required ConnectionSettingsFormState formState,
    AgentAdapterCapabilities? agentAdapterCapabilities,
    bool isSystemSettings = false,
    ConnectionRemoteRuntimeState? remoteRuntime,
    ConnectionModelCatalog? availableModelCatalog,
    ConnectionSettingsModelCatalogSource? availableModelCatalogSource,
    PocketUserFacingError? modelCatalogRefreshError,
    bool supportsModelCatalogRefresh = false,
    bool isRefreshingModelCatalog = false,
    List<ConnectionSettingsSystemTemplate> availableSystemTemplates =
        const <ConnectionSettingsSystemTemplate>[],
    bool isTestingSystem = false,
    String? systemTestFailure,
    bool supportsSystemTesting = false,
    bool supportsLocalConnectionMode = false,
  }) {
    final resolvedAgentAdapterCapabilities =
        agentAdapterCapabilities ??
        agentAdapterCapabilitiesFor(formState.draft.agentAdapter);
    final presentationState = _ConnectionSettingsPresentationState.fromForm(
      initialProfile: initialProfile,
      initialSecrets: initialSecrets,
      formState: formState,
      agentAdapterCapabilities: resolvedAgentAdapterCapabilities,
      isSystemSettings: isSystemSettings,
      availableModelCatalog: availableModelCatalog,
      availableModelCatalogSource: availableModelCatalogSource,
      modelCatalogRefreshError: modelCatalogRefreshError,
      supportsModelCatalogRefresh: supportsModelCatalogRefresh,
      isRefreshingModelCatalog: isRefreshingModelCatalog,
      availableSystemTemplates: availableSystemTemplates,
      isTestingSystem: isTestingSystem,
      systemTestFailure: systemTestFailure,
      supportsSystemTesting: supportsSystemTesting,
    );
    final adapterLabel = agentAdapterLabel(
      presentationState.draft.agentAdapter,
    );

    return ConnectionSettingsContract(
      title: 'Workspace',
      profileSection: _buildProfileSection(presentationState.draft),
      connectionModeSection: _buildConnectionModeSection(
        presentationState.draft,
        supportsLocalConnectionMode: supportsLocalConnectionMode,
      ),
      systemPicker: _buildSystemPicker(presentationState),
      remoteConnectionSection: _buildRemoteConnectionSection(
        presentationState,
        remoteRuntime: remoteRuntime,
      ),
      authenticationSection: _buildAuthenticationSection(presentationState),
      systemTrust: _buildSystemTrust(presentationState),
      agentAdapterSection: _buildHostSection(presentationState),
      modelSection: _buildModelSection(presentationState),
      runModeSection: ConnectionSettingsRunModeSectionContract(
        title: 'Run mode',
        toggles: <ConnectionSettingsToggleContract>[
          if (presentationState
              .agentAdapterCapabilities
              .supportsDangerouslyBypassSandbox)
            ConnectionSettingsToggleContract(
              id: ConnectionSettingsToggleId.dangerouslyBypassSandbox,
              title: 'Dangerous full access',
              subtitle:
                  'Turns off the safer auto sandbox and gives $adapterLabel direct unsandboxed execution for this workspace.',
              value: presentationState.draft.dangerouslyBypassSandbox,
            ),
          if (presentationState
              .agentAdapterCapabilities
              .supportsEphemeralSessions)
            ConnectionSettingsToggleContract(
              id: ConnectionSettingsToggleId.ephemeralSession,
              title: 'Ephemeral workspace',
              subtitle:
                  'Do not keep $adapterLabel session history between prompts.',
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

  String _normalizedLabel(String label) {
    final trimmed = label.trim();
    return trimmed.isEmpty ? 'Workspace' : trimmed;
  }
}
