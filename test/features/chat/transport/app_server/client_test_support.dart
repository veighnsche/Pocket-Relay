import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:flutter_test/flutter_test.dart';

export 'dart:async';
export 'dart:convert';
export 'dart:typed_data';
export 'package:pocket_relay/src/core/models/connection_models.dart';
export 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
export 'package:flutter_test/flutter_test.dart';

ConnectionProfile clientProfile({bool ephemeralSession = false}) {
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
    ephemeralSession: ephemeralSession,
  );
}

class FakeCodexAppServerProcess implements CodexAppServerProcess {
  FakeCodexAppServerProcess({this.onClientMessage, this.exitCodeValue = 0}) {
    _stdinController.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final decoded = jsonDecode(line) as Map<String, dynamic>;
          writtenMessages.add(decoded);
          onClientMessage?.call(decoded);
        });
  }

  final void Function(Map<String, dynamic> message)? onClientMessage;
  final int? exitCodeValue;
  final List<Map<String, dynamic>> writtenMessages = <Map<String, dynamic>>[];

  final _stdinController = StreamController<Uint8List>();
  final _stdoutController = StreamController<Uint8List>.broadcast();
  final _stderrController = StreamController<Uint8List>.broadcast();
  final _doneCompleter = Completer<void>();
  bool _isClosed = false;

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

  void sendStdout(Map<String, Object?> payload) {
    final line = '${jsonEncode(payload)}\n';
    _stdoutController.add(Uint8List.fromList(utf8.encode(line)));
  }

  void sendStderr(String text, {bool includeTrailingNewline = true}) {
    final output = includeTrailingNewline ? '$text\n' : text;
    _stderrController.add(Uint8List.fromList(utf8.encode(output)));
  }

  @override
  Future<void> close() async {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
    await _stdinController.close();
    await _stdoutController.close();
    await _stderrController.close();
  }
}

class FakeCodexAppServerTransport implements CodexAppServerTransport {
  FakeCodexAppServerTransport({this.onClientLine});

  final void Function(String line)? onClientLine;
  @override
  final CodexAppServerTransportTermination? termination =
      const CodexAppServerTransportTermination(exitCode: 0);
  final List<String> writtenLines = <String>[];

  final _protocolMessagesController = StreamController<String>.broadcast();
  final _diagnosticsController = StreamController<String>.broadcast();
  final _doneCompleter = Completer<void>();
  bool _isClosed = false;

  @override
  Stream<String> get protocolMessages => _protocolMessagesController.stream;

  @override
  Stream<String> get diagnostics => _diagnosticsController.stream;

  @override
  Future<void> get done => _doneCompleter.future;

  void sendProtocolMessage(Map<String, Object?> payload) {
    _protocolMessagesController.add(jsonEncode(payload));
  }

  void sendDiagnostic(String message) {
    _diagnosticsController.add(message);
  }

  @override
  void sendLine(String line) {
    writtenLines.add(line);
    onClientLine?.call(line);
  }

  @override
  Future<void> close() async {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
    await _protocolMessagesController.close();
    await _diagnosticsController.close();
  }
}
