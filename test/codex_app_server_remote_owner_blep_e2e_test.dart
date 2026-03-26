import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_connection_scoped_transport.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart';

final _BlepSshE2eConfig _blepSshE2eConfig = _resolveBlepSshE2eConfig();

void main() {
  test(
    'optional real SSH blep smoke test starts the managed remote server and attaches',
    () async {
      final config = _blepSshE2eConfig;
      final profile = config.profile!;
      final secrets = config.secrets!;
      const ownerId = 'blep-e2e-start';

      final ownerControl = CodexSshRemoteAppServerOwnerControl(
        readyPollAttempts: 80,
        readyPollDelay: const Duration(milliseconds: 250),
        stopPollAttempts: 30,
        stopPollDelay: const Duration(milliseconds: 150),
      );

      await ownerControl.stopOwner(
        profile: profile,
        secrets: secrets,
        ownerId: ownerId,
        workspaceDir: profile.workspaceDir,
      );
      addTearDown(() async {
        await ownerControl.stopOwner(
          profile: profile,
          secrets: secrets,
          ownerId: ownerId,
          workspaceDir: profile.workspaceDir,
        );
      });

      final capabilities = await ownerControl.probeHostCapabilities(
        profile: profile,
        secrets: secrets,
      );
      if (!capabilities.supportsContinuity) {
        fail(
          'blep host does not support continuity. '
          'issues=${capabilities.issues} detail=${capabilities.detail}',
        );
      }

      final started = await ownerControl.startOwner(
        profile: profile,
        secrets: secrets,
        ownerId: ownerId,
        workspaceDir: profile.workspaceDir,
      );
      if (!started.isConnectable) {
        fail(
          'blep remote owner did not become connectable. '
          'status=${started.status} detail=${started.detail} endpoint=${started.endpoint?.host}:${started.endpoint?.port}',
        );
      }

      final client = CodexAppServerClient(
        transportOpener: buildConnectionScopedCodexAppServerTransportOpener(
          ownerId: ownerId,
        ),
      );
      addTearDown(client.dispose);

      await client.connect(profile: profile, secrets: secrets);

      expect(client.isConnected, isTrue);

      await client.disconnect();

      final stopped = await ownerControl.stopOwner(
        profile: profile,
        secrets: secrets,
        ownerId: ownerId,
        workspaceDir: profile.workspaceDir,
      );
      expect(
        stopped.status,
        anyOf(
          CodexRemoteAppServerOwnerStatus.missing,
          CodexRemoteAppServerOwnerStatus.stopped,
        ),
      );
    },
    skip: _blepSshE2eConfig.skipReason ?? false,
    timeout: Timeout.factor(4),
  );
}

final class _BlepSshE2eConfig {
  const _BlepSshE2eConfig({
    this.skipReason,
    this.profile,
    this.secrets,
    this.identityFilePath,
  });

  final String? skipReason;
  final ConnectionProfile? profile;
  final ConnectionSecrets? secrets;
  final String? identityFilePath;
}

_BlepSshE2eConfig _resolveBlepSshE2eConfig() {
  if (!_runtimeFlagEnabled('POCKET_RELAY_RUN_REAL_REMOTE_SMOKE')) {
    return const _BlepSshE2eConfig(
      skipReason:
          'Set POCKET_RELAY_RUN_REAL_REMOTE_SMOKE=1 to run the real SSH smoke test.',
    );
  }

  final resolved = _resolveSshAlias('blep');
  if (resolved == null) {
    return const _BlepSshE2eConfig(
      skipReason: 'SSH alias `blep` is not configured.',
    );
  }

  final hostname = resolved['hostname']?.trim() ?? '';
  final username = resolved['user']?.trim() ?? '';
  final port = int.tryParse((resolved['port'] ?? '').trim());
  final identityFile = _expandHomePath((resolved['identityfile'] ?? '').trim());
  if (hostname.isEmpty || hostname == 'blep') {
    return const _BlepSshE2eConfig(
      skipReason: 'SSH alias `blep` did not resolve to a concrete host.',
    );
  }
  if (username.isEmpty || port == null) {
    return const _BlepSshE2eConfig(
      skipReason: 'SSH alias `blep` did not resolve to a usable user/port.',
    );
  }
  if (identityFile.isEmpty || !File(identityFile).existsSync()) {
    return const _BlepSshE2eConfig(
      skipReason:
          'SSH alias `blep` did not resolve to a readable identity file.',
    );
  }

  final privateKeyPem = File(identityFile).readAsStringSync().trim();
  if (privateKeyPem.isEmpty) {
    return const _BlepSshE2eConfig(
      skipReason: 'Resolved SSH identity file for `blep` was empty.',
    );
  }

  final hostFingerprint = _readEd25519Fingerprint(
    hostname: hostname,
    port: port,
  );
  if (hostFingerprint == null || hostFingerprint.isEmpty) {
    return const _BlepSshE2eConfig(
      skipReason: 'Could not resolve an ED25519 host fingerprint for `blep`.',
    );
  }

  final workspaceDir =
      (_runtimeSetting('POCKET_RELAY_REAL_SSH_BLEP_WORKSPACE_DIR').isNotEmpty
              ? _runtimeSetting('POCKET_RELAY_REAL_SSH_BLEP_WORKSPACE_DIR')
              : '/home/$username')
          .trim();
  final codexPath =
      (_runtimeSetting('POCKET_RELAY_REAL_SSH_BLEP_CODEX_PATH').isNotEmpty
              ? _runtimeSetting('POCKET_RELAY_REAL_SSH_BLEP_CODEX_PATH')
              : 'codex')
          .trim();

  return _BlepSshE2eConfig(
    profile: ConnectionProfile.defaults().copyWith(
      label: 'blep',
      host: hostname,
      port: port,
      username: username,
      workspaceDir: workspaceDir,
      codexPath: codexPath,
      authMode: AuthMode.privateKey,
      hostFingerprint: hostFingerprint,
      connectionMode: ConnectionMode.remote,
    ),
    secrets: ConnectionSecrets(
      privateKeyPem: privateKeyPem,
      privateKeyPassphrase: _runtimeSetting(
        'POCKET_RELAY_REAL_SSH_BLEP_PRIVATE_KEY_PASSPHRASE',
      ),
    ),
    identityFilePath: identityFile,
  );
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

String _shellQuote(String value) {
  return "'${value.replaceAll("'", r"'\''")}'";
}

bool _envFlagEnabled(String name) {
  final value = _runtimeSetting(name).trim().toLowerCase();
  return value == '1' || value == 'true' || value == 'yes' || value == 'on';
}

bool _runtimeFlagEnabled(String name) => _envFlagEnabled(name);

String _runtimeSetting(String name) {
  final environmentValue = Platform.environment[name]?.trim();
  if (environmentValue != null && environmentValue.isNotEmpty) {
    return environmentValue;
  }

  return switch (name) {
    'POCKET_RELAY_RUN_REAL_REMOTE_SMOKE' => const String.fromEnvironment(
      'POCKET_RELAY_RUN_REAL_REMOTE_SMOKE',
    ).trim(),
    'POCKET_RELAY_REAL_SSH_BLEP_WORKSPACE_DIR' => const String.fromEnvironment(
      'POCKET_RELAY_REAL_SSH_BLEP_WORKSPACE_DIR',
    ).trim(),
    'POCKET_RELAY_REAL_SSH_BLEP_CODEX_PATH' => const String.fromEnvironment(
      'POCKET_RELAY_REAL_SSH_BLEP_CODEX_PATH',
    ).trim(),
    'POCKET_RELAY_REAL_SSH_BLEP_PRIVATE_KEY_PASSPHRASE' =>
      const String.fromEnvironment(
        'POCKET_RELAY_REAL_SSH_BLEP_PRIVATE_KEY_PASSPHRASE',
      ).trim(),
    _ => '',
  };
}
