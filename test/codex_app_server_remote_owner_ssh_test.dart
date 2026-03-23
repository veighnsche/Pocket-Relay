import 'dart:async';
import 'dart:convert';
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

    expect(command, contains('command -v tmux'));
    expect(command, contains('codex app-server --help'));
    expect(command, contains('/workspace'));
  });

  test(
    'builds a capability probe command for a launch command with spaces',
    () {
      final command = buildSshRemoteHostCapabilityProbeCommand(
        profile: _profile().copyWith(codexPath: 'just codex-mcp'),
      );

      expect(command, contains('just codex-mcp app-server --help'));
    },
  );

  test(
    'probeHostCapabilities returns supported when tmux and codex are available',
    () async {
      final process = _FakeCodexAppServerProcess(
        stdoutLines: <String>['__pocket_relay_capabilities__ tmux=0 codex=0'],
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
        stdoutLines: <String>['__pocket_relay_capabilities__ tmux=1 codex=1'],
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
        'pocket-relay:remote-owner-feature',
      );
    },
  );

  test('buildSshRemoteOwnerInspectCommand checks tmux and readyz', () {
    final command = buildSshRemoteOwnerInspectCommand(
      sessionName: 'pocket-relay:remote-1',
      workspaceDir: '/workspace',
    );

    expect(command, contains('tmux has-session'));
    expect(command, contains('/readyz'));
    expect(command, contains('pocket-relay:remote-1'));
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
    expect(snapshot.sessionName, 'pocket-relay:remote-1');
    expect(snapshot.detail, contains('No Pocket Relay server is running'));
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
  void close() {}
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
