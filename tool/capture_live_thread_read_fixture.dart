import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_thread_read_fixture_sanitizer.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_json_rpc_codec.dart';

final class CodexLaunchInvocation {
  const CodexLaunchInvocation({
    required this.executable,
    required this.arguments,
  });

  final String executable;
  final List<String> arguments;
}

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  if (options == null) {
    _printUsage(stderr);
    exitCode = 64;
    return;
  }

  final prefs = await _loadPreferences(options.prefsPath);
  final profile = _loadProfile(prefs, profileKey: options.profileKey);
  final threadId = _resolveThreadId(prefs, options: options);
  final workingDirectory =
      options.workingDirectory ?? _asNonEmptyString(profile['workspaceDir']);
  final codexPath =
      options.launcherCommand ?? _asNonEmptyString(profile['codexPath']);
  final connectionMode = (_asString(profile['connectionMode']) ?? '').trim();

  if (workingDirectory == null || workingDirectory.isEmpty) {
    stderr.writeln(
      'Saved profile did not include a usable workspace directory. '
      'Pass --working-directory explicitly.',
    );
    exitCode = 64;
    return;
  }

  if (codexPath == null || codexPath.isEmpty) {
    stderr.writeln(
      'Saved profile did not include a usable Codex launch command. '
      'Pass --launcher-command explicitly.',
    );
    exitCode = 64;
    return;
  }

  if (options.launcherCommand == null &&
      connectionMode.isNotEmpty &&
      connectionMode != 'local') {
    stderr.writeln(
      'Saved profile is "$connectionMode", but this capture tool only launches '
      'a local app-server process. Pass --launcher-command and '
      '--working-directory explicitly if you have a local repro path.',
    );
    exitCode = 64;
    return;
  }

  _JsonRpcProcessClient? client;
  try {
    final invocation = buildCodexLaunchInvocation(codexPath);
    stderr.writeln('Launching app-server from $workingDirectory...');

    final process = await Process.start(
      invocation.executable,
      <String>[
        ...invocation.arguments,
        'app-server',
        '--listen',
        'stdio://',
      ],
      workingDirectory: workingDirectory,
    );

    client = _JsonRpcProcessClient(process);
    final initializeTimeout = Duration(
      seconds: options.initializeTimeoutSeconds,
    );
    final readTimeout = Duration(seconds: options.readTimeoutSeconds);
    await client.initialize().timeout(initializeTimeout);
    stderr.writeln('Reading thread $threadId with includeTurns=true...');
    final payload = await client.readThread(threadId).timeout(readTimeout);

    final sanitized = CodexAppServerThreadReadFixtureSanitizer().sanitize(
      payload,
    );

    if (options.rawOutputPath case final rawOutputPath?) {
      await _writeJsonFile(path: rawOutputPath, content: payload);
      stderr.writeln('Raw payload written to $rawOutputPath');
    }

    await _writeJsonFile(path: options.sanitizedOutputPath, content: sanitized);
    stderr.writeln(
      'Sanitized fixture written to ${options.sanitizedOutputPath}',
    );

    final turnCount = _extractTurns(payload).length;
    final itemCountsByTurn = _extractTurns(payload)
        .map((turn) => _asObjectList(turn['items'])?.length ?? 0)
        .toList(growable: false);
    stdout.writeln(
      jsonEncode(<String, Object?>{
        'threadId': _extractThreadId(payload) ?? threadId,
        'turnCount': turnCount,
        'itemCountsByTurn': itemCountsByTurn,
      }),
    );
  } on TimeoutException catch (error) {
    stderr.writeln('Capture timed out: $error');
    final stderrTail = await client?.stderrTail() ?? '';
    if (stderrTail.isNotEmpty) {
      stderr.writeln(stderrTail);
    }
    exitCode = 1;
  } on _JsonRpcRemoteException catch (error) {
    stderr.writeln('Codex app-server returned an error: ${error.message}');
    if (error.data != null) {
      stderr.writeln(jsonEncode(error.data));
    }
    final stderrTail = await client?.stderrTail() ?? '';
    if (stderrTail.isNotEmpty) {
      stderr.writeln(stderrTail);
    }
    exitCode = 1;
  } on ProcessException catch (error) {
    stderr.writeln('Failed to launch Codex app-server: $error');
    exitCode = 1;
  } on FormatException catch (error) {
    stderr.writeln('Invalid Codex launch command: ${error.message}');
    exitCode = 64;
  } on Object catch (error) {
    stderr.writeln('Capture failed: $error');
    final stderrTail = await client?.stderrTail() ?? '';
    if (stderrTail.isNotEmpty) {
      stderr.writeln(stderrTail);
    }
    exitCode = 1;
  } finally {
    await client?.close();
  }
}

CodexLaunchInvocation buildCodexLaunchInvocation(String launcherCommand) {
  final tokens = _tokenizeCommand(launcherCommand.trim());
  if (tokens == null || tokens.isEmpty) {
    throw const FormatException(
      'Codex launch command must be a plain executable plus optional '
      'arguments.',
    );
  }

  return CodexLaunchInvocation(
    executable: tokens.first,
    arguments: tokens.sublist(1),
  );
}

typedef _CaptureOptions = ({
  String prefsPath,
  String profileKey,
  String handoffKey,
  String? threadId,
  String? launcherCommand,
  String? workingDirectory,
  int initializeTimeoutSeconds,
  int readTimeoutSeconds,
  String sanitizedOutputPath,
  String? rawOutputPath,
});

_CaptureOptions? _parseArgs(List<String> args) {
  var prefsPath =
      '${Platform.environment['HOME']}/.local/share/com.example.pocket_relay/shared_preferences.json';
  var profileKey = 'pocket_relay.profile';
  var handoffKey = 'pocket_relay.conversation_handoff';
  String? threadId;
  String? launcherCommand;
  String? workingDirectory;
  var initializeTimeoutSeconds = 90;
  var readTimeoutSeconds = 60;
  String? sanitizedOutputPath;
  String? rawOutputPath;

  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    switch (arg) {
      case '--prefs':
        if (index + 1 >= args.length) {
          return null;
        }
        prefsPath = args[++index];
      case '--profile-key':
        if (index + 1 >= args.length) {
          return null;
        }
        profileKey = args[++index];
      case '--handoff-key':
        if (index + 1 >= args.length) {
          return null;
        }
        handoffKey = args[++index];
      case '--thread-id':
        if (index + 1 >= args.length) {
          return null;
        }
        threadId = args[++index];
      case '--launcher-command':
        if (index + 1 >= args.length) {
          return null;
        }
        launcherCommand = args[++index];
      case '--working-directory':
        if (index + 1 >= args.length) {
          return null;
        }
        workingDirectory = args[++index];
      case '--initialize-timeout-seconds':
        if (index + 1 >= args.length) {
          return null;
        }
        initializeTimeoutSeconds = int.parse(args[++index]);
      case '--read-timeout-seconds':
        if (index + 1 >= args.length) {
          return null;
        }
        readTimeoutSeconds = int.parse(args[++index]);
      case '--sanitized-output':
        if (index + 1 >= args.length) {
          return null;
        }
        sanitizedOutputPath = args[++index];
      case '--raw-output':
        if (index + 1 >= args.length) {
          return null;
        }
        rawOutputPath = args[++index];
      case '--help':
      case '-h':
        return null;
      default:
        return null;
    }
  }

  final normalizedSanitizedOutputPath = sanitizedOutputPath?.trim();
  if (normalizedSanitizedOutputPath == null ||
      normalizedSanitizedOutputPath.isEmpty) {
    return null;
  }

  return (
    prefsPath: prefsPath,
    profileKey: profileKey,
    handoffKey: handoffKey,
    threadId: _normalizeOptionalString(threadId),
    launcherCommand: _normalizeOptionalString(launcherCommand),
    workingDirectory: _normalizeOptionalString(workingDirectory),
    initializeTimeoutSeconds: initializeTimeoutSeconds,
    readTimeoutSeconds: readTimeoutSeconds,
    sanitizedOutputPath: normalizedSanitizedOutputPath,
    rawOutputPath: _normalizeOptionalString(rawOutputPath),
  );
}

Future<Map<String, dynamic>> _loadPreferences(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw StateError('Shared preferences file not found: $path');
  }
  final text = await file.readAsString();
  final decoded = jsonDecode(text);
  if (decoded is! Map) {
    throw StateError('Shared preferences file was not a JSON object.');
  }
  return Map<String, dynamic>.from(decoded);
}

Map<String, dynamic> _loadProfile(
  Map<String, dynamic> prefs, {
  required String profileKey,
}) {
  final rawProfile = prefs[profileKey];
  if (rawProfile is! String || rawProfile.trim().isEmpty) {
    throw StateError(
      'Shared preferences did not include a profile at $profileKey.',
    );
  }
  final decoded = jsonDecode(rawProfile);
  if (decoded is! Map) {
    throw StateError('Saved profile at $profileKey was not a JSON object.');
  }
  return Map<String, dynamic>.from(decoded);
}

String _resolveThreadId(
  Map<String, dynamic> prefs, {
  required _CaptureOptions options,
}) {
  if (options.threadId case final threadId?) {
    return threadId;
  }

  final rawHandoff = prefs[options.handoffKey];
  if (rawHandoff is! String || rawHandoff.trim().isEmpty) {
    throw StateError(
      'Shared preferences did not include a handoff entry at ${options.handoffKey}. '
      'Pass --thread-id explicitly.',
    );
  }

  final decoded = jsonDecode(rawHandoff);
  if (decoded is! Map) {
    throw StateError(
      'Saved handoff at ${options.handoffKey} was not a JSON object. '
      'Pass --thread-id explicitly.',
    );
  }

  final resumeThreadId = _asNonEmptyString(
    Map<String, dynamic>.from(decoded)['resumeThreadId'],
  );
  if (resumeThreadId == null) {
    throw StateError(
      'Handoff entry at ${options.handoffKey} did not include a resumeThreadId. '
      'Pass --thread-id explicitly.',
    );
  }

  return resumeThreadId;
}

List<Map<String, dynamic>> _extractTurns(Map<String, dynamic> payload) {
  final thread = _extractThreadObject(payload);
  return _asObjectList(thread?['turns']) ??
      _asObjectList(payload['turns']) ??
      const <Map<String, dynamic>>[];
}

Map<String, dynamic>? _extractThreadObject(Map<String, dynamic> payload) {
  final rawThread = payload['thread'];
  if (rawThread is Map) {
    return Map<String, dynamic>.from(rawThread);
  }
  return null;
}

String? _extractThreadId(Map<String, dynamic> payload) {
  final thread = _extractThreadObject(payload);
  return _asNonEmptyString(thread?['id']) ??
      _asNonEmptyString(payload['threadId']) ??
      _asNonEmptyString(payload['id']);
}

List<Map<String, dynamic>>? _asObjectList(Object? value) {
  if (value is! List) {
    return null;
  }
  return value
      .whereType<Map>()
      .map((entry) => Map<String, dynamic>.from(entry))
      .toList(growable: false);
}

String? _asString(Object? value) {
  return value is String ? value : null;
}

String? _asNonEmptyString(Object? value) {
  final normalized = _asString(value)?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String? _normalizeOptionalString(String? value) {
  if (value == null) {
    return null;
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

List<String>? _tokenizeCommand(String commandText) {
  final tokens = <String>[];
  final buffer = StringBuffer();
  String? quote;
  var escaping = false;

  void flushBuffer() {
    if (buffer.isEmpty) {
      return;
    }
    tokens.add(buffer.toString());
    buffer.clear();
  }

  for (var index = 0; index < commandText.length; index += 1) {
    final char = commandText[index];
    if (escaping) {
      buffer.write(char);
      escaping = false;
      continue;
    }

    if (quote == "'") {
      if (char == "'") {
        quote = null;
      } else {
        buffer.write(char);
      }
      continue;
    }

    if (quote == '"') {
      if (char == '"') {
        quote = null;
      } else if (char == '\\') {
        final next = index + 1 < commandText.length
            ? commandText[index + 1]
            : null;
        if (next != null &&
            (RegExp(r'\s').hasMatch(next) ||
                next == '"' ||
                next == "'" ||
                next == '\\')) {
          escaping = true;
          continue;
        }
        buffer.write(char);
      } else {
        buffer.write(char);
      }
      continue;
    }

    if (char == "'") {
      quote = "'";
      continue;
    }
    if (char == '"') {
      quote = '"';
      continue;
    }
    if (char == '\\') {
      final next = index + 1 < commandText.length
          ? commandText[index + 1]
          : null;
      if (next != null &&
          (RegExp(r'\s').hasMatch(next) ||
              next == '"' ||
              next == "'" ||
              next == '\\')) {
        escaping = true;
        continue;
      }
      buffer.write(char);
      continue;
    }
    if (RegExp(r'\s').hasMatch(char)) {
      flushBuffer();
      continue;
    }

    buffer.write(char);
  }

  if (escaping || quote != null) {
    return null;
  }

  flushBuffer();
  return tokens.isEmpty ? null : tokens;
}

Future<void> _writeJsonFile({
  required String path,
  required Object? content,
}) async {
  final outputFile = File(path);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(content)}\n',
  );
}

void _printUsage(IOSink sink) {
  sink.writeln(
    'Usage: dart run tool/capture_live_thread_read_fixture.dart '
    '--sanitized-output <fixture.json> [--raw-output <raw.json>] '
    '[--thread-id <thread_id>] [--prefs <shared_preferences.json>] '
    '[--profile-key <key>] [--handoff-key <key>] '
    '[--launcher-command <command>] [--working-directory <dir>] '
    '[--initialize-timeout-seconds <seconds>] '
    '[--read-timeout-seconds <seconds>]',
  );
}

final class _JsonRpcProcessClient {
  _JsonRpcProcessClient(this._process) {
    _stdoutSubscription = _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleStdoutLine);
    _stderrSubscription = _process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleStderrLine);
  }

  final Process _process;
  final CodexJsonRpcCodec _codec = const CodexJsonRpcCodec();
  final List<String> _stderrLines = <String>[];
  final Map<String, Completer<Object?>> _pendingRequests =
      <String, Completer<Object?>>{};
  late final StreamSubscription<String> _stdoutSubscription;
  late final StreamSubscription<String> _stderrSubscription;
  int _nextRequestId = 1;

  Future<void> initialize() async {
    await _sendRequest(
      method: 'initialize',
      params: <String, Object?>{
        'clientInfo': const <String, String>{
          'name': 'pocket_relay_fixture_capture',
          'title': 'Pocket Relay Fixture Capture',
          'version': '1.0.0',
        },
        'capabilities': const <String, bool>{'experimentalApi': true},
      },
    );
    _writeMessage(const CodexJsonRpcNotification(method: 'initialized'));
  }

  Future<Map<String, dynamic>> readThread(String threadId) async {
    final response = await _sendRequest(
      method: 'thread/read',
      params: <String, Object?>{'threadId': threadId, 'includeTurns': true},
    );
    if (response is! Map) {
      throw StateError('thread/read response was not a JSON object.');
    }
    return Map<String, dynamic>.from(response);
  }

  Future<String> stderrTail() async {
    if (_stderrLines.isEmpty) {
      return '';
    }
    return _stderrLines.join('\n');
  }

  Future<void> close() async {
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('App-server process closed before request completed.'),
        );
      }
    }
    _pendingRequests.clear();
    await _stdoutSubscription.cancel();
    await _stderrSubscription.cancel();
    _process.kill();
    try {
      await _process.exitCode.timeout(const Duration(seconds: 2));
    } catch (_) {
      // Ignore shutdown races.
    }
  }

  Future<Object?> _sendRequest({
    required String method,
    required Object? params,
  }) {
    final request = CodexJsonRpcRequest(
      id: CodexJsonRpcId(_nextRequestId++),
      method: method,
      params: params,
    );
    final completer = Completer<Object?>();
    _pendingRequests[request.id.token] = completer;
    _writeMessage(request);
    return completer.future;
  }

  void _writeMessage(CodexJsonRpcMessage message) {
    _process.stdin.write(_codec.encodeLine(message));
  }

  void _handleStdoutLine(String line) {
    final decoded = _codec.decodeLine(line);
    if (decoded is! CodexJsonRpcDecodedMessage) {
      return;
    }

    final message = decoded.message;
    switch (message) {
      case CodexJsonRpcResponse(:final id, :final isError):
        final completer = _pendingRequests.remove(id.token);
        if (completer == null || completer.isCompleted) {
          return;
        }
        if (isError) {
          completer.completeError(
            _JsonRpcRemoteException(
              message.error?.message ?? 'Unknown JSON-RPC error.',
              code: message.error?.code,
              data: message.error?.data,
            ),
          );
        } else {
          completer.complete(message.result);
        }
      case CodexJsonRpcRequest(:final id):
        _writeMessage(
          CodexJsonRpcResponse.failure(
            id: id,
            error: const CodexJsonRpcError(
              code: -32000,
              message: 'Unexpected server request during fixture capture.',
            ),
          ),
        );
      case CodexJsonRpcNotification():
      // Ignore notifications during capture.
    }
  }

  void _handleStderrLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _stderrLines.add(trimmed);
    if (_stderrLines.length > 40) {
      _stderrLines.removeAt(0);
    }
  }
}

final class _JsonRpcRemoteException implements Exception {
  const _JsonRpcRemoteException(this.message, {this.code, this.data});

  final String message;
  final int? code;
  final Object? data;

  @override
  String toString() {
    if (code == null) {
      return message;
    }
    return '[$code] $message';
  }
}
