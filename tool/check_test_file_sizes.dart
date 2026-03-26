import 'dart:convert';
import 'dart:io';

const int _defaultLimit = 500;

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  if (options == null) {
    _printUsage(stderr);
    exitCode = 64;
    return;
  }

  final root = Directory(options.rootPath);
  if (!await root.exists()) {
    stderr.writeln('Directory not found: ${options.rootPath}');
    exitCode = 66;
    return;
  }

  final oversized = await _collectOversizedFiles(
    root,
    lineLimit: options.limit,
  );
  if (oversized.isEmpty) {
    stdout.writeln(
      'All test entry files are within the ${options.limit}-line limit.',
    );
    return;
  }

  stdout.writeln(
    'Found ${oversized.length} oversized test entry files '
    '(limit: ${options.limit} lines):',
  );
  for (final result in oversized) {
    stdout.writeln('${result.path}: ${result.lineCount}');
  }

  if (options.failOnOversized) {
    exitCode = 1;
  }
}

typedef _Options = ({bool failOnOversized, int limit, String rootPath});

typedef _OversizedFile = ({int lineCount, String path});

_Options? _parseArgs(List<String> args) {
  var failOnOversized = false;
  var limit = _defaultLimit;
  var rootPath = 'test';

  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    switch (arg) {
      case '--fail':
        failOnOversized = true;
      case '--limit':
        if (index + 1 >= args.length) {
          return null;
        }
        limit = int.tryParse(args[++index]) ?? -1;
        if (limit <= 0) {
          return null;
        }
      case '--root':
        if (index + 1 >= args.length) {
          return null;
        }
        rootPath = args[++index];
      case '--help':
      case '-h':
        return null;
      default:
        return null;
    }
  }

  return (failOnOversized: failOnOversized, limit: limit, rootPath: rootPath);
}

Future<List<_OversizedFile>> _collectOversizedFiles(
  Directory root, {
  required int lineLimit,
}) async {
  final oversized = <_OversizedFile>[];

  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('_test.dart')) {
      continue;
    }
    final lineCount = await _countLines(entity);
    if (lineCount <= lineLimit) {
      continue;
    }
    oversized.add((lineCount: lineCount, path: entity.path));
  }

  oversized.sort((left, right) {
    final lineCountOrder = right.lineCount.compareTo(left.lineCount);
    if (lineCountOrder != 0) {
      return lineCountOrder;
    }
    return left.path.compareTo(right.path);
  });

  return oversized;
}

Future<int> _countLines(File file) async {
  final lines = await file
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .length;

  final endsWithNewline = await _endsWithNewline(file);
  if (endsWithNewline) {
    return lines;
  }
  final text = await file.readAsString();
  if (text.isEmpty) {
    return 0;
  }
  return lines + 1;
}

Future<bool> _endsWithNewline(File file) async {
  final length = await file.length();
  if (length == 0) {
    return false;
  }
  final tail = await file.openRead(length - 1).first;
  return tail.isNotEmpty && tail.first == 0x0A;
}

void _printUsage(IOSink sink) {
  sink.writeln(
    'Usage: dart run tool/check_test_file_sizes.dart '
    '[--limit <lines>] [--root <dir>] [--fail]',
  );
}
