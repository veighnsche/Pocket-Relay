import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart';

void main() {
  test('builds a capability probe command for a plain codex binary', () {
    final command = buildSshRemoteHostCapabilityProbeCommand(
      profile: _profile().copyWith(codexPath: 'codex'),
    );

    expect(
      command,
      contains(
        r'PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"',
      ),
    );
    expect(command, contains('command -v tmux'));
    expect(command, contains('run_requested_codex app-server --help'));
    expect(command, contains(r'$HOME/.local/bin/$requested_codex'));
    expect(command, contains('/workspace'));
  });

  test(
    'capability probe command executes successfully for a plain codex binary',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'pocket_relay_capability_probe_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final workspaceDir = Directory('${tempDir.path}/workspace')..createSync();
      final localBinDir = Directory('${tempDir.path}/.local/bin')
        ..createSync(recursive: true);
      final codexFile = File('${localBinDir.path}/codex');
      codexFile.writeAsStringSync('''
#!/bin/bash
if [ "\$1" = "app-server" ] && [ "\$2" = "--help" ]; then
  exit 0
fi
exit 1
''');
      await Process.run('/bin/chmod', <String>['+x', codexFile.path]);

      final command = buildSshRemoteHostCapabilityProbeCommand(
        profile: _profile().copyWith(
          codexPath: 'codex',
          workspaceDir: workspaceDir.path,
        ),
      );

      final result = await Process.run(
        '/bin/bash',
        <String>['-c', command],
        environment: <String, String>{
          'HOME': tempDir.path,
          'PATH': Platform.environment['PATH'] ?? '',
        },
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(
        result.stdout.toString(),
        contains('__pocket_relay_capabilities__ tmux='),
      );
    },
  );

  test(
    'builds a capability probe command for a launch command with spaces',
    () {
      final command = buildSshRemoteHostCapabilityProbeCommand(
        profile: _profile().copyWith(codexPath: 'just codex-mcp'),
      );

      expect(command, contains('just codex-mcp'));
      expect(command, contains('run_requested_codex app-server --help'));
    },
  );

  test(
    'probeHostCapabilities returns supported when tmux and codex are available',
    () async {
      final process = _FakeCodexAppServerProcess(
        stdoutLines: <String>[
          '__pocket_relay_capabilities__ tmux=0 workspace=0 codex=0',
        ],
      );
      final probe = CodexSshRemoteAppServerHostProbe(
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return _FakeSshBootstrapClient(process: process);
            },
      );

      final capabilities = await probe.probeHostCapabilities(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      );

      expect(capabilities.supportsContinuity, isTrue);
      expect(capabilities.issues, isEmpty);
    },
  );

  test(
    'probeHostCapabilities reports explicit missing tmux and codex issues',
    () async {
      final process = _FakeCodexAppServerProcess(
        stdoutLines: <String>[
          '__pocket_relay_capabilities__ tmux=1 workspace=0 codex=1',
        ],
      );
      final probe = CodexSshRemoteAppServerHostProbe(
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return _FakeSshBootstrapClient(process: process);
            },
      );

      final capabilities = await probe.probeHostCapabilities(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      );

      expect(capabilities.issues, <ConnectionRemoteHostCapabilityIssue>{
        ConnectionRemoteHostCapabilityIssue.tmuxMissing,
        ConnectionRemoteHostCapabilityIssue.codexMissing,
      });
    },
  );

  test(
    'probeHostCapabilities reports an unavailable workspace separately from codex availability',
    () async {
      final process = _FakeCodexAppServerProcess(
        stdoutLines: <String>[
          '__pocket_relay_capabilities__ tmux=0 workspace=1 codex=1',
        ],
      );
      final probe = CodexSshRemoteAppServerHostProbe(
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return _FakeSshBootstrapClient(process: process);
            },
      );

      final capabilities = await probe.probeHostCapabilities(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      );

      expect(capabilities.supportsContinuity, isFalse);
      expect(capabilities.issues, <ConnectionRemoteHostCapabilityIssue>{
        ConnectionRemoteHostCapabilityIssue.workspaceUnavailable,
        ConnectionRemoteHostCapabilityIssue.codexMissing,
      });
    },
  );

  test(
    'probeHostCapabilities throws when the remote output is not parseable',
    () async {
      final process = _FakeCodexAppServerProcess(
        stdoutLines: <String>['unexpected output'],
        stderrLines: <String>['stderr detail'],
        exitCodeValue: 7,
      );
      final probe = CodexSshRemoteAppServerHostProbe(
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return _FakeSshBootstrapClient(process: process);
            },
      );

      await expectLater(
        probe.probeHostCapabilities(
          profile: _profile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('no parseable result'),
          ),
        ),
      );
    },
  );

  test(
    'buildPocketRelayRemoteOwnerSessionName normalizes unsafe characters',
    () {
      expect(
        buildPocketRelayRemoteOwnerSessionName(
          ownerId: ' remote owner / feature ',
        ),
        'pocket-relay-remote-owner-feature',
      );
    },
  );

  test('buildPocketRelayRemoteOwnerPortCandidates are deterministic', () {
    final first = buildPocketRelayRemoteOwnerPortCandidates(
      ownerId: 'remote-1',
    );
    final second = buildPocketRelayRemoteOwnerPortCandidates(
      ownerId: 'remote-1',
    );

    expect(first, second);
    expect(first, hasLength(8));
    expect(first.toSet(), hasLength(8));
    expect(first.every((port) => port >= 42000 && port < 62000), isTrue);
  });

  test('buildSshRemoteOwnerInspectCommand checks tmux and readyz', () {
    final command = buildSshRemoteOwnerInspectCommand(
      sessionName: 'pocket-relay-remote-1',
      workspaceDir: '/workspace',
    );

    expect(
      command,
      contains(
        r'PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"',
      ),
    );
    expect(command, contains('tmux has-session'));
    expect(command, contains('/readyz'));
    expect(command, contains('/tmp/pocket-relay-remote-1.log'));
    expect(command, contains('pocket-relay-remote-1'));
  });

  test('buildSshRemoteOwnerStartCommand starts a tmux websocket owner', () {
    final command = buildSshRemoteOwnerStartCommand(
      sessionName: 'pocket-relay-remote-1',
      workspaceDir: '/workspace',
      codexPath: 'codex',
      port: 45123,
    );

    expect(
      command,
      contains(
        r'PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"',
      ),
    );
    expect(command, contains('tmux new-session'));
    expect(command, contains('ws://127.0.0.1:45123'));
    expect(command, contains('/tmp/pocket-relay-remote-1.log'));
    expect(command, contains('requested_codex='));
    expect(command, contains('resolve_requested_codex()'));
    expect(command, contains('run_requested_codex app-server --listen'));
    expect(command, contains('codex app-server exited with status'));
    expect(command, contains('pocket-relay-remote-1'));
    expect(command, contains('tmux respawn-pane'));
    expect(command, contains('exec bash -lc'));
    expect(command, contains('tmux new-session -d -P -F'));
    expect(command, contains('#{pane_id}'));
  });

  test(
    'buildSshRemoteOwnerStartCommand preserves shell-wrapped launch commands',
    () {
      final command = buildSshRemoteOwnerStartCommand(
        sessionName: 'pocket-relay-remote-1',
        workspaceDir: '/workspace',
        codexPath: 'source /etc/profile && codex',
        port: 45123,
      );

      expect(command, contains('source /etc/profile && codex'));
      expect(command, contains('run_requested_codex app-server --listen'));
    },
  );

  test('buildSshRemoteOwnerStopCommand kills the expected tmux session', () {
    final command = buildSshRemoteOwnerStopCommand(
      sessionName: 'pocket-relay-remote-1',
    );

    expect(
      command,
      contains(
        r'PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"',
      ),
    );
    expect(command, contains('tmux kill-session'));
    expect(command, contains('/tmp/pocket-relay-remote-1.log'));
    expect(command, contains('pocket-relay-remote-1'));
  });

  test('inspectOwner appends captured launch output when provided', () async {
    final encodedLog = base64.encode(utf8.encode('codex: command not found\n'));
    final process = _FakeCodexAppServerProcess(
      stdoutLines: <String>[
        '__pocket_relay_owner__ status=missing pid= host= port= detail=session_missing log_b64=$encodedLog',
      ],
    );
    final inspector = CodexSshRemoteAppServerOwnerInspector(
      sshBootstrap:
          ({required profile, required secrets, required verifyHostKey}) async {
            return _FakeSshBootstrapClient(process: process);
          },
    );

    final snapshot = await inspector.inspectOwner(
      profile: _profile(),
      secrets: const ConnectionSecrets(password: 'secret'),
      ownerId: 'remote-1',
      workspaceDir: '/workspace',
    );

    expect(snapshot.status, CodexRemoteAppServerOwnerStatus.missing);
    expect(
      snapshot.detail,
      contains('Underlying error: codex: command not found'),
    );
  });

  test('inspectOwner reports missing when no managed session exists', () async {
    final process = _FakeCodexAppServerProcess(
      stdoutLines: <String>[
        '__pocket_relay_owner__ status=missing pid= host= port= detail=session_missing',
      ],
    );
    final inspector = CodexSshRemoteAppServerOwnerInspector(
      sshBootstrap:
          ({required profile, required secrets, required verifyHostKey}) async {
            return _FakeSshBootstrapClient(process: process);
          },
    );

    final snapshot = await inspector.inspectOwner(
      profile: _profile(),
      secrets: const ConnectionSecrets(password: 'secret'),
      ownerId: 'remote-1',
      workspaceDir: '/workspace',
    );

    expect(snapshot.status, CodexRemoteAppServerOwnerStatus.missing);
    expect(snapshot.sessionName, 'pocket-relay-remote-1');
    expect(
      snapshot.detail,
      contains('No managed remote app-server is running'),
    );
    expect(snapshot.isConnectable, isFalse);
  });

  test(
    'inspectOwner reports stopped when websocket launch metadata is missing',
    () async {
      final process = _FakeCodexAppServerProcess(
        stdoutLines: <String>[
          '__pocket_relay_owner__ status=stopped pid=2041 host= port= detail=listen_url_missing',
        ],
      );
      final inspector = CodexSshRemoteAppServerOwnerInspector(
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return _FakeSshBootstrapClient(process: process);
            },
      );

      final snapshot = await inspector.inspectOwner(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        ownerId: 'remote-1',
        workspaceDir: '/workspace',
      );

      expect(snapshot.status, CodexRemoteAppServerOwnerStatus.stopped);
      expect(snapshot.pid, 2041);
      expect(snapshot.detail, contains('not running a websocket app-server'));
    },
  );

  test(
    'inspectOwner appends explicit app-server exit status from the launch log',
    () async {
      final encodedLog = base64.encode(
        utf8.encode('pocket-relay: codex app-server exited with status 23\n'),
      );
      final process = _FakeCodexAppServerProcess(
        stdoutLines: <String>[
          '__pocket_relay_owner__ status=stopped pid=2041 host= port= detail=process_missing log_b64=$encodedLog',
        ],
      );
      final inspector = CodexSshRemoteAppServerOwnerInspector(
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return _FakeSshBootstrapClient(process: process);
            },
      );

      final snapshot = await inspector.inspectOwner(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        ownerId: 'remote-1',
        workspaceDir: '/workspace',
      );

      expect(snapshot.status, CodexRemoteAppServerOwnerStatus.stopped);
      expect(snapshot.detail, contains('Underlying error:'));
      expect(
        snapshot.detail,
        contains('codex app-server exited with status 23'),
      );
    },
  );

  test('inspectOwner reports unhealthy when readyz fails', () async {
    final process = _FakeCodexAppServerProcess(
      stdoutLines: <String>[
        '__pocket_relay_owner__ status=unhealthy pid=2041 host=127.0.0.1 port=4100 detail=ready_check_failed',
      ],
    );
    final inspector = CodexSshRemoteAppServerOwnerInspector(
      sshBootstrap:
          ({required profile, required secrets, required verifyHostKey}) async {
            return _FakeSshBootstrapClient(process: process);
          },
    );

    final snapshot = await inspector.inspectOwner(
      profile: _profile(),
      secrets: const ConnectionSecrets(password: 'secret'),
      ownerId: 'remote-1',
      workspaceDir: '/workspace',
    );

    expect(snapshot.status, CodexRemoteAppServerOwnerStatus.unhealthy);
    expect(snapshot.endpoint, isNotNull);
    expect(snapshot.endpoint!.port, 4100);
    expect(snapshot.detail, contains('did not pass its readiness check'));
  });

  test(
    'inspectOwner reports unhealthy when the configured workspace is inaccessible',
    () async {
      final process = _FakeCodexAppServerProcess(
        stdoutLines: <String>[
          '__pocket_relay_owner__ status=unhealthy pid=2041 host= port= detail=expected_workspace_unavailable',
        ],
      );
      final inspector = CodexSshRemoteAppServerOwnerInspector(
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return _FakeSshBootstrapClient(process: process);
            },
      );

      final snapshot = await inspector.inspectOwner(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        ownerId: 'remote-1',
        workspaceDir: '/workspace',
      );

      expect(snapshot.status, CodexRemoteAppServerOwnerStatus.unhealthy);
      expect(
        snapshot.detail,
        contains('configured workspace directory is not accessible'),
      );
    },
  );

  test('inspectOwner reports running when readyz succeeds', () async {
    final process = _FakeCodexAppServerProcess(
      stdoutLines: <String>[
        '__pocket_relay_owner__ status=running pid=2041 host=127.0.0.1 port=4100 detail=ready',
      ],
    );
    final inspector = CodexSshRemoteAppServerOwnerInspector(
      sshBootstrap:
          ({required profile, required secrets, required verifyHostKey}) async {
            return _FakeSshBootstrapClient(process: process);
          },
    );

    final snapshot = await inspector.inspectOwner(
      profile: _profile(),
      secrets: const ConnectionSecrets(password: 'secret'),
      ownerId: 'remote-1',
      workspaceDir: '/workspace',
    );

    expect(snapshot.status, CodexRemoteAppServerOwnerStatus.running);
    expect(snapshot.endpoint, isNotNull);
    expect(snapshot.endpoint!.host, '127.0.0.1');
    expect(snapshot.endpoint!.port, 4100);
    expect(snapshot.isConnectable, isTrue);
  });

  test('startOwner creates a new tmux-managed server when missing', () async {
    final inspectOutputs = <_FakeCodexAppServerProcess>[
      _ownerProcess(
        '__pocket_relay_owner__ status=missing pid= host= port= detail=session_missing',
      ),
      _ownerProcess(
        '__pocket_relay_owner__ status=running pid=2041 host=127.0.0.1 port=45123 detail=ready',
      ),
    ];
    final launchedCommands = <String>[];
    final control = CodexSshRemoteAppServerOwnerControl(
      sshBootstrap:
          ({required profile, required secrets, required verifyHostKey}) async {
            return _ScriptedSshBootstrapClient(
              onLaunch: (command) async {
                launchedCommands.add(command);
                if (command.contains('__pocket_relay_owner__')) {
                  return inspectOutputs.removeAt(0);
                }
                return _FakeCodexAppServerProcess();
              },
            );
          },
    );

    final snapshot = await control.startOwner(
      profile: _profile(),
      secrets: const ConnectionSecrets(password: 'secret'),
      ownerId: 'remote-1',
      workspaceDir: '/workspace',
    );

    expect(snapshot.status, CodexRemoteAppServerOwnerStatus.running);
    expect(snapshot.endpoint?.port, 45123);
    expect(
      launchedCommands.any((command) => command.contains('tmux new-session')),
      isTrue,
    );
  });

  test('startOwner waits through delayed readyz before reporting running', () async {
    final inspectOutputs = <_FakeCodexAppServerProcess>[
      _ownerProcess(
        '__pocket_relay_owner__ status=missing pid= host= port= detail=session_missing',
      ),
      for (var index = 0; index < 24; index += 1)
        _ownerProcess(
          '__pocket_relay_owner__ status=unhealthy pid=2041 host=127.0.0.1 port=45123 detail=ready_check_failed',
        ),
      _ownerProcess(
        '__pocket_relay_owner__ status=running pid=2041 host=127.0.0.1 port=45123 detail=ready',
      ),
    ];
    final control = CodexSshRemoteAppServerOwnerControl(
      readyPollDelay: Duration.zero,
      sshBootstrap:
          ({required profile, required secrets, required verifyHostKey}) async {
            return _ScriptedSshBootstrapClient(
              onLaunch: (command) async {
                if (command.contains('__pocket_relay_owner__')) {
                  return inspectOutputs.removeAt(0);
                }
                return _FakeCodexAppServerProcess();
              },
            );
          },
    );

    final snapshot = await control.startOwner(
      profile: _profile(),
      secrets: const ConnectionSecrets(password: 'secret'),
      ownerId: 'remote-1',
      workspaceDir: '/workspace',
    );

    expect(snapshot.status, CodexRemoteAppServerOwnerStatus.running);
    expect(snapshot.endpoint?.port, 45123);
  });

  test(
    'startOwner returns the existing running owner without relaunch',
    () async {
      final launchedCommands = <String>[];
      final control = CodexSshRemoteAppServerOwnerControl(
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return _ScriptedSshBootstrapClient(
                onLaunch: (command) async {
                  launchedCommands.add(command);
                  return _ownerProcess(
                    '__pocket_relay_owner__ status=running pid=2041 host=127.0.0.1 port=4100 detail=ready',
                  );
                },
              );
            },
      );

      final snapshot = await control.startOwner(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        ownerId: 'remote-1',
        workspaceDir: '/workspace',
      );

      expect(snapshot.status, CodexRemoteAppServerOwnerStatus.running);
      expect(
        launchedCommands.any((command) => command.contains('tmux new-session')),
        isFalse,
      );
    },
  );

  test('stopOwner kills the tmux owner and returns the missing state', () async {
    final inspectOutputs = <_FakeCodexAppServerProcess>[
      _ownerProcess(
        '__pocket_relay_owner__ status=missing pid= host= port= detail=session_missing',
      ),
    ];
    final launchedCommands = <String>[];
    final control = CodexSshRemoteAppServerOwnerControl(
      sshBootstrap:
          ({required profile, required secrets, required verifyHostKey}) async {
            return _ScriptedSshBootstrapClient(
              onLaunch: (command) async {
                launchedCommands.add(command);
                if (command.contains('__pocket_relay_owner__')) {
                  return inspectOutputs.removeAt(0);
                }
                return _FakeCodexAppServerProcess();
              },
            );
          },
    );

    final snapshot = await control.stopOwner(
      profile: _profile(),
      secrets: const ConnectionSecrets(password: 'secret'),
      ownerId: 'remote-1',
      workspaceDir: '/workspace',
    );

    expect(snapshot.status, CodexRemoteAppServerOwnerStatus.missing);
    expect(
      launchedCommands.any((command) => command.contains('tmux kill-session')),
      isTrue,
    );
  });

  test(
    'stopOwner waits through delayed owner shutdown before reporting missing',
    () async {
      final inspectOutputs = <_FakeCodexAppServerProcess>[
        for (var index = 0; index < 4; index += 1)
          _ownerProcess(
            '__pocket_relay_owner__ status=running pid=2041 host=127.0.0.1 port=45123 detail=ready',
          ),
        _ownerProcess(
          '__pocket_relay_owner__ status=missing pid= host= port= detail=session_missing',
        ),
      ];
      final launchedCommands = <String>[];
      final control = CodexSshRemoteAppServerOwnerControl(
        stopPollDelay: Duration.zero,
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return _ScriptedSshBootstrapClient(
                onLaunch: (command) async {
                  launchedCommands.add(command);
                  if (command.contains('__pocket_relay_owner__')) {
                    return inspectOutputs.removeAt(0);
                  }
                  return _FakeCodexAppServerProcess();
                },
              );
            },
      );

      final snapshot = await control.stopOwner(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        ownerId: 'remote-1',
        workspaceDir: '/workspace',
      );

      expect(snapshot.status, CodexRemoteAppServerOwnerStatus.missing);
      expect(
        launchedCommands
            .where((command) => command.contains('__pocket_relay_owner__'))
            .length,
        5,
      );
    },
  );

  test('restartOwner is explicit stop plus start', () async {
    final inspectOutputs = <_FakeCodexAppServerProcess>[
      _ownerProcess(
        '__pocket_relay_owner__ status=missing pid= host= port= detail=session_missing',
      ),
      _ownerProcess(
        '__pocket_relay_owner__ status=missing pid= host= port= detail=session_missing',
      ),
      _ownerProcess(
        '__pocket_relay_owner__ status=running pid=2041 host=127.0.0.1 port=45123 detail=ready',
      ),
    ];
    final launchedCommands = <String>[];
    final control = CodexSshRemoteAppServerOwnerControl(
      sshBootstrap:
          ({required profile, required secrets, required verifyHostKey}) async {
            return _ScriptedSshBootstrapClient(
              onLaunch: (command) async {
                launchedCommands.add(command);
                if (command.contains('__pocket_relay_owner__')) {
                  return inspectOutputs.removeAt(0);
                }
                return _FakeCodexAppServerProcess();
              },
            );
          },
    );

    final snapshot = await control.restartOwner(
      profile: _profile(),
      secrets: const ConnectionSecrets(password: 'secret'),
      ownerId: 'remote-1',
      workspaceDir: '/workspace',
    );

    expect(snapshot.status, CodexRemoteAppServerOwnerStatus.running);
    final killIndex = launchedCommands.indexWhere(
      (command) => command.contains('tmux kill-session'),
    );
    final startIndex = launchedCommands.indexWhere(
      (command) => command.contains('tmux new-session'),
    );
    expect(killIndex, isNonNegative);
    expect(startIndex, greaterThan(killIndex));
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

final class _FakeSshBootstrapClient implements CodexSshBootstrapClient {
  _FakeSshBootstrapClient({this.process});

  final CodexAppServerProcess? process;

  @override
  Future<void> authenticate() async {}

  @override
  Future<CodexAppServerProcess> launchProcess(String command) async {
    return process ?? _FakeCodexAppServerProcess();
  }

  @override
  Future<CodexSshForwardChannel> forwardLocal(
    String remoteHost,
    int remotePort, {
    String localHost = 'localhost',
    int localPort = 0,
  }) {
    throw UnimplementedError('forwardLocal is not used in these tests');
  }

  @override
  void close() {}
}

typedef _LaunchHandler = Future<CodexAppServerProcess> Function(String command);

final class _ScriptedSshBootstrapClient implements CodexSshBootstrapClient {
  _ScriptedSshBootstrapClient({required this.onLaunch});

  final _LaunchHandler onLaunch;

  @override
  Future<void> authenticate() async {}

  @override
  Future<CodexAppServerProcess> launchProcess(String command) {
    return onLaunch(command);
  }

  @override
  Future<CodexSshForwardChannel> forwardLocal(
    String remoteHost,
    int remotePort, {
    String localHost = 'localhost',
    int localPort = 0,
  }) {
    throw UnimplementedError('forwardLocal is not used in these tests');
  }

  @override
  void close() {}
}

_FakeCodexAppServerProcess _ownerProcess(String line) {
  return _FakeCodexAppServerProcess(stdoutLines: <String>[line]);
}

final class _FakeCodexAppServerProcess implements CodexAppServerProcess {
  _FakeCodexAppServerProcess({
    List<String> stdoutLines = const <String>[],
    List<String> stderrLines = const <String>[],
    this.exitCodeValue = 0,
  }) {
    unawaited(
      Future<void>(() async {
        for (final line in stdoutLines) {
          _stdoutController.add(Uint8List.fromList(utf8.encode('$line\n')));
        }
        for (final line in stderrLines) {
          _stderrController.add(Uint8List.fromList(utf8.encode('$line\n')));
        }
        await _stdoutController.close();
        await _stderrController.close();
        _doneCompleter.complete();
      }),
    );
  }

  final int? exitCodeValue;
  final _stdoutController = StreamController<Uint8List>();
  final _stderrController = StreamController<Uint8List>();
  final _stdinController = StreamController<Uint8List>();
  final _doneCompleter = Completer<void>();

  @override
  Stream<Uint8List> get stdout => _stdoutController.stream;

  @override
  Stream<Uint8List> get stderr => _stderrController.stream;

  @override
  StreamSink<Uint8List> get stdin => _stdinController.sink;

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  int? get exitCode => exitCodeValue;

  @override
  Future<void> close() async {
    if (!_stdoutController.isClosed) {
      await _stdoutController.close();
    }
    if (!_stderrController.isClosed) {
      await _stderrController.close();
    }
    unawaited(_stdinController.close());
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }
}
