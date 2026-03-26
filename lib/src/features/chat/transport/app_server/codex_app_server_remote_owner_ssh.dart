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
    this.readyPollAttempts = 40,
    this.readyPollDelay = const Duration(milliseconds: 250),
    this.stopPollAttempts = 10,
    this.stopPollDelay = const Duration(milliseconds: 100),
  });

  final CodexSshProcessBootstrap sshBootstrap;
  final int readyPollAttempts;
  final Duration readyPollDelay;
  final int stopPollAttempts;
  final Duration stopPollDelay;

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
        attempts: readyPollAttempts,
        delay: readyPollDelay,
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
      attempts: stopPollAttempts,
      delay: stopPollDelay,
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
${_buildRequestedCodexShellFunctions(requestedCodex: profile.codexPath)}
tmux_status=1
if command -v tmux >/dev/null 2>&1; then
  tmux_status=0
fi
workspace_status=1
if cd ${shellEscape(profile.workspaceDir.trim())} >/dev/null 2>&1; then
  workspace_status=0
fi
codex_status=1
if [ "\$workspace_status" = "0" ] && run_requested_codex app-server --help >/dev/null 2>&1; then
  codex_status=0
fi
printf '__pocket_relay_capabilities__ tmux=%s workspace=%s codex=%s\\n' "\$tmux_status" "\$workspace_status" "\$codex_status"
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
  return 'pocket-relay-$suffix';
}

String buildPocketRelayRemoteOwnerLogFilePath({required String sessionName}) {
  final normalized = sessionName.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(sessionName, 'sessionName', 'must not be empty');
  }
  return '/tmp/$normalized.log';
}

String _buildPocketRelayRemoteOwnerLogShellFunctions() {
  return '''
resolve_pocket_relay_log_dir() {
  if [ -n "\${XDG_RUNTIME_DIR-}" ] && [ -d "\${XDG_RUNTIME_DIR-}" ] && [ -w "\${XDG_RUNTIME_DIR-}" ]; then
    printf '%s' "\$XDG_RUNTIME_DIR/pocket-relay"
    return 0
  fi

  if [ -n "\${HOME-}" ] && [ -d "\${HOME-}" ]; then
    cache_root="\$HOME/.cache"
    if { [ -d "\$cache_root" ] && [ -w "\$cache_root" ]; } || { [ ! -e "\$cache_root" ] && [ -w "\$HOME" ]; }; then
      printf '%s' "\$cache_root/pocket-relay"
      return 0
    fi
  fi

  uid_suffix=\$(id -u 2>/dev/null | tr -cd '0-9')
  if [ -z "\$uid_suffix" ]; then
    uid_suffix=unknown
  fi
  printf '%s' "/tmp/pocket-relay-\$uid_suffix"
}

resolve_pocket_relay_log_file() {
  session_name="\$1"
  printf '%s/%s.log' "\$(resolve_pocket_relay_log_dir)" "\$session_name"
}

ensure_pocket_relay_log_dir() {
  log_dir=\$(resolve_pocket_relay_log_dir)
  previous_umask=\$(umask)
  if [ -z "\$previous_umask" ]; then
    previous_umask=022
  fi
  umask 077
  if mkdir -p "\$log_dir"; then
    status=0
  else
    status=\$?
  fi
  chmod 700 "\$log_dir" 2>/dev/null || true
  umask "\$previous_umask"
  return "\$status"
}
''';
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

String _buildRequestedCodexShellFunctions({required String requestedCodex}) {
  final normalizedRequestedCodex = requestedCodex.trim();
  return '''
${_buildRemoteBinaryPathPrelude()}
requested_codex=${shellEscape(normalizedRequestedCodex)}

requested_codex_requires_eval() {
  [[ "\$requested_codex" == *[[:space:]]* || "\$requested_codex" == */* ]]
}

resolve_requested_codex() {
  if [ -z "\$requested_codex" ]; then
    return 1
  fi

  if requested_codex_requires_eval; then
    printf '%s' "\$requested_codex"
    return 0
  fi

  if command -v "\$requested_codex" >/dev/null 2>&1; then
    command -v "\$requested_codex"
    return 0
  fi

  for candidate in "\$HOME/.local/bin/\$requested_codex" "\$HOME/bin/\$requested_codex" "/usr/local/bin/\$requested_codex" "/opt/homebrew/bin/\$requested_codex" "/usr/bin/\$requested_codex" "/bin/\$requested_codex"; do
    if [ -x "\$candidate" ]; then
      printf '%s' "\$candidate"
      return 0
    fi
  done

  return 1
}

run_requested_codex() {
  resolved_codex=\$(resolve_requested_codex) || return 127
  if requested_codex_requires_eval; then
    quoted_args=
    for arg in "\$@"; do
      printf -v quoted_args '%s %q' "\$quoted_args" "\$arg"
    done
    eval "\$resolved_codex\$quoted_args"
    return \$?
  fi
  "\$resolved_codex" "\$@"
}
''';
}

String _buildRemoteBinaryPathPrelude() {
  return '''
PATH="\$HOME/.local/bin:\$HOME/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:\$PATH"
export PATH
''';
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
${_buildRemoteBinaryPathPrelude()}
${_buildPocketRelayRemoteOwnerLogShellFunctions()}
log_file=\$(resolve_pocket_relay_log_file "\$session_name")

encode_log_tail() {
  if [ ! -f "\$log_file" ]; then
    return 0
  fi
  tail -n 40 "\$log_file" 2>/dev/null | base64 | tr -d '\\n'
}

print_result() {
  status="\$1"
  pid="\$2"
  host="\$3"
  port="\$4"
  detail="\$5"
  if [ "\$status" = "running" ]; then
    log_b64=
  else
    log_b64=\$(encode_log_tail)
  fi
  printf '__pocket_relay_owner__ status=%s pid=%s host=%s port=%s detail=%s log_b64=%s\\n' "\$status" "\$pid" "\$host" "\$port" "\$detail" "\$log_b64"
}

resolved_process_pid=
resolved_process_args=

resolve_app_server_process() {
  current_pid="\$1"
  depth=0

  while [ -n "\$current_pid" ] && [ "\$current_pid" != "0" ] && [ "\$depth" -lt 6 ]; do
    current_args=\$(ps -p "\$current_pid" -o args= 2>/dev/null | head -n 1)
    if [ -z "\$current_args" ]; then
      return 1
    fi

    if [[ "\$current_args" =~ app-server ]]; then
      resolved_process_pid="\$current_pid"
      resolved_process_args="\$current_args"
      return 0
    fi

    child_pids=\$(ps -o pid= --ppid "\$current_pid" 2>/dev/null | awk 'NF { gsub(/^[[:space:]]+|[[:space:]]+\$/, ""); print }')
    child_count=\$(printf '%s\\n' "\$child_pids" | sed '/^\$/d' | wc -l | tr -d '[:space:]')
    if [ "\$child_count" != "1" ]; then
      return 1
    fi

    current_pid=\$(printf '%s\\n' "\$child_pids" | sed -n '1p')
    depth=\$((depth + 1))
  done

  return 1
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

if [ -n "\$expected_workspace" ]; then
  if ! cd "\$expected_workspace" >/dev/null 2>&1; then
    print_result unhealthy "\$pane_pid" "" "" expected_workspace_unavailable
    exit 0
  fi
  expected_workspace_real=\$(pwd -P)
  pane_path_real=\$pane_path
  if [ -n "\$pane_path" ] && cd "\$pane_path" >/dev/null 2>&1; then
    pane_path_real=\$(pwd -P)
  fi
  if [ "\$pane_path_real" != "\$expected_workspace_real" ]; then
    print_result unhealthy "\$pane_pid" "" "" workspace_mismatch
    exit 0
  fi
fi

if ! resolve_app_server_process "\$pane_pid"; then
  print_result stopped "\$pane_pid" "" "" process_missing
  exit 0
fi

pane_pid="\$resolved_process_pid"
process_args="\$resolved_process_args"

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
  if [[ "\$response" == HTTP/*" 200"* ]]; then
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
  final tmuxCommand =
      '''
${_buildRequestedCodexShellFunctions(requestedCodex: codexPath)}
${_buildPocketRelayRemoteOwnerLogShellFunctions()}
ensure_pocket_relay_log_dir
log_file=\$(resolve_pocket_relay_log_file ${shellEscape(sessionName)})
rm -f "\$log_file"
run_requested_codex app-server --listen ws://127.0.0.1:$port >>"\$log_file" 2>&1
status=\$?
echo "pocket-relay: codex app-server exited with status \$status" >>"\$log_file"
exit "\$status"
''';
  final paneCommand = 'exec bash -lc ${shellEscape(tmuxCommand)}';
  final command =
      '''
set -euo pipefail
session_name=${shellEscape(sessionName)}
workspace_dir=${shellEscape(workspaceDir.trim())}
${_buildRemoteBinaryPathPrelude()}

if ! command -v tmux >/dev/null 2>&1; then
  echo 'tmux is not available on the remote host.' >&2
  exit 1
fi

if tmux has-session -t "\$session_name" 2>/dev/null; then
  echo "Managed tmux owner already exists: \$session_name" >&2
  exit 2
fi

pane_id=\$(tmux new-session -d -P -F '#{pane_id}' -s "\$session_name" -c "\$workspace_dir")
tmux respawn-pane -k -t "\$pane_id" ${shellEscape(paneCommand)}
''';
  return 'bash -lc ${shellEscape(command)}';
}

@visibleForTesting
String buildSshRemoteOwnerStopCommand({required String sessionName}) {
  final command =
      '''
session_name=${shellEscape(sessionName)}
${_buildRemoteBinaryPathPrelude()}
${_buildPocketRelayRemoteOwnerLogShellFunctions()}
log_file=\$(resolve_pocket_relay_log_file "\$session_name")
if ! command -v tmux >/dev/null 2>&1; then
  rm -f "\$log_file"
  exit 0
fi
if tmux has-session -t "\$session_name" 2>/dev/null; then
  tmux kill-session -t "\$session_name"
fi
rm -f "\$log_file"
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
  final logDetail = _decodedOwnerLog(fields['log_b64']);

  return CodexRemoteAppServerOwnerSnapshot(
    ownerId: ownerId,
    workspaceDir: workspaceDir,
    status: status,
    sessionName: sessionName,
    pid: pid,
    endpoint: host != null && host.isNotEmpty && port != null
        ? CodexRemoteAppServerEndpoint(host: host, port: port)
        : null,
    detail: _ownerDetailForCode(fields['detail'], logDetail: logDetail),
  );
}

CodexRemoteAppServerHostCapabilities _parseHostCapabilities({
  required String stdout,
  required String stderr,
  required int? exitCode,
}) {
  final match = RegExp(
    r'__pocket_relay_capabilities__\s+tmux=(\d+)\s+workspace=(\d+)\s+codex=(\d+)',
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
    issues.add(ConnectionRemoteHostCapabilityIssue.workspaceUnavailable);
  }
  if (match.group(3) != '0') {
    issues.add(ConnectionRemoteHostCapabilityIssue.codexMissing);
  }

  return CodexRemoteAppServerHostCapabilities(
    issues: issues,
    detail: issues.isEmpty
        ? 'Remote host supports continuity and can run the managed remote app-server.'
        : null,
  );
}

String? _ownerDetailForCode(String? code, {String? logDetail}) {
  final baseDetail = switch (code) {
    null || '' => null,
    'ready' => 'Managed remote app-server is ready.',
    'session_missing' =>
      'No managed remote app-server is running for this connection.',
    'pane_missing' =>
      'The managed tmux owner exists but has no live pane process.',
    'process_missing' =>
      'The managed tmux owner exists but the app-server process is not running.',
    'workspace_mismatch' =>
      'The managed tmux owner exists but points at a different workspace.',
    'expected_workspace_unavailable' =>
      'The configured workspace directory is not accessible on the remote host.',
    'listen_url_missing' =>
      'The managed tmux owner is not running a websocket app-server.',
    'ready_check_failed' =>
      'The managed remote app-server is running but did not pass its readiness check.',
    'tmux_unavailable' => 'tmux is not available on the remote host.',
    _ => code,
  };

  final normalizedLog = logDetail?.trim();
  if (normalizedLog == null || normalizedLog.isEmpty) {
    return baseDetail;
  }
  if (baseDetail == null || baseDetail.isEmpty) {
    return normalizedLog;
  }
  if (baseDetail.contains(normalizedLog)) {
    return baseDetail;
  }
  return '$baseDetail Underlying error: $normalizedLog';
}

String? _decodedOwnerLog(String? encodedLog) {
  final normalized = encodedLog?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }

  try {
    final decoded = utf8.decode(base64.decode(normalized));
    final lines = decoded
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return null;
    }
    return lines.join(' ');
  } catch (_) {
    return null;
  }
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
  required int attempts,
  required Duration delay,
}) async {
  CodexRemoteAppServerOwnerSnapshot? lastSnapshot;
  for (var attempt = 0; attempt < attempts; attempt += 1) {
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
    await Future<void>.delayed(delay);
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
  required int attempts,
  required Duration delay,
}) async {
  CodexRemoteAppServerOwnerSnapshot? lastSnapshot;
  for (var attempt = 0; attempt < attempts; attempt += 1) {
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
    await Future<void>.delayed(delay);
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
