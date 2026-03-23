import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/utils/shell_utils.dart';

import 'codex_app_server_models.dart';
import 'codex_app_server_remote_owner.dart';
import 'codex_app_server_ssh_process.dart';

class CodexSshRemoteAppServerHostProbe
    implements CodexRemoteAppServerHostProbe {
  const CodexSshRemoteAppServerHostProbe({
    this.sshBootstrap = connectSshBootstrapClient,
  });

  final CodexSshProcessBootstrap sshBootstrap;

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    final result = await _runRemoteProbeCommand(
      profile: profile,
      secrets: secrets,
      sshBootstrap: sshBootstrap,
      command: buildSshRemoteHostCapabilityProbeCommand(profile: profile),
    );
    return _parseHostCapabilities(
      stdout: result.stdout,
      stderr: result.stderr,
      exitCode: result.exitCode,
    );
  }
}

class CodexSshRemoteAppServerOwnerInspector
    implements CodexRemoteAppServerOwnerInspector {
  const CodexSshRemoteAppServerOwnerInspector({
    this.sshBootstrap = connectSshBootstrapClient,
  });

  final CodexSshProcessBootstrap sshBootstrap;

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) {
    return CodexSshRemoteAppServerHostProbe(
      sshBootstrap: sshBootstrap,
    ).probeHostCapabilities(profile: profile, secrets: secrets);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    final sessionName = buildPocketRelayRemoteOwnerSessionName(
      ownerId: ownerId,
    );
    final result = await _runRemoteProbeCommand(
      profile: profile,
      secrets: secrets,
      sshBootstrap: sshBootstrap,
      command: buildSshRemoteOwnerInspectCommand(
        sessionName: sessionName,
        workspaceDir: workspaceDir,
      ),
    );
    return _parseOwnerSnapshot(
      ownerId: ownerId,
      workspaceDir: workspaceDir,
      sessionName: sessionName,
      stdout: result.stdout,
      stderr: result.stderr,
      exitCode: result.exitCode,
    );
  }
}

@visibleForTesting
String buildSshRemoteHostCapabilityProbeCommand({
  required ConnectionProfile profile,
}) {
  final command =
      '''
tmux_status=1
if command -v tmux >/dev/null 2>&1; then
  tmux_status=0
fi
codex_status=1
if cd ${shellEscape(profile.workspaceDir.trim())} >/dev/null 2>&1 && ${profile.codexPath.trim()} app-server --help >/dev/null 2>&1; then
  codex_status=0
fi
printf '__pocket_relay_capabilities__ tmux=%s codex=%s\\n' "\$tmux_status" "\$codex_status"
''';
  return 'bash -lc ${shellEscape(command)}';
}

@visibleForTesting
String buildPocketRelayRemoteOwnerSessionName({required String ownerId}) {
  final normalized = ownerId.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(ownerId, 'ownerId', 'must not be empty');
  }
  final sanitized = normalized
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final suffix = sanitized.isEmpty ? 'owner' : sanitized;
  return 'pocket-relay:$suffix';
}

@visibleForTesting
String buildSshRemoteOwnerInspectCommand({
  required String sessionName,
  required String workspaceDir,
}) {
  final command =
      '''
session_name=${shellEscape(sessionName)}
expected_workspace=${shellEscape(workspaceDir.trim())}

print_result() {
  status="\$1"
  pid="\$2"
  host="\$3"
  port="\$4"
  detail="\$5"
  printf '__pocket_relay_owner__ status=%s pid=%s host=%s port=%s detail=%s\\n' "\$status" "\$pid" "\$host" "\$port" "\$detail"
}

if ! command -v tmux >/dev/null 2>&1; then
  print_result unhealthy "" "" "" tmux_unavailable
  exit 0
fi

if ! tmux has-session -t "\$session_name" 2>/dev/null; then
  print_result missing "" "" "" session_missing
  exit 0
fi

pane_pid=\$(tmux list-panes -t "\$session_name" -F '#{pane_pid}' 2>/dev/null | head -n 1 | tr -d '[:space:]')
pane_path=\$(tmux display-message -p -t "\$session_name" '#{pane_current_path}' 2>/dev/null | head -n 1)

if [ -z "\$pane_pid" ] || [ "\$pane_pid" = "0" ]; then
  print_result stopped "" "" "" pane_missing
  exit 0
fi

if [ -n "\$expected_workspace" ] && [ "\$pane_path" != "\$expected_workspace" ]; then
  print_result unhealthy "\$pane_pid" "" "" workspace_mismatch
  exit 0
fi

process_args=\$(ps -p "\$pane_pid" -o args= 2>/dev/null | head -n 1)
if [ -z "\$process_args" ]; then
  print_result stopped "\$pane_pid" "" "" process_missing
  exit 0
fi

if [[ ! "\$process_args" =~ app-server ]]; then
  print_result stopped "\$pane_pid" "" "" process_missing
  exit 0
fi

listen_host=
port=
if [[ "\$process_args" =~ --listen[[:space:]]+ws://([^:[:space:]]+):([0-9]+) ]]; then
  listen_host="\${BASH_REMATCH[1]}"
  port="\${BASH_REMATCH[2]}"
else
  print_result stopped "\$pane_pid" "" "" listen_url_missing
  exit 0
fi

health_host="\$listen_host"
if [ "\$health_host" = "0.0.0.0" ]; then
  health_host=127.0.0.1
fi

http_status=
if exec 3<>"/dev/tcp/\$health_host/\$port" 2>/dev/null; then
  printf 'GET /readyz HTTP/1.1\\r\\nHost: %s\\r\\nConnection: close\\r\\n\\r\\n' "\$health_host" >&3
  response=\$(cat <&3 || true)
  exec 3<&-
  exec 3>&-
  if [[ "\$response" =~ ^HTTP/[0-9.]+ 200 ]]; then
    http_status=200
  fi
fi

if [ "\$http_status" = "200" ]; then
  print_result running "\$pane_pid" "\$health_host" "\$port" ready
else
  print_result unhealthy "\$pane_pid" "\$health_host" "\$port" ready_check_failed
fi
''';
  return 'bash -lc ${shellEscape(command)}';
}

Future<_RemoteProbeCommandResult> _runRemoteProbeCommand({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required CodexSshProcessBootstrap sshBootstrap,
  required String command,
}) async {
  final client = await sshBootstrap(
    profile: profile,
    secrets: secrets,
    verifyHostKey: (keyType, actualFingerprint) {
      final expectedFingerprint = profile.hostFingerprint.trim();
      if (expectedFingerprint.isEmpty) {
        return false;
      }
      return normalizeFingerprint(expectedFingerprint) ==
          normalizeFingerprint(actualFingerprint);
    },
  );

  try {
    await client.authenticate();
    final process = await client.launchProcess(command);
    try {
      final stdout = await _readProcessStream(process.stdout);
      final stderr = await _readProcessStream(process.stderr);
      await process.done;
      return _RemoteProbeCommandResult(
        stdout: stdout,
        stderr: stderr,
        exitCode: process.exitCode,
      );
    } finally {
      await process.close();
    }
  } catch (_) {
    client.close();
    rethrow;
  }
}

Future<String> _readProcessStream(Stream<List<int>> stream) async {
  final buffer = StringBuffer();
  await for (final chunk in stream) {
    buffer.write(utf8.decode(chunk));
  }
  return buffer.toString();
}

CodexRemoteAppServerOwnerSnapshot _parseOwnerSnapshot({
  required String ownerId,
  required String workspaceDir,
  required String sessionName,
  required String stdout,
  required String stderr,
  required int? exitCode,
}) {
  final line = stdout
      .split('\n')
      .map((entry) => entry.trim())
      .firstWhere(
        (entry) => entry.startsWith('__pocket_relay_owner__'),
        orElse: () => '',
      );
  if (line.isEmpty) {
    final detail = [
      if (exitCode != null) 'exit $exitCode',
      if (stderr.trim().isNotEmpty) stderr.trim(),
      if (stdout.trim().isNotEmpty) stdout.trim(),
    ].join(' | ');
    throw StateError(
      detail.isEmpty
          ? 'Remote owner inspection returned no parseable result.'
          : 'Remote owner inspection returned no parseable result: $detail',
    );
  }

  final fields = <String, String>{};
  for (final segment in line.split(RegExp(r'\s+')).skip(1)) {
    final separatorIndex = segment.indexOf('=');
    if (separatorIndex <= 0) {
      continue;
    }
    fields[segment.substring(0, separatorIndex)] = segment.substring(
      separatorIndex + 1,
    );
  }

  final status = switch (fields['status']) {
    'missing' => CodexRemoteAppServerOwnerStatus.missing,
    'stopped' => CodexRemoteAppServerOwnerStatus.stopped,
    'running' => CodexRemoteAppServerOwnerStatus.running,
    'unhealthy' => CodexRemoteAppServerOwnerStatus.unhealthy,
    _ => null,
  };
  if (status == null) {
    throw StateError(
      'Remote owner inspection returned an unknown status: ${fields['status']}.',
    );
  }

  final pid = int.tryParse(fields['pid'] ?? '');
  final host = fields['host'];
  final port = int.tryParse(fields['port'] ?? '');

  return CodexRemoteAppServerOwnerSnapshot(
    ownerId: ownerId,
    workspaceDir: workspaceDir,
    status: status,
    sessionName: sessionName,
    pid: pid,
    endpoint: host != null && host.isNotEmpty && port != null
        ? CodexRemoteAppServerEndpoint(host: host, port: port)
        : null,
    detail: _ownerDetailForCode(fields['detail']),
  );
}

CodexRemoteAppServerHostCapabilities _parseHostCapabilities({
  required String stdout,
  required String stderr,
  required int? exitCode,
}) {
  final match = RegExp(
    r'__pocket_relay_capabilities__\s+tmux=(\d+)\s+codex=(\d+)',
  ).firstMatch(stdout);
  if (match == null) {
    final detail = [
      if (exitCode != null) 'exit $exitCode',
      if (stderr.trim().isNotEmpty) stderr.trim(),
      if (stdout.trim().isNotEmpty) stdout.trim(),
    ].join(' | ');
    throw StateError(
      detail.isEmpty
          ? 'Remote host capability probe returned no parseable result.'
          : 'Remote host capability probe returned no parseable result: $detail',
    );
  }

  final issues = <ConnectionRemoteHostCapabilityIssue>{};
  if (match.group(1) != '0') {
    issues.add(ConnectionRemoteHostCapabilityIssue.tmuxMissing);
  }
  if (match.group(2) != '0') {
    issues.add(ConnectionRemoteHostCapabilityIssue.codexMissing);
  }

  return CodexRemoteAppServerHostCapabilities(
    issues: issues,
    detail: issues.isEmpty
        ? 'Remote host supports Pocket Relay continuity.'
        : null,
  );
}

String? _ownerDetailForCode(String? code) {
  return switch (code) {
    null || '' => null,
    'ready' => 'Remote Pocket Relay server is ready.',
    'session_missing' =>
      'No Pocket Relay server is running for this connection.',
    'pane_missing' =>
      'The Pocket Relay tmux owner exists but has no live pane process.',
    'process_missing' =>
      'The Pocket Relay tmux owner exists but the app-server process is not running.',
    'workspace_mismatch' =>
      'The Pocket Relay tmux owner exists but points at a different workspace.',
    'listen_url_missing' =>
      'The Pocket Relay tmux owner is not running a websocket app-server.',
    'ready_check_failed' =>
      'The Pocket Relay app-server is running but did not pass its readiness check.',
    'tmux_unavailable' => 'tmux is not available on the remote host.',
    _ => code,
  };
}

final class _RemoteProbeCommandResult {
  const _RemoteProbeCommandResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final String stdout;
  final String stderr;
  final int? exitCode;
}
