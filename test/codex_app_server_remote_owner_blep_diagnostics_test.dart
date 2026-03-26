import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart';

final _BlepDiagnosticsConfig _blepDiagnosticsConfig =
    _resolveBlepDiagnosticsConfig();

void main() {
  test(
    'optional BLEP diagnostics isolate OpenSSH and dartssh2 owner behavior',
    () async {
      final config = _blepDiagnosticsConfig;
      final profile = config.profile!;
      final secrets = config.secrets!;
      const manualOwnerId = 'blep-diagnostics-manual';
      const dartOwnerId = 'blep-diagnostics-dart';
      final ownerControl = const CodexSshRemoteAppServerOwnerControl(
        readyPollAttempts: 20,
        readyPollDelay: Duration(milliseconds: 250),
        stopPollAttempts: 10,
        stopPollDelay: Duration(milliseconds: 150),
      );
      final ownerInspector = const CodexSshRemoteAppServerOwnerInspector();

      addTearDown(() async {
        await _bestEffortStop(
          ownerControl,
          profile: profile,
          secrets: secrets,
          ownerId: manualOwnerId,
        );
        await _bestEffortStop(
          ownerControl,
          profile: profile,
          secrets: secrets,
          ownerId: dartOwnerId,
        );
      });

      await _bestEffortStop(
        ownerControl,
        profile: profile,
        secrets: secrets,
        ownerId: manualOwnerId,
      );
      await _bestEffortStop(
        ownerControl,
        profile: profile,
        secrets: secrets,
        ownerId: dartOwnerId,
      );

      final manualSessionName = buildPocketRelayRemoteOwnerSessionName(
        ownerId: manualOwnerId,
      );
      final manualPort = buildPocketRelayRemoteOwnerPortCandidates(
        ownerId: manualOwnerId,
      ).first;
      final manualStart = _startOwnerViaOpenSsh(
        alias: config.alias,
        sessionName: manualSessionName,
        workspaceDir: profile.workspaceDir,
        port: manualPort,
      );
      if (!manualStart.ok) {
        fail('OpenSSH start failed.\n${manualStart.detail}');
      }

      final manualSnapshot = await ownerInspector.inspectOwner(
        profile: profile,
        secrets: secrets,
        ownerId: manualOwnerId,
        workspaceDir: profile.workspaceDir,
      );
      if (manualSnapshot.status != CodexRemoteAppServerOwnerStatus.running) {
        fail(
          'Dart inspector did not see the OpenSSH-started owner as running.\n'
          'snapshot=${_describeSnapshot(manualSnapshot)}\n'
          'openssh=${manualStart.detail}\n'
          'remote=${_rawOwnerState(alias: config.alias, sessionName: manualSessionName)}',
        );
      }

      final rawSessionName = buildPocketRelayRemoteOwnerSessionName(
        ownerId: dartOwnerId,
      );
      final rawStartCommand = buildSshRemoteOwnerStartCommand(
        sessionName: rawSessionName,
        workspaceDir: profile.workspaceDir,
        codexPath: profile.codexPath,
        port: buildPocketRelayRemoteOwnerPortCandidates(ownerId: dartOwnerId)
            .first,
      );
      final rawBootstrap = await connectSshBootstrapClient(
        profile: profile,
        secrets: secrets,
        verifyHostKey: (keyType, actualFingerprint) {
          return _normalizeFingerprint(profile.hostFingerprint) ==
              _normalizeFingerprint(actualFingerprint);
        },
      );
      await rawBootstrap.authenticate();
      final rawProcess = await rawBootstrap.launchProcess(rawStartCommand);
      final rawStdout = await _readStream(rawProcess.stdout);
      final rawStderr = await _readStream(rawProcess.stderr);
      await rawProcess.done;
      final rawDebug = await _runRawSshCommand(
        profile: profile,
        secrets: secrets,
        command: _buildImmediateTmuxDebugCommand(
          sessionName: rawSessionName,
          workspaceDir: profile.workspaceDir,
          port: buildPocketRelayRemoteOwnerPortCandidates(ownerId: dartOwnerId)
              .first,
        ),
      );
      final rawOpenSshStateBeforeClose = _rawOwnerState(
        alias: config.alias,
        sessionName: rawSessionName,
      );
      await rawProcess.close();
      final rawOpenSshStateAfterClose = _rawOwnerState(
        alias: config.alias,
        sessionName: rawSessionName,
      );

      if (!rawOpenSshStateBeforeClose.contains('HAS_SESSION\nyes')) {
        fail(
          'Raw dartssh2 start command did not create a visible tmux session even before close.\n'
          'stdout=$rawStdout\n'
          'stderr=$rawStderr\n'
          'exit=${rawProcess.exitCode}\n'
          'rawDebug=$rawDebug\n'
          'beforeClose=$rawOpenSshStateBeforeClose\n'
          'afterClose=$rawOpenSshStateAfterClose',
        );
      }

      final dartSnapshot = await ownerControl.startOwner(
        profile: profile,
        secrets: secrets,
        ownerId: dartOwnerId,
        workspaceDir: profile.workspaceDir,
      );
      final dartSessionName = buildPocketRelayRemoteOwnerSessionName(
        ownerId: dartOwnerId,
      );
      final rawDartOwnerState = _rawOwnerState(
        alias: config.alias,
        sessionName: dartSessionName,
      );

      if (dartSnapshot.status != CodexRemoteAppServerOwnerStatus.running) {
        fail(
          'dartssh2 startOwner did not produce a running owner.\n'
          'snapshot=${_describeSnapshot(dartSnapshot)}\n'
          'rawBeforeClose=$rawOpenSshStateBeforeClose\n'
          'rawAfterClose=$rawOpenSshStateAfterClose\n'
          'remote=$rawDartOwnerState',
        );
      }
    },
    skip: _blepDiagnosticsConfig.skipReason ?? false,
    timeout: Timeout.factor(4),
  );
}

final class _BlepDiagnosticsConfig {
  const _BlepDiagnosticsConfig({
    required this.alias,
    this.skipReason,
    this.profile,
    this.secrets,
  });

  final String alias;
  final String? skipReason;
  final ConnectionProfile? profile;
  final ConnectionSecrets? secrets;
}

_BlepDiagnosticsConfig _resolveBlepDiagnosticsConfig() {
  const alias = 'blep';
  if (!_runtimeFlagEnabled('POCKET_RELAY_RUN_REAL_REMOTE_SMOKE')) {
    return const _BlepDiagnosticsConfig(
      alias: alias,
      skipReason:
          'Set POCKET_RELAY_RUN_REAL_REMOTE_SMOKE=1 to run BLEP diagnostics.',
    );
  }

  final resolved = _resolveSshAlias(alias);
  if (resolved == null) {
    return const _BlepDiagnosticsConfig(
      alias: alias,
      skipReason: 'SSH alias `blep` is not configured.',
    );
  }

  final hostname = resolved['hostname']?.trim() ?? '';
  final username = resolved['user']?.trim() ?? '';
  final port = int.tryParse((resolved['port'] ?? '').trim());
  final identityFile = _expandHomePath((resolved['identityfile'] ?? '').trim());
  if (hostname.isEmpty || hostname == alias) {
    return const _BlepDiagnosticsConfig(
      alias: alias,
      skipReason: 'SSH alias `blep` did not resolve to a concrete host.',
    );
  }
  if (username.isEmpty || port == null) {
    return const _BlepDiagnosticsConfig(
      alias: alias,
      skipReason: 'SSH alias `blep` did not resolve to a usable user/port.',
    );
  }
  if (identityFile.isEmpty || !File(identityFile).existsSync()) {
    return const _BlepDiagnosticsConfig(
      alias: alias,
      skipReason:
          'SSH alias `blep` did not resolve to a readable identity file.',
    );
  }

  final privateKeyPem = File(identityFile).readAsStringSync().trim();
  if (privateKeyPem.isEmpty) {
    return const _BlepDiagnosticsConfig(
      alias: alias,
      skipReason: 'Resolved SSH identity file for `blep` was empty.',
    );
  }

  final hostFingerprint = _readEd25519Fingerprint(
    hostname: hostname,
    port: port,
  );
  if (hostFingerprint == null || hostFingerprint.isEmpty) {
    return const _BlepDiagnosticsConfig(
      alias: alias,
      skipReason: 'Could not resolve an ED25519 host fingerprint for `blep`.',
    );
  }

  return _BlepDiagnosticsConfig(
    alias: alias,
    profile: ConnectionProfile.defaults().copyWith(
      label: 'blep',
      host: hostname,
      port: port,
      username: username,
      workspaceDir: '/home/$username',
      codexPath: 'codex',
      authMode: AuthMode.privateKey,
      hostFingerprint: hostFingerprint,
      connectionMode: ConnectionMode.remote,
    ),
    secrets: ConnectionSecrets(privateKeyPem: privateKeyPem),
  );
}

Future<void> _bestEffortStop(
  CodexSshRemoteAppServerOwnerControl ownerControl, {
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required String ownerId,
}) async {
  try {
    await ownerControl.stopOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: profile.workspaceDir,
    );
  } catch (_) {
    // Best effort cleanup only.
  }
}

String _describeSnapshot(CodexRemoteAppServerOwnerSnapshot snapshot) {
  return 'status=${snapshot.status} detail=${snapshot.detail} '
      'pid=${snapshot.pid} endpoint=${snapshot.endpoint?.host}:${snapshot.endpoint?.port}';
}

Future<String> _readStream(Stream<List<int>> stream) async {
  final buffer = StringBuffer();
  await for (final chunk in stream) {
    buffer.write(String.fromCharCodes(chunk));
  }
  return buffer.toString();
}

Future<String> _runRawSshCommand({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required String command,
}) async {
  final client = await connectSshBootstrapClient(
    profile: profile,
    secrets: secrets,
    verifyHostKey: (keyType, actualFingerprint) {
      return _normalizeFingerprint(profile.hostFingerprint) ==
          _normalizeFingerprint(actualFingerprint);
    },
  );
  await client.authenticate();
  final process = await client.launchProcess(command);
  final stdout = await _readStream(process.stdout);
  final stderr = await _readStream(process.stderr);
  await process.done;
  final exitCode = process.exitCode;
  await process.close();
  return 'exit=$exitCode\nstdout=$stdout\nstderr=$stderr';
}

String _buildImmediateTmuxDebugCommand({
  required String sessionName,
  required String workspaceDir,
  required int port,
}) {
  final logFile = buildPocketRelayRemoteOwnerLogFilePath(
    sessionName: sessionName,
  );
  final tmuxCommand =
      '''
launch_command="codex app-server --listen ws://127.0.0.1:$port"
log_file="$logFile"
rm -f "\$log_file"
eval "\$launch_command" >>"\$log_file" 2>&1
app_status=\$?
echo "pocket-relay: codex app-server exited with status \$app_status" >>"\$log_file"
exit "\$app_status"
''';
  final paneCommand = 'exec bash -lc ${_shellQuote(tmuxCommand)}';
  final script =
      '''
set -euo pipefail
printf 'HOME=%s\\nPATH=%s\\nSHELL=%s\\nTMPDIR=%s\\nTMUX_TMPDIR=%s\\nXDG_RUNTIME_DIR=%s\\n' "\${HOME-}" "\${PATH-}" "\${SHELL-}" "\${TMPDIR-}" "\${TMUX_TMPDIR-}" "\${XDG_RUNTIME_DIR-}"
command -v tmux || true
command -v codex || true
tmux kill-session -t ${_shellQuote(sessionName)} 2>/dev/null || true
rm -f ${_shellQuote(logFile)}
pane_id=\$(tmux new-session -d -P -F '#{pane_id}' -s ${_shellQuote(sessionName)} -c ${_shellQuote(workspaceDir)})
printf 'pane_id=%s\\n' "\$pane_id"
tmux respawn-pane -k -t "\$pane_id" ${_shellQuote(paneCommand)}
printf 'start_exit=%s\\n' '0'
tmux has-session -t ${_shellQuote(sessionName)} 2>/dev/null && echo has_immediate=yes || echo has_immediate=no
echo LIST
tmux list-sessions 2>/dev/null || true
echo CLIENTS
tmux list-clients -F 'tty=#{client_tty} session=#{session_name} attached=#{session_attached}' 2>/dev/null || true
echo OPTIONS
tmux show-options -g destroy-unattached 2>/dev/null || true
tmux show-options -g exit-empty 2>/dev/null || true
echo PANES
tmux list-panes -t ${_shellQuote(sessionName)} -F 'pid=#{pane_pid} cmd=#{pane_current_command} path=#{pane_current_path}' 2>/dev/null || true
echo PS
pane_pid=\$(tmux list-panes -t ${_shellQuote(sessionName)} -F '#{pane_pid}' 2>/dev/null | head -n 1 | tr -d '[:space:]')
if [ -n "\$pane_pid" ]; then
  ps -o pid=,ppid=,args= -p "\$pane_pid" || true
  ps -o pid=,ppid=,args= --ppid "\$pane_pid" || true
fi
echo LOG
cat ${_shellQuote(logFile)} 2>/dev/null || true
''';
  return 'bash -lc ${_shellQuote(script)}';
}

_ShellResult _startOwnerViaOpenSsh({
  required String alias,
  required String sessionName,
  required String workspaceDir,
  required int port,
}) {
  final logFile = buildPocketRelayRemoteOwnerLogFilePath(
    sessionName: sessionName,
  );
  final script =
      '''
set -euo pipefail
tmux kill-session -t ${_shellQuote(sessionName)} 2>/dev/null || true
rm -f ${_shellQuote(logFile)}
tmux new-session -d -s ${_shellQuote(sessionName)} -c ${_shellQuote(workspaceDir)} "bash -lc 'launch_command=\\\"codex app-server --listen ws://127.0.0.1:$port\\\"; log_file=\\\"$logFile\\\"; rm -f \\\"\\\$log_file\\\"; eval \\\"\\\$launch_command\\\" >>\\\"\\\$log_file\\\" 2>&1; app_status=\\\$?; echo \\\"pocket-relay: codex app-server exited with status \\\$app_status\\\" >>\\\"\\\$log_file\\\"; exit \\\"\\\$app_status\\\"'"
sleep 1
tmux has-session -t ${_shellQuote(sessionName)} 2>/dev/null && echo HAS_SESSION=yes || echo HAS_SESSION=no
printf 'LOG\\n'
cat ${_shellQuote(logFile)} 2>/dev/null || true
''';
  final result = Process.runSync(
    'ssh',
    <String>[alias, 'bash -lc ${_shellQuote(script)}'],
  );
  return _ShellResult(
    ok: result.exitCode == 0,
    detail: 'exit=${result.exitCode}\nstdout=${result.stdout}\nstderr=${result.stderr}',
  );
}

String _rawOwnerState({required String alias, required String sessionName}) {
  final logFile = buildPocketRelayRemoteOwnerLogFilePath(
    sessionName: sessionName,
  );
  final script =
      '''
set -euo pipefail
echo 'HAS_SESSION'
tmux has-session -t ${_shellQuote(sessionName)} 2>/dev/null && echo yes || echo no
echo 'LIST_PANES'
tmux list-panes -t ${_shellQuote(sessionName)} -F 'pid=#{pane_pid} cmd=#{pane_current_command} path=#{pane_current_path}' 2>/dev/null || true
echo 'LOG'
cat ${_shellQuote(logFile)} 2>/dev/null || true
''';
  final result = Process.runSync(
    'ssh',
    <String>[alias, 'bash -lc ${_shellQuote(script)}'],
  );
  return 'exit=${result.exitCode}\nstdout=${result.stdout}\nstderr=${result.stderr}';
}

Map<String, String>? _resolveSshAlias(String alias) {
  final result = Process.runSync('/bin/bash', <String>['-lc', 'ssh -G $alias']);
  if (result.exitCode != 0) {
    return null;
  }

  final resolved = <String, String>{};
  for (final line in (result.stdout as String).split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final separatorIndex = trimmed.indexOf(' ');
    if (separatorIndex <= 0) {
      continue;
    }
    resolved[trimmed.substring(0, separatorIndex)] = trimmed
        .substring(separatorIndex + 1)
        .trim();
  }
  return resolved;
}

String _expandHomePath(String path) {
  if (!path.startsWith('~/')) {
    return path;
  }
  final home = Platform.environment['HOME'] ?? '';
  if (home.isEmpty) {
    return path;
  }
  return '$home/${path.substring(2)}';
}

String? _readEd25519Fingerprint({required String hostname, required int port}) {
  final command =
      '''
set -o pipefail
ssh-keyscan -p $port ${_shellQuote(hostname)} 2>/dev/null |
ssh-keygen -l -E md5 -f - 2>/dev/null |
awk '
  /\\(ED25519\\)\$/ { value=\$2; sub(/^MD5:/, "", value); print value; found=1; exit }
  NR == 1 { fallback=\$2 }
  END {
    if (!found && fallback != "") {
      sub(/^MD5:/, "", fallback)
      print fallback
    }
  }
'
''';
  final result = Process.runSync('/bin/bash', <String>['-lc', command]);
  if (result.exitCode != 0) {
    return null;
  }
  final fingerprint = (result.stdout as String)
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  return fingerprint.isEmpty ? null : fingerprint;
}

bool _runtimeFlagEnabled(String key) {
  final rawValue = const String.fromEnvironment(
    'POCKET_RELAY_RUN_REAL_REMOTE_SMOKE',
  );
  return switch (rawValue.trim().toLowerCase()) {
    '1' || 'true' || 'yes' || 'on' => true,
    _ => false,
  };
}

String _shellQuote(String value) {
  return "'${value.replaceAll("'", "'\"'\"'")}'";
}

String _normalizeFingerprint(String value) {
  return value.replaceAll(':', '').trim().toLowerCase();
}

final class _ShellResult {
  const _ShellResult({required this.ok, required this.detail});

  final bool ok;
  final String detail;
}
