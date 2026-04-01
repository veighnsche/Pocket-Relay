import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart';

export 'dart:async';
export 'dart:convert';
export 'dart:io';
export 'dart:typed_data';
export 'package:flutter_test/flutter_test.dart';
export 'package:pocket_relay/src/core/models/connection_models.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart';

ConnectionProfile sshProfile() {
  return ConnectionProfile(
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

final class FakeSshBootstrapClient implements CodexSshBootstrapClient {
  FakeSshBootstrapClient({this.process});

  final CodexAppServerProcess? process;

  @override
  Future<void> authenticate() async {}

  @override
  Future<CodexAppServerProcess> launchProcess(String command) async {
    return process ?? FakeCodexAppServerProcess();
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

typedef LaunchHandler = Future<CodexAppServerProcess> Function(String command);

final class ScriptedSshBootstrapClient implements CodexSshBootstrapClient {
  ScriptedSshBootstrapClient({required this.onLaunch});

  final LaunchHandler onLaunch;

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

FakeCodexAppServerProcess ownerProcess(String line) {
  return FakeCodexAppServerProcess(stdoutLines: <String>[line]);
}

final class FakeCodexAppServerProcess implements CodexAppServerProcess {
  FakeCodexAppServerProcess({
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
