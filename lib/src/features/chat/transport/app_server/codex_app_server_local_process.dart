import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';

import 'codex_app_server_models.dart';

class CodexLocalShellInvocation {
  const CodexLocalShellInvocation({
    required this.executable,
    required this.arguments,
  });

  final String executable;
  final List<String> arguments;
}

typedef CodexLocalProcessStarter =
    Future<Process> Function({
      required String executable,
      required List<String> arguments,
      required String workingDirectory,
    });

Future<CodexAppServerProcess> openLocalCodexAppServerProcess({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required void Function(CodexAppServerEvent event) emitEvent,
  @visibleForTesting
  CodexLocalProcessStarter processStarter = _startLocalProcess,
}) async {
  final invocation = buildLocalCodexAppServerInvocation(profile: profile);

  try {
    final process = await processStarter(
      executable: invocation.executable,
      arguments: invocation.arguments,
      workingDirectory: profile.workspaceDir.trim(),
    );
    return _LocalCodexAppServerProcess(process);
  } catch (error) {
    emitEvent(
      CodexAppServerDiagnosticEvent(
        message: 'Failed to start local Codex app-server: $error',
        isError: true,
      ),
    );
    rethrow;
  }
}

CodexLocalShellInvocation buildLocalCodexAppServerInvocation({
  required ConnectionProfile profile,
  TargetPlatform? platform,
}) {
  final command = '${profile.codexPath.trim()} app-server --listen stdio://';
  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.windows => CodexLocalShellInvocation(
      executable: 'cmd.exe',
      arguments: <String>['/C', command],
    ),
    _ => CodexLocalShellInvocation(
      executable: 'bash',
      arguments: <String>['-lc', command],
    ),
  };
}

Future<Process> _startLocalProcess({
  required String executable,
  required List<String> arguments,
  required String workingDirectory,
}) {
  return Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
}

class _LocalCodexAppServerProcess implements CodexAppServerProcess {
  _LocalCodexAppServerProcess(this._process) {
    _process.exitCode.then((code) {
      _exitCode = code;
    });
    _stdinController.stream.listen(
      (data) {
        _process.stdin.add(data);
      },
      onDone: () {
        unawaited(_process.stdin.close());
      },
    );
  }

  final Process _process;
  final _stdinController = StreamController<Uint8List>();
  int? _exitCode;

  @override
  Stream<Uint8List> get stdout => _process.stdout.map(
    (chunk) => chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
  );

  @override
  Stream<Uint8List> get stderr => _process.stderr.map(
    (chunk) => chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
  );

  @override
  StreamSink<Uint8List> get stdin => _stdinController.sink;

  @override
  Future<void> get done => _process.exitCode.then((_) {});

  @override
  int? get exitCode => _exitCode;

  @override
  Future<void> close() async {
    await _stdinController.close();
    _process.kill();
    try {
      await _process.exitCode;
    } catch (_) {
      // Ignore exit errors during teardown.
    }
  }
}
