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

class CodexSshRemoteAppServerOwnerControl
    implements CodexRemoteAppServerOwnerControl {
  const CodexSshRemoteAppServerOwnerControl({
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
  }) {
    return CodexSshRemoteAppServerOwnerInspector(
      sshBootstrap: sshBootstrap,
    ).inspectOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    );
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> startOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    final existingSnapshot = await inspectOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    );
    switch (existingSnapshot.status) {
      case CodexRemoteAppServerOwnerStatus.running:
        return existingSnapshot;
      case CodexRemoteAppServerOwnerStatus.unhealthy:
        return existingSnapshot;
      case CodexRemoteAppServerOwnerStatus.stopped:
        await stopOwner(
          profile: profile,
          secrets: secrets,
          ownerId: ownerId,
          workspaceDir: workspaceDir,
        );
      case CodexRemoteAppServerOwnerStatus.missing:
        break;
    }

    final sessionName = buildPocketRelayRemoteOwnerSessionName(
      ownerId: ownerId,
    );
    CodexRemoteAppServerOwnerSnapshot? lastSnapshot;
    for (final port in buildPocketRelayRemoteOwnerPortCandidates(
      ownerId: ownerId,
    )) {
      await _runRemoteControlCommand(
        profile: profile,
        secrets: secrets,
        sshBootstrap: sshBootstrap,
        command: buildSshRemoteOwnerStartCommand(
          sessionName: sessionName,
          workspaceDir: workspaceDir,
          codexPath: profile.codexPath,
          port: port,
        ),
      );
      lastSnapshot = await _waitForOwnerReady(
        profile: profile,
        secrets: secrets,
        ownerId: ownerId,
        workspaceDir: workspaceDir,
        sshBootstrap: sshBootstrap,
      );
      if (lastSnapshot.status == CodexRemoteAppServerOwnerStatus.running) {
        return lastSnapshot;
      }
      if (!_shouldRetryRemoteOwnerStart(lastSnapshot)) {
        return lastSnapshot;
      }
      await _runRemoteControlCommand(
        profile: profile,
        secrets: secrets,
        sshBootstrap: sshBootstrap,
        command: buildSshRemoteOwnerStopCommand(sessionName: sessionName),
      );
    }

    if (lastSnapshot != null) {
      return lastSnapshot;
    }
    return inspectOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    );
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> stopOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    final sessionName = buildPocketRelayRemoteOwnerSessionName(
      ownerId: ownerId,
    );
    await _runRemoteControlCommand(
      profile: profile,
      secrets: secrets,
      sshBootstrap: sshBootstrap,
      command: buildSshRemoteOwnerStopCommand(sessionName: sessionName),
    );
    return _waitForOwnerStopped(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
      sshBootstrap: sshBootstrap,
    );
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> restartOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    await stopOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    );
    return startOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
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
List<int> buildPocketRelayRemoteOwnerPortCandidates({
  required String ownerId,
  int candidateCount = 8,
}) {
  final normalized = ownerId.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(ownerId, 'ownerId', 'must not be empty');
  }
  if (candidateCount <= 0) {
    throw ArgumentError.value(
      candidateCount,
      'candidateCount',
      'must be greater than zero',
    );
  }

  const minPort = 42000;
  const portRange = 20000;
  final basePort = minPort + (_fnv1a32(normalized) % portRange);
  final seenPorts = <int>{};
  final ports = <int>[];
  var offset = 0;
  while (ports.length < candidateCount) {
    final port = minPort + ((basePort - minPort + offset) % portRange);
    if (seenPorts.add(port)) {
      ports.add(port);
    }
    offset += 1;
  }
  return ports;
}

int _fnv1a32(String value) {
  const offsetBasis = 0x811C9DC5;
  const prime = 0x01000193;
  var hash = offsetBasis;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * prime) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
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

@visibleForTesting
String buildSshRemoteOwnerStartCommand({
  required String sessionName,
  required String workspaceDir,
  required String codexPath,
  required int port,
}) {
  final command =
      '''
session_name=${shellEscape(sessionName)}
workspace_dir=${shellEscape(workspaceDir.trim())}
launch_command=${shellEscape('${codexPath.trim()} app-server --listen ws://127.0.0.1:$port')}

if ! command -v tmux >/dev/null 2>&1; then
  echo 'tmux is not available on the remote host.' >&2
  exit 1
fi

if tmux has-session -t "\$session_name" 2>/dev/null; then
  echo "Pocket Relay tmux owner already exists: \$session_name" >&2
  exit 2
fi

tmux new-session -d -s "\$session_name" -c "\$workspace_dir" "\$launch_command"
''';
  return 'bash -lc ${shellEscape(command)}';
}

@visibleForTesting
String buildSshRemoteOwnerStopCommand({required String sessionName}) {
  final command =
      '''
session_name=${shellEscape(sessionName)}
if ! command -v tmux >/dev/null 2>&1; then
  exit 0
fi
if tmux has-session -t "\$session_name" 2>/dev/null; then
  tmux kill-session -t "\$session_name"
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

Future<void> _runRemoteControlCommand({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required CodexSshProcessBootstrap sshBootstrap,
  required String command,
}) async {
  final result = await _runRemoteProbeCommand(
    profile: profile,
    secrets: secrets,
    sshBootstrap: sshBootstrap,
    command: command,
  );
  final exitCode = result.exitCode ?? 0;
  if (exitCode == 0) {
    return;
  }
  final detail = [
    'exit $exitCode',
    if (result.stderr.trim().isNotEmpty) result.stderr.trim(),
    if (result.stdout.trim().isNotEmpty) result.stdout.trim(),
  ].join(' | ');
  throw StateError(
    detail.isEmpty
        ? 'Remote owner control command failed.'
        : 'Remote owner control command failed: $detail',
  );
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

bool _shouldRetryRemoteOwnerStart(CodexRemoteAppServerOwnerSnapshot snapshot) {
  return switch (snapshot.status) {
    CodexRemoteAppServerOwnerStatus.stopped => true,
    _ => false,
  };
}

Future<CodexRemoteAppServerOwnerSnapshot> _waitForOwnerReady({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required String ownerId,
  required String workspaceDir,
  required CodexSshProcessBootstrap sshBootstrap,
}) async {
  CodexRemoteAppServerOwnerSnapshot? lastSnapshot;
  for (var attempt = 0; attempt < 20; attempt += 1) {
    lastSnapshot =
        await CodexSshRemoteAppServerOwnerInspector(
          sshBootstrap: sshBootstrap,
        ).inspectOwner(
          profile: profile,
          secrets: secrets,
          ownerId: ownerId,
          workspaceDir: workspaceDir,
        );
    if (lastSnapshot.status == CodexRemoteAppServerOwnerStatus.running) {
      return lastSnapshot;
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
  if (lastSnapshot != null) {
    return lastSnapshot;
  }
  return CodexSshRemoteAppServerOwnerInspector(
    sshBootstrap: sshBootstrap,
  ).inspectOwner(
    profile: profile,
    secrets: secrets,
    ownerId: ownerId,
    workspaceDir: workspaceDir,
  );
}

Future<CodexRemoteAppServerOwnerSnapshot> _waitForOwnerStopped({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required String ownerId,
  required String workspaceDir,
  required CodexSshProcessBootstrap sshBootstrap,
}) async {
  CodexRemoteAppServerOwnerSnapshot? lastSnapshot;
  for (var attempt = 0; attempt < 10; attempt += 1) {
    lastSnapshot =
        await CodexSshRemoteAppServerOwnerInspector(
          sshBootstrap: sshBootstrap,
        ).inspectOwner(
          profile: profile,
          secrets: secrets,
          ownerId: ownerId,
          workspaceDir: workspaceDir,
        );
    if (lastSnapshot.status == CodexRemoteAppServerOwnerStatus.missing ||
        lastSnapshot.status == CodexRemoteAppServerOwnerStatus.stopped) {
      return lastSnapshot;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  if (lastSnapshot != null) {
    return lastSnapshot;
  }
  return CodexSshRemoteAppServerOwnerInspector(
    sshBootstrap: sshBootstrap,
  ).inspectOwner(
    profile: profile,
    secrets: secrets,
    ownerId: ownerId,
    workspaceDir: workspaceDir,
  );
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
