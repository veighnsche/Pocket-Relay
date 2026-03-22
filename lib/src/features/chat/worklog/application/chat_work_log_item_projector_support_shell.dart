part of 'chat_work_log_item_projector.dart';

bool _looksLikeCommandExecution(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  if (trimmed.contains('&&') ||
      trimmed.contains('||') ||
      trimmed.contains('|') ||
      trimmed.contains(';')) {
    return false;
  }

  final tokens = _tokenizeShellCommand(trimmed);
  if (tokens == null || tokens.isEmpty) {
    return false;
  }

  final commandName = _commandName(tokens.first);
  if (commandName.isEmpty) {
    return false;
  }
  if (_structuredCommandNames.contains(commandName)) {
    return false;
  }

  if (tokens.length == 1) {
    return true;
  }

  return tokens
      .skip(1)
      .any(
        (token) =>
            token.startsWith('-') ||
            token.contains('/') ||
            token.contains('\\') ||
            token.contains('.') ||
            token.contains('=') ||
            token.contains(':'),
      );
}

const Set<String> _structuredCommandNames = <String>{
  'awk',
  'cat',
  'findstr',
  'get-content',
  'git',
  'grep',
  'head',
  'more',
  'rg',
  'sed',
  'select-string',
  'tail',
  'type',
};

bool _containsShellOperators(String commandText) {
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var escaping = false;

  for (var index = 0; index < commandText.length; index++) {
    final char = commandText[index];

    if (escaping) {
      escaping = false;
      continue;
    }
    if (inSingleQuote) {
      if (char == "'") {
        inSingleQuote = false;
      }
      continue;
    }
    if (inDoubleQuote) {
      if (char == '\\') {
        escaping = true;
        continue;
      }
      if (char == '"') {
        inDoubleQuote = false;
      }
      continue;
    }

    if (char == "'") {
      inSingleQuote = true;
      continue;
    }
    if (char == '"') {
      inDoubleQuote = true;
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
              next == '\\' ||
              next == ';' ||
              next == '&' ||
              next == '|' ||
              next == '>' ||
              next == '<' ||
              next == '`')) {
        escaping = true;
        continue;
      }
    }
    if (char == '\n' ||
        char == ';' ||
        char == '&' ||
        char == '|' ||
        char == '>' ||
        char == '<' ||
        char == '`') {
      return true;
    }
  }

  return false;
}

class _PipeCommand {
  const _PipeCommand({required this.leftCommand, required this.rightCommand});

  final String leftCommand;
  final String rightCommand;
}

_PipeCommand? _splitSinglePipeCommand(String commandText) {
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var escaping = false;
  int? pipeIndex;

  for (var index = 0; index < commandText.length; index++) {
    final char = commandText[index];

    if (escaping) {
      escaping = false;
      continue;
    }
    if (inSingleQuote) {
      if (char == "'") {
        inSingleQuote = false;
      }
      continue;
    }
    if (inDoubleQuote) {
      if (char == '\\') {
        escaping = true;
        continue;
      }
      if (char == '"') {
        inDoubleQuote = false;
      }
      continue;
    }

    if (char == "'") {
      inSingleQuote = true;
      continue;
    }
    if (char == '"') {
      inDoubleQuote = true;
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
              next == '\\' ||
              next == ';' ||
              next == '&' ||
              next == '|' ||
              next == '>' ||
              next == '<' ||
              next == '`')) {
        escaping = true;
        continue;
      }
    }
    if (char == '\n' ||
        char == ';' ||
        char == '&' ||
        char == '>' ||
        char == '<' ||
        char == '`') {
      return null;
    }
    if (char != '|') {
      continue;
    }
    final previous = index > 0 ? commandText[index - 1] : null;
    final next = index + 1 < commandText.length ? commandText[index + 1] : null;
    if (previous == '|' || next == '|') {
      return null;
    }
    if (pipeIndex != null) {
      return null;
    }
    pipeIndex = index;
  }

  if (pipeIndex == null) {
    return null;
  }

  final leftCommand = commandText.substring(0, pipeIndex).trim();
  final rightCommand = commandText.substring(pipeIndex + 1).trim();
  if (leftCommand.isEmpty || rightCommand.isEmpty) {
    return null;
  }

  return _PipeCommand(leftCommand: leftCommand, rightCommand: rightCommand);
}

List<String>? _tokenizeShellCommand(String commandText) {
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

  for (var index = 0; index < commandText.length; index++) {
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

String _fileNameForPath(String path) {
  final normalizedPath = path.replaceAll('\\', '/');
  final segments = normalizedPath
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  return segments.isEmpty ? path : segments.last;
}

String _commandName(String executableToken) {
  final normalizedToken = executableToken.replaceAll('\\', '/');
  final segments = normalizedToken
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  final fileName = segments.isEmpty ? executableToken : segments.last;
  return fileName.toLowerCase().replaceFirst(RegExp(r'\.exe$'), '');
}

String? _unwrapPowerShellWrappedCommand(List<String> tokens) {
  for (var index = 1; index < tokens.length; index++) {
    final token = tokens[index].toLowerCase();
    if (token == '-command' || token == '-c') {
      final commandTokens = tokens.sublist(index + 1);
      if (commandTokens.isEmpty) {
        return null;
      }
      return commandTokens.join(' ').trim();
    }
  }
  return null;
}

bool _isPowerShellNamedParameter(String token, String parameterName) {
  return token == '-$parameterName' || token.startsWith('-$parameterName:');
}

_ResolvedPowerShellParameter? _resolvePowerShellParameterValue({
  required List<String> tokens,
  required int index,
  required String parameterName,
}) {
  final token = tokens[index];
  final prefix = '-$parameterName:';
  if (token.toLowerCase().startsWith(prefix)) {
    final value = token.substring(prefix.length);
    if (value.isEmpty) {
      return null;
    }
    return _ResolvedPowerShellParameter(value: value, nextIndex: index + 1);
  }
  if (index + 1 >= tokens.length) {
    return null;
  }
  return _ResolvedPowerShellParameter(
    value: tokens[index + 1],
    nextIndex: index + 2,
  );
}
