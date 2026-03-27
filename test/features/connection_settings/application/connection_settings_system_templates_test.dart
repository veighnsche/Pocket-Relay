import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_system_templates.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';

void main() {
  test(
    'derives reusable systems by host sign-in and prefers the fingerprinted variant',
    () {
      final first = SavedConnection(
        id: 'workspace_one',
        profile: ConnectionProfile.defaults().copyWith(
          label: 'Workspace One',
          host: 'devbox.local',
          port: 22,
          username: 'vince',
          workspaceDir: '/workspace/one',
          codexPath: 'codex',
          authMode: AuthMode.password,
          hostFingerprint: '',
        ),
        secrets: const ConnectionSecrets(password: 'secret-1'),
      );
      final second = SavedConnection(
        id: 'workspace_two',
        profile: ConnectionProfile.defaults().copyWith(
          label: 'Workspace Two',
          host: 'devbox.local',
          port: 22,
          username: 'vince',
          workspaceDir: '/workspace/two',
          codexPath: 'codex',
          authMode: AuthMode.password,
          hostFingerprint: 'aa:bb:cc:dd',
        ),
        secrets: const ConnectionSecrets(password: 'secret-1'),
      );
      final other = SavedConnection(
        id: 'workspace_three',
        profile: ConnectionProfile.defaults().copyWith(
          label: 'Workspace Three',
          host: 'buildbox.local',
          port: 2200,
          username: 'alice',
          workspaceDir: '/workspace/three',
          codexPath: 'codex',
          authMode: AuthMode.privateKey,
          hostFingerprint: '11:22:33:44',
        ),
        secrets: const ConnectionSecrets(
          privateKeyPem:
              '-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----',
          privateKeyPassphrase: 'passphrase',
        ),
      );

      final templates = deriveConnectionSettingsSystemTemplates(
        <SavedConnection>[first, second, other],
      );

      expect(templates, hasLength(2));
      expect(templates.first.id, 'workspace_two');
      expect(templates.first.profile.hostFingerprint, 'aa:bb:cc:dd');
      expect(templates.last.id, 'workspace_three');
    },
  );

  test(
    'applies a reusable system template without overwriting workspace fields',
    () {
      final template = SavedConnection(
        id: 'workspace_two',
        profile: ConnectionProfile.defaults().copyWith(
          label: 'Workspace Two',
          host: 'devbox.local',
          port: 2200,
          username: 'vince',
          workspaceDir: '/workspace/two',
          codexPath: 'codex',
          authMode: AuthMode.password,
          hostFingerprint: 'aa:bb:cc:dd',
        ),
        secrets: const ConnectionSecrets(password: 'secret-1'),
      );
      final draft = ConnectionSettingsDraft.fromConnection(
        profile: ConnectionProfile.defaults().copyWith(
          label: 'Current Workspace',
          host: '',
          username: '',
          workspaceDir: '/workspace/current',
          codexPath: 'codex-mcp',
          hostFingerprint: '',
        ),
        secrets: const ConnectionSecrets(),
      );

      final templates = deriveConnectionSettingsSystemTemplates(
        <SavedConnection>[template],
      );
      final nextDraft = applyConnectionSettingsSystemTemplate(
        draft: draft,
        template: templates.single,
      );

      expect(
        matchingConnectionSettingsSystemTemplateId(
          draft: nextDraft,
          templates: templates,
        ),
        templates.single.id,
      );
      expect(nextDraft.host, 'devbox.local');
      expect(nextDraft.port, '2200');
      expect(nextDraft.username, 'vince');
      expect(nextDraft.hostFingerprint, 'aa:bb:cc:dd');
      expect(nextDraft.password, 'secret-1');
      expect(nextDraft.workspaceDir, '/workspace/current');
      expect(nextDraft.codexPath, 'codex-mcp');
    },
  );
}
