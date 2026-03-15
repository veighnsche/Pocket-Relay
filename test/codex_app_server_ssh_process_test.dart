import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_ssh_process.dart';

void main() {
  test('builds a remote command for a plain codex binary', () {
    final command = buildSshCodexAppServerCommand(
      profile: _profile().copyWith(codexPath: 'codex'),
    );

    expect(command, startsWith("sh -lc '"));
    expect(command, contains(r'exec "$SHELL" -lc '));
    expect(command, contains('exec /bin/sh -lc '));
    expect(command, contains('/workspace'));
    expect(command, contains('codex app-server --listen stdio://'));
  });

  test('builds a remote command for a launch command with spaces', () {
    final command = buildSshCodexAppServerCommand(
      profile: _profile().copyWith(codexPath: 'just codex-mcp'),
    );

    expect(command, startsWith("sh -lc '"));
    expect(command, contains('/workspace'));
    expect(command, contains('just codex-mcp app-server --listen stdio://'));
  });

  test('prefers the remote account shell before falling back to sh', () {
    final command = buildSshCodexAppServerCommand(profile: _profile());

    expect(command, contains(r'if [ -n "${SHELL:-}" ]'));
    expect(command, contains(r'getent passwd "$(id -un)" | cut -d: -f7'));
    expect(command, contains(r'exec "$_pocket_relay_shell" -lc'));
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
    skipGitRepoCheck: true,
    dangerouslyBypassSandbox: false,
    ephemeralSession: false,
  );
}
