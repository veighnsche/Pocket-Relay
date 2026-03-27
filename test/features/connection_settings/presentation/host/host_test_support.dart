import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_system_probe.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_system_template.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_host.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_sheet.dart';

Widget buildMaterialSettingsApp({
  Brightness brightness = Brightness.light,
  required ValueChanged<ConnectionSettingsSubmitPayload> onSubmit,
  PocketPlatformBehavior platformBehavior = mobileSettingsBehavior,
  ConnectionRemoteRuntimeState? initialRemoteRuntime,
  ConnectionModelCatalog? availableModelCatalog,
  ConnectionSettingsModelCatalogSource? availableModelCatalogSource,
  ConnectionProfile? initialProfile,
  Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
  onRefreshModelCatalog,
  ConnectionSettingsRemoteRuntimeRefresher? onRefreshRemoteRuntime,
  List<ConnectionSettingsSystemTemplate> availableSystemTemplates =
      const <ConnectionSettingsSystemTemplate>[],
  ConnectionSettingsSystemTester? onTestSystem,
  ConnectionSettingsHostBuilder? builder,
}) {
  return MaterialApp(
    theme: buildPocketTheme(brightness),
    darkTheme: buildPocketTheme(Brightness.dark),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(
      body: buildSettingsHost(
        onSubmit: onSubmit,
        platformBehavior: platformBehavior,
        initialRemoteRuntime: initialRemoteRuntime,
        availableModelCatalog: availableModelCatalog,
        availableModelCatalogSource: availableModelCatalogSource,
        initialProfile: initialProfile,
        onRefreshModelCatalog: onRefreshModelCatalog,
        onRefreshRemoteRuntime: onRefreshRemoteRuntime,
        availableSystemTemplates: availableSystemTemplates,
        onTestSystem: onTestSystem ?? defaultSystemTester,
        builder:
            builder ??
            (context, viewModel, actions) {
              return ConnectionSheet(
                platformBehavior: platformBehavior,
                viewModel: viewModel,
                actions: actions,
              );
            },
      ),
    ),
  );
}

Widget buildSettingsHost({
  required ValueChanged<ConnectionSettingsSubmitPayload> onSubmit,
  required ConnectionSettingsHostBuilder builder,
  PocketPlatformBehavior platformBehavior = mobileSettingsBehavior,
  ConnectionRemoteRuntimeState? initialRemoteRuntime,
  ConnectionModelCatalog? availableModelCatalog,
  ConnectionSettingsModelCatalogSource? availableModelCatalogSource,
  ConnectionProfile? initialProfile,
  Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
  onRefreshModelCatalog,
  ConnectionSettingsRemoteRuntimeRefresher? onRefreshRemoteRuntime,
  List<ConnectionSettingsSystemTemplate> availableSystemTemplates =
      const <ConnectionSettingsSystemTemplate>[],
  ConnectionSettingsSystemTester? onTestSystem,
}) {
  return ConnectionSettingsHost(
    initialProfile: initialProfile ?? configuredConnectionProfile(),
    initialSecrets: const ConnectionSecrets(password: 'secret'),
    initialRemoteRuntime: initialRemoteRuntime,
    availableModelCatalog: availableModelCatalog,
    availableModelCatalogSource: availableModelCatalogSource,
    onRefreshModelCatalog: onRefreshModelCatalog,
    onRefreshRemoteRuntime: onRefreshRemoteRuntime,
    availableSystemTemplates: availableSystemTemplates,
    onTestSystem: onTestSystem ?? defaultSystemTester,
    platformBehavior: platformBehavior,
    onCancel: () {},
    onSubmit: onSubmit,
    builder: builder,
  );
}

Finder materialTextField(String label) {
  return find.byKey(settingsFieldKey(settingsFieldIdForLabel(label)));
}

ValueKey<String> settingsFieldKey(ConnectionSettingsFieldId fieldId) {
  return ValueKey<String>('connection_settings_${fieldId.name}');
}

ConnectionSettingsFieldId settingsFieldIdForLabel(String label) {
  return switch (label) {
    'Profile label' || 'Workspace name' => ConnectionSettingsFieldId.label,
    'Host' => ConnectionSettingsFieldId.host,
    'Port' || 'SSH port' => ConnectionSettingsFieldId.port,
    'Username' || 'SSH username' => ConnectionSettingsFieldId.username,
    'Workspace directory' => ConnectionSettingsFieldId.workspaceDir,
    'Codex launch command' ||
    'Codex command' => ConnectionSettingsFieldId.codexPath,
    'Host fingerprint' => ConnectionSettingsFieldId.hostFingerprint,
    'SSH password' || 'Password' => ConnectionSettingsFieldId.password,
    'Private key PEM' ||
    'Private key' => ConnectionSettingsFieldId.privateKeyPem,
    'Key passphrase (optional)' =>
      ConnectionSettingsFieldId.privateKeyPassphrase,
    _ => throw ArgumentError.value(label, 'label', 'Unknown settings field'),
  };
}

ConnectionProfile configuredConnectionProfile() {
  return ConnectionProfile.defaults().copyWith(
    label: 'Dev Box',
    host: 'devbox.local',
    username: 'vince',
    workspaceDir: '/workspace',
    codexPath: 'codex',
    hostFingerprint: 'aa:bb:cc:dd',
  );
}

ConnectionModelCatalog backendAvailableModelCatalog() {
  return ConnectionModelCatalog(
    connectionId: 'conn_primary',
    fetchedAt: DateTime.utc(2026, 3, 22),
    models: const <ConnectionAvailableModel>[
      ConnectionAvailableModel(
        id: 'preset_gpt_live_default',
        model: 'gpt-live-default',
        displayName: 'GPT Live Default',
        description: 'Live backend default.',
        hidden: false,
        supportedReasoningEfforts:
            <ConnectionAvailableModelReasoningEffortOption>[
              ConnectionAvailableModelReasoningEffortOption(
                reasoningEffort: CodexReasoningEffort.minimal,
                description: 'Fastest backend lane mode.',
              ),
              ConnectionAvailableModelReasoningEffortOption(
                reasoningEffort: CodexReasoningEffort.xhigh,
                description: 'Deepest backend lane mode.',
              ),
            ],
        defaultReasoningEffort: CodexReasoningEffort.xhigh,
        inputModalities: <String>['text'],
        supportsPersonality: false,
        isDefault: true,
      ),
    ],
  );
}

const mobileSettingsBehavior = PocketPlatformBehavior(
  experience: PocketPlatformExperience.mobile,
  supportsLocalConnectionMode: false,
  supportsWakeLock: true,
  supportsFiniteBackgroundGrace: false,
  supportsActiveTurnForegroundService: false,
  usesDesktopKeyboardSubmit: false,
  supportsCollapsibleDesktopSidebar: false,
);

const desktopSettingsBehavior = PocketPlatformBehavior(
  experience: PocketPlatformExperience.desktop,
  supportsLocalConnectionMode: true,
  supportsWakeLock: false,
  supportsFiniteBackgroundGrace: false,
  supportsActiveTurnForegroundService: false,
  usesDesktopKeyboardSubmit: true,
  supportsCollapsibleDesktopSidebar: false,
);

const pausedRemoteRuntimeForTest = ConnectionRemoteRuntimeState(
  hostCapability: ConnectionRemoteHostCapabilityState(
    status: ConnectionRemoteHostCapabilityStatus.unknown,
    detail:
        'Pocket Relay pauses remote checks while you edit authentication settings.',
  ),
  server: ConnectionRemoteServerState.unknown(),
);

Future<ConnectionSettingsSystemTestResult> defaultSystemTester(
  ConnectionProfile profile,
  ConnectionSecrets _,
) async {
  final fingerprint = profile.hostFingerprint.trim();
  return ConnectionSettingsSystemTestResult(
    keyType: 'ssh-ed25519',
    fingerprint: fingerprint.isEmpty ? 'aa:bb:cc:dd' : fingerprint,
  );
}
