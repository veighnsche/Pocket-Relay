import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_ssh_process.dart';

void main() {
  test('builds a remote command for a plain codex binary', () {
    final command = buildSshCodexAppServerCommand(
      profile: _profile().copyWith(codexPath: 'codex'),
    );

    expect(
      command,
      "bash -lc 'cd '\"'\"'/workspace'\"'\"' && codex app-server --listen stdio://'",
    );
  });

  test('builds a remote command for a launch command with spaces', () {
    final command = buildSshCodexAppServerCommand(
      profile: _profile().copyWith(codexPath: 'just codex-mcp'),
    );

    expect(
      command,
      "bash -lc 'cd '\"'\"'/workspace'\"'\"' && just codex-mcp app-server --listen stdio://'",
    );
  });
}

ConnectionProfile _profile() {
  return const ConnectionProfile(
    label: 'Developer Box',
    host: 'example.com',
    port: 22,
    username: 'vince',
    workspaceDir: '/workspace',
    codexPath: 'codex',
    authMode: AuthMode.password,
    hostFingerprint: '',
    dangerouslyBypassSandbox: false,
    ephemeralSession: false,
  );
}
