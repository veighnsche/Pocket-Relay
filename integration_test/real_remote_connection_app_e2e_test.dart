import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pocket_relay/src/app/pocket_relay_app.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_desktop_shell.dart';

final _RealRemoteAppE2eConfig _realRemoteAppE2eConfig =
    _resolveRealRemoteAppE2eConfig();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'optional real-host app E2E starts the managed server and opens a live remote lane through the production UI',
    (tester) async {
      final config = _realRemoteAppE2eConfig;
      final connection = config.connection!;
      final profile = connection.profile;
      final secrets = connection.secrets;
      final connectionId = connection.id;
      final ownerControl = const CodexSshRemoteAppServerOwnerControl(
        readyPollAttempts: 80,
        readyPollDelay: Duration(milliseconds: 250),
        stopPollAttempts: 30,
        stopPollDelay: Duration(milliseconds: 150),
      );

      await _bestEffortStopOwner(
        ownerControl,
        profile: profile,
        secrets: secrets,
        ownerId: connectionId,
        workspaceDir: profile.workspaceDir,
      );

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await _bestEffortStopOwner(
          ownerControl,
          profile: profile,
          secrets: secrets,
          ownerId: connectionId,
          workspaceDir: profile.workspaceDir,
        );
      });

      await tester.pumpWidget(
        PocketRelayApp(
          connectionRepository: MemoryCodexConnectionRepository(
            initialConnections: <SavedConnection>[connection],
          ),
          modelCatalogStore: MemoryConnectionModelCatalogStore(),
          recoveryStore: MemoryConnectionWorkspaceRecoveryStore(),
          platformPolicy: PocketPlatformPolicy.resolve(
            platform: TargetPlatform.macOS,
            isWeb: false,
          ),
        ),
      );

      await _pumpUntilFound(
        tester,
        find.byType(ConnectionWorkspaceDesktopShell),
        description: 'desktop workspace shell',
      );

      final shell = tester.widget<ConnectionWorkspaceDesktopShell>(
        find.byType(ConnectionWorkspaceDesktopShell),
      );
      final workspaceController = shell.workspaceController;

      await tester.tap(find.byKey(const ValueKey('desktop_saved_connections')));
      await tester.pumpAndSettle();

      await _pumpUntilFound(
        tester,
        find.byKey(ValueKey<String>('saved_connection_$connectionId')),
        description: 'saved connection row for $connectionId',
      );

      await _pumpUntilCondition(
        tester,
        description: 'settled remote runtime probe',
        condition: () {
          final runtime = workspaceController.state.remoteRuntimeFor(
            connectionId,
          );
          if (runtime == null) {
            return false;
          }
          return runtime.hostCapability.status !=
                  ConnectionRemoteHostCapabilityStatus.unknown &&
              runtime.hostCapability.status !=
                  ConnectionRemoteHostCapabilityStatus.checking;
        },
        timeout: const Duration(seconds: 30),
        failureDetail: () => _describeWorkspaceState(
          workspaceController,
          connectionId: connectionId,
        ),
      );

      final initialRuntime = workspaceController.state.remoteRuntimeFor(
        connectionId,
      )!;
      if (!initialRuntime.hostCapability.isSupported) {
        fail(
          'Remote host is not ready for continuity.\n'
          '${_describeWorkspaceState(workspaceController, connectionId: connectionId)}',
        );
      }

      final startServerButton = find.byKey(
        ValueKey<String>('saved_connection_remote_server_start_$connectionId'),
      );
      await _pumpUntilCondition(
        tester,
        description: 'start server action',
        condition: () => startServerButton.evaluate().isNotEmpty,
        timeout: const Duration(seconds: 30),
        failureDetail: () => _describeWorkspaceState(
          workspaceController,
          connectionId: connectionId,
        ),
      );

      await tester.ensureVisible(startServerButton);
      await tester.tap(startServerButton);
      await tester.pump();

      await _pumpUntilCondition(
        tester,
        description: 'managed remote server running',
        condition: () =>
            workspaceController.state
                .remoteRuntimeFor(connectionId)
                ?.server
                .isConnectable ==
            true,
        timeout: const Duration(minutes: 1),
        failureDetail: () => _describeWorkspaceState(
          workspaceController,
          connectionId: connectionId,
          tester: tester,
        ),
      );

      final openLaneButton = find.byKey(
        ValueKey<String>('open_connection_$connectionId'),
      );
      await tester.ensureVisible(openLaneButton);
      await tester.tap(openLaneButton);
      await tester.pumpAndSettle();

      await _pumpUntilCondition(
        tester,
        description: 'selected live lane',
        condition: () =>
            workspaceController.state.isShowingLiveLane &&
            workspaceController.state.selectedConnectionId == connectionId &&
            workspaceController.bindingForConnectionId(connectionId) != null,
        timeout: const Duration(seconds: 15),
        failureDetail: () => _describeWorkspaceState(
          workspaceController,
          connectionId: connectionId,
        ),
      );

      final laneBinding = workspaceController.bindingForConnectionId(
        connectionId,
      )!;
      final sessionController = laneBinding.sessionController;
      const prompt = 'Reply with exactly: ok';

      final composerInput = find.byKey(const ValueKey('composer_input'));
      final sendButton = find.byKey(const ValueKey('send'));
      await _pumpUntilFound(
        tester,
        composerInput,
        description: 'chat composer input',
      );
      await tester.enterText(composerInput, prompt);
      await tester.pump();

      await tester.ensureVisible(sendButton);
      await tester.tap(sendButton);
      await tester.pump();

      await _pumpUntilCondition(
        tester,
        description: 'connected lane with active thread',
        condition: () {
          final sessionState = sessionController.sessionState;
          final threadId =
              sessionState.currentThreadId?.trim() ??
              sessionState.rootThreadId?.trim() ??
              '';
          return laneBinding.appServerClient.isConnected && threadId.isNotEmpty;
        },
        timeout: const Duration(minutes: 2),
        failureDetail: () => _describeWorkspaceState(
          workspaceController,
          connectionId: connectionId,
          tester: tester,
        ),
      );

      final sessionThreadId =
          sessionController.sessionState.currentThreadId?.trim().isNotEmpty ==
              true
          ? sessionController.sessionState.currentThreadId!.trim()
          : sessionController.sessionState.rootThreadId!.trim();

      expect(laneBinding.appServerClient.isConnected, isTrue);
      expect(sessionThreadId, isNotEmpty);
      expect(sessionController.sessionState.connectionStatus, isNotNull);

      final thread = await laneBinding.appServerClient.readThread(
        threadId: sessionThreadId,
      );
      expect(thread.id, sessionThreadId);
    },
    skip: _realRemoteAppE2eConfig.skipReason != null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> _bestEffortStopOwner(
  CodexSshRemoteAppServerOwnerControl ownerControl, {
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required String ownerId,
  required String workspaceDir,
}) async {
  try {
    await ownerControl.stopOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    );
  } catch (_) {
    // Best-effort cleanup only.
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  required String description,
  Duration timeout = const Duration(seconds: 30),
}) {
  return _pumpUntilCondition(
    tester,
    description: description,
    timeout: timeout,
    condition: () => finder.evaluate().isNotEmpty,
  );
}

Future<void> _pumpUntilCondition(
  WidgetTester tester, {
  required String description,
  required bool Function() condition,
  Duration timeout = const Duration(seconds: 30),
  String Function()? failureDetail,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 250));
  }

  final detail = failureDetail?.call();
  fail(
    detail == null || detail.trim().isEmpty
        ? 'Timed out waiting for $description.'
        : 'Timed out waiting for $description.\n$detail',
  );
}

String _describeWorkspaceState(
  ConnectionWorkspaceController workspaceController, {
  required String connectionId,
  WidgetTester? tester,
}) {
  final state = workspaceController.state;
  final runtime = state.remoteRuntimeFor(connectionId);
  final binding = workspaceController.bindingForConnectionId(connectionId);
  final sessionState = binding?.sessionController.sessionState;
  final snackBarTexts = tester == null
      ? const <String>[]
      : _snackBarTexts(tester);

  return [
    'selectedConnectionId=${state.selectedConnectionId}',
    'viewport=${state.viewport}',
    'liveConnectionIds=${state.liveConnectionIds}',
    'remoteHostCapability=${runtime?.hostCapability.status}',
    'remoteHostDetail=${runtime?.hostCapability.detail}',
    'remoteServerStatus=${runtime?.server.status}',
    'remoteServerDetail=${runtime?.server.detail}',
    'remoteServerPort=${runtime?.server.port}',
    'appServerConnected=${binding?.appServerClient.isConnected}',
    'sessionConnectionStatus=${sessionState?.connectionStatus}',
    'sessionThreadId=${sessionState?.currentThreadId}',
    'snackBars=${snackBarTexts.join(' | ')}',
  ].join('\n');
}

List<String> _snackBarTexts(WidgetTester tester) {
  return find
      .descendant(of: find.byType(SnackBar), matching: find.byType(Text))
      .evaluate()
      .map<String>((element) => ((element.widget as Text).data ?? '').trim())
      .where((text) => text.isNotEmpty)
      .toList(growable: false);
}

final class _RealRemoteAppE2eConfig {
  const _RealRemoteAppE2eConfig({this.skipReason, this.connection});

  final String? skipReason;
  final SavedConnection? connection;
}

_RealRemoteAppE2eConfig _resolveRealRemoteAppE2eConfig() {
  if (!_runtimeFlagEnabled('POCKET_RELAY_RUN_REAL_REMOTE_APP_E2E')) {
    return const _RealRemoteAppE2eConfig(
      skipReason:
          'Set POCKET_RELAY_RUN_REAL_REMOTE_APP_E2E=1 to run the real-host app E2E.',
    );
  }

  final alias = _firstNonEmpty(
    _runtimeSetting('POCKET_RELAY_REAL_REMOTE_SSH_ALIAS'),
    'blep',
  );
  final hasDirectConnectionSettings =
      _runtimeSetting('POCKET_RELAY_REAL_REMOTE_HOST').isNotEmpty &&
      _runtimeSetting('POCKET_RELAY_REAL_REMOTE_USERNAME').isNotEmpty &&
      _runtimeSetting('POCKET_RELAY_REAL_REMOTE_PORT').isNotEmpty &&
      _runtimeSetting('POCKET_RELAY_REAL_REMOTE_PRIVATE_KEY_FILE').isNotEmpty;
  final resolvedAlias = hasDirectConnectionSettings
      ? null
      : _resolveSshAlias(alias);
  if (!hasDirectConnectionSettings && resolvedAlias == null) {
    return _RealRemoteAppE2eConfig(
      skipReason: 'SSH alias `$alias` is not configured.',
    );
  }

  final hostname = _firstNonEmpty(
    _runtimeSetting('POCKET_RELAY_REAL_REMOTE_HOST'),
    resolvedAlias?['hostname'],
  );
  final username = _firstNonEmpty(
    _runtimeSetting('POCKET_RELAY_REAL_REMOTE_USERNAME'),
    resolvedAlias?['user'],
  );
  final port = int.tryParse(
    _firstNonEmpty(
      _runtimeSetting('POCKET_RELAY_REAL_REMOTE_PORT'),
      resolvedAlias?['port'],
    ),
  );
  final identityFile = _expandHomePath(
    _firstNonEmpty(
      _runtimeSetting('POCKET_RELAY_REAL_REMOTE_PRIVATE_KEY_FILE'),
      resolvedAlias?['identityfile'],
    ),
  );
  final privateKeyPem = _resolvePrivateKeyPem(identityFile);

  if (hostname.isEmpty || username.isEmpty || port == null) {
    return const _RealRemoteAppE2eConfig(
      skipReason:
          'The real-host E2E could not resolve a usable host, user, and port.',
    );
  }
  if (privateKeyPem.isEmpty) {
    return const _RealRemoteAppE2eConfig(
      skipReason:
          'The real-host E2E could not resolve readable private key material.',
    );
  }

  final hostFingerprint = _firstNonEmpty(
    _runtimeSetting('POCKET_RELAY_REAL_REMOTE_HOST_FINGERPRINT'),
    _readEd25519Fingerprint(hostname: hostname, port: port),
  );
  if (hostFingerprint.isEmpty) {
    return const _RealRemoteAppE2eConfig(
      skipReason:
          'The real-host E2E could not resolve an ED25519 host fingerprint.',
    );
  }

  final workspaceDir = _firstNonEmpty(
    _runtimeSetting('POCKET_RELAY_REAL_REMOTE_WORKSPACE_DIR'),
    _probeRemoteWorkspaceDir(alias, username),
  );
  if (workspaceDir.isEmpty) {
    return const _RealRemoteAppE2eConfig(
      skipReason:
          'The real-host E2E could not resolve a usable remote workspace directory.',
    );
  }

  final codexPath = _firstNonEmpty(
    _runtimeSetting('POCKET_RELAY_REAL_REMOTE_CODEX_PATH'),
    _probeRemoteCodexPath(alias),
  );
  if (codexPath.isEmpty) {
    return const _RealRemoteAppE2eConfig(
      skipReason:
          'The real-host E2E could not resolve the remote codex executable.',
    );
  }

  final connectionId =
      'conn_real_remote_app_e2e_${DateTime.now().microsecondsSinceEpoch}';
  return _RealRemoteAppE2eConfig(
    connection: SavedConnection(
      id: connectionId,
      profile: ConnectionProfile.defaults().copyWith(
        label: 'Real Remote E2E',
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
          'POCKET_RELAY_REAL_REMOTE_PRIVATE_KEY_PASSPHRASE',
        ),
      ),
    ),
  );
}

String _probeRemoteWorkspaceDir(String alias, String username) {
  final override = _runtimeSetting('POCKET_RELAY_REAL_REMOTE_WORKSPACE_DIR');
  final candidates = <String>[
    if (override.isNotEmpty) override,
    '/home/$username/Projects/Pocket-Relay',
    '/home/$username/Projects',
    '/home/$username',
  ];
  final candidateList = candidates
      .map(_shellQuote)
      .map((candidate) => '  $candidate')
      .join(' \\\n');
  final command =
      '''
for candidate in \\
$candidateList
do
  if [ -d "\$candidate" ]; then
    printf '%s\\n' "\$candidate"
    exit 0
  fi
done
exit 1
''';
  return _runSshCommand(alias, command);
}

String _probeRemoteCodexPath(String alias) {
  return _runSshCommand(alias, 'command -v codex');
}

String _runSshCommand(String alias, String command) {
  final result = Process.runSync('/bin/bash', <String>[
    '-lc',
    "ssh -o BatchMode=yes ${_shellQuote(alias)} ${_shellQuote(command)}",
  ]);
  if (result.exitCode != 0) {
    return '';
  }
  return (result.stdout as String)
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
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

String _resolvePrivateKeyPem(String identityFile) {
  final encodedPem = _runtimeSetting(
    'POCKET_RELAY_REAL_REMOTE_PRIVATE_KEY_PEM_B64',
  );
  if (encodedPem.isNotEmpty) {
    try {
      return utf8.decode(base64.decode(encodedPem)).trim();
    } catch (_) {
      return '';
    }
  }

  final inlinePem = _runtimeSetting('POCKET_RELAY_REAL_REMOTE_PRIVATE_KEY_PEM');
  if (inlinePem.isNotEmpty) {
    return inlinePem.trim();
  }

  if (identityFile.isEmpty || !File(identityFile).existsSync()) {
    return '';
  }

  try {
    return File(identityFile).readAsStringSync().trim();
  } catch (_) {
    return '';
  }
}

String _readEd25519Fingerprint({required String hostname, required int port}) {
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
    return '';
  }
  return (result.stdout as String)
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
}

String _firstNonEmpty(String? first, String? second) {
  final firstValue = first?.trim() ?? '';
  if (firstValue.isNotEmpty) {
    return firstValue;
  }
  return second?.trim() ?? '';
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
    'POCKET_RELAY_RUN_REAL_REMOTE_APP_E2E' => const String.fromEnvironment(
      'POCKET_RELAY_RUN_REAL_REMOTE_APP_E2E',
    ).trim(),
    'POCKET_RELAY_REAL_REMOTE_SSH_ALIAS' => const String.fromEnvironment(
      'POCKET_RELAY_REAL_REMOTE_SSH_ALIAS',
    ).trim(),
    'POCKET_RELAY_REAL_REMOTE_HOST' => const String.fromEnvironment(
      'POCKET_RELAY_REAL_REMOTE_HOST',
    ).trim(),
    'POCKET_RELAY_REAL_REMOTE_USERNAME' => const String.fromEnvironment(
      'POCKET_RELAY_REAL_REMOTE_USERNAME',
    ).trim(),
    'POCKET_RELAY_REAL_REMOTE_PORT' => const String.fromEnvironment(
      'POCKET_RELAY_REAL_REMOTE_PORT',
    ).trim(),
    'POCKET_RELAY_REAL_REMOTE_PRIVATE_KEY_FILE' => const String.fromEnvironment(
      'POCKET_RELAY_REAL_REMOTE_PRIVATE_KEY_FILE',
    ).trim(),
    'POCKET_RELAY_REAL_REMOTE_PRIVATE_KEY_PEM' => const String.fromEnvironment(
      'POCKET_RELAY_REAL_REMOTE_PRIVATE_KEY_PEM',
    ).trim(),
    'POCKET_RELAY_REAL_REMOTE_PRIVATE_KEY_PEM_B64' =>
      const String.fromEnvironment(
        'POCKET_RELAY_REAL_REMOTE_PRIVATE_KEY_PEM_B64',
      ).trim(),
    'POCKET_RELAY_REAL_REMOTE_PRIVATE_KEY_PASSPHRASE' =>
      const String.fromEnvironment(
        'POCKET_RELAY_REAL_REMOTE_PRIVATE_KEY_PASSPHRASE',
      ).trim(),
    'POCKET_RELAY_REAL_REMOTE_HOST_FINGERPRINT' => const String.fromEnvironment(
      'POCKET_RELAY_REAL_REMOTE_HOST_FINGERPRINT',
    ).trim(),
    'POCKET_RELAY_REAL_REMOTE_WORKSPACE_DIR' => const String.fromEnvironment(
      'POCKET_RELAY_REAL_REMOTE_WORKSPACE_DIR',
    ).trim(),
    'POCKET_RELAY_REAL_REMOTE_CODEX_PATH' => const String.fromEnvironment(
      'POCKET_RELAY_REAL_REMOTE_CODEX_PATH',
    ).trim(),
    _ => '',
  };
}
