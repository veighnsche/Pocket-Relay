import 'dart:convert';
import 'dart:io';

import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_thread_read_fixture_sanitizer.dart';

Future<void> main(List<String> args) async {
  final parsed = _parseArgs(args);
  if (parsed == null) {
    _printUsage(stderr);
    exitCode = 64;
    return;
  }

  final inputFile = File(parsed.inputPath);
  if (!await inputFile.exists()) {
    stderr.writeln('Input file not found: ${parsed.inputPath}');
    exitCode = 66;
    return;
  }

  final rawText = await inputFile.readAsString();
  final decoded = jsonDecode(rawText);
  final sanitized = CodexAppServerThreadReadFixtureSanitizer().sanitize(
    decoded,
  );
  final formatted = const JsonEncoder.withIndent('  ').convert(sanitized);

  if (parsed.outputPath case final outputPath?) {
    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString('$formatted\n');
    stdout.writeln('Sanitized fixture written to $outputPath');
    return;
  }

  stdout.writeln(formatted);
}

({String inputPath, String? outputPath})? _parseArgs(List<String> args) {
  String? inputPath;
  String? outputPath;

  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    switch (arg) {
      case '--input':
      case '-i':
        if (index + 1 >= args.length) {
          return null;
        }
        inputPath = args[++index];
      case '--output':
      case '-o':
        if (index + 1 >= args.length) {
          return null;
        }
        outputPath = args[++index];
      case '--help':
      case '-h':
        return null;
      default:
        return null;
    }
  }

  if (inputPath == null || inputPath.trim().isEmpty) {
    return null;
  }

  return (inputPath: inputPath, outputPath: outputPath);
}

void _printUsage(IOSink sink) {
  sink.writeln(
    'Usage: dart run tool/sanitize_thread_read_fixture.dart '
    '--input <raw.json> [--output <sanitized.json>]',
  );
}
