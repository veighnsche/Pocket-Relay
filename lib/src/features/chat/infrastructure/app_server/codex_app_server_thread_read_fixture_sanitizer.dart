class CodexAppServerThreadReadFixtureSanitizer {
  CodexAppServerThreadReadFixtureSanitizer();

  final Map<String, String> _stableValueMap = <String, String>{};
  final Map<String, int> _categoryCounts = <String, int>{};

  Map<String, dynamic> sanitize(Object? payload) {
    if (payload is! Map) {
      throw ArgumentError.value(
        payload,
        'payload',
        'thread/read fixture payload must be a JSON object.',
      );
    }
    return _sanitizeMap(
      Map<String, dynamic>.from(payload),
      path: const <String>[],
    );
  }

  Map<String, dynamic> _sanitizeMap(
    Map<String, dynamic> input, {
    required List<String> path,
  }) {
    final sanitized = <String, dynamic>{};
    for (final entry in input.entries) {
      sanitized[entry.key] = _sanitizeValue(
        entry.value,
        path: <String>[...path, entry.key],
      );
    }
    return sanitized;
  }

  List<dynamic> _sanitizeList(
    List<dynamic> input, {
    required List<String> path,
  }) {
    return input
        .map((value) => _sanitizeValue(value, path: <String>[...path, '[]']))
        .toList(growable: false);
  }

  Object? _sanitizeValue(Object? value, {required List<String> path}) {
    return switch (value) {
      final Map<dynamic, dynamic> map => _sanitizeMap(
        Map<String, dynamic>.from(map),
        path: path,
      ),
      final List<dynamic> list => _sanitizeList(list, path: path),
      final String string => _sanitizeString(string, path: path),
      _ => value,
    };
  }

  String _sanitizeString(String value, {required List<String> path}) {
    if (value.isEmpty) {
      return value;
    }

    final key = path.isEmpty ? '' : path.last;
    if (_isStableProtocolValueKey(key)) {
      return value;
    }

    final category = _redactionCategory(path);
    final mapKey = '$category::$value';
    final existing = _stableValueMap[mapKey];
    if (existing != null) {
      return existing;
    }

    final nextIndex = (_categoryCounts[category] ?? 0) + 1;
    _categoryCounts[category] = nextIndex;
    final replacement = '<${category}_$nextIndex>';
    _stableValueMap[mapKey] = replacement;
    return replacement;
  }

  bool _isStableProtocolValueKey(String key) {
    return switch (key) {
      'type' ||
      'status' ||
      'kind' ||
      'model' ||
      'modelProvider' ||
      'stopReason' ||
      'reasoningEffort' ||
      'reasoning_effort' ||
      'effort' ||
      'approvalPolicy' ||
      'sandbox' ||
      'sourceKind' => true,
      _ => false,
    };
  }

  String _redactionCategory(List<String> path) {
    final key = path.isEmpty ? '' : path.last;
    if (_isThreadIdPath(path)) {
      return 'thread';
    }
    if (_isTurnIdPath(path)) {
      return 'turn';
    }
    if (_isItemIdPath(path)) {
      return 'item';
    }
    if (_isRequestIdKey(key)) {
      return 'request';
    }
    return switch (key) {
      'cwd' => 'cwd',
      'path' => 'path',
      'preview' => 'preview',
      'name' => 'name',
      'text' => 'text',
      'title' => 'title',
      'summary' => 'summary',
      'message' => 'message',
      'detail' => 'detail',
      'reason' => 'reason',
      'prompt' => 'prompt',
      'query' => 'query',
      'command' => 'command',
      'review' => 'review',
      'revisedPrompt' => 'prompt',
      'agentNickname' => 'nickname',
      'role' || 'agentRole' => 'role',
      'providerThreadId' => 'thread',
      _ => 'string',
    };
  }

  bool _isThreadIdPath(List<String> path) {
    final key = path.isEmpty ? '' : path.last;
    if (key == 'threadId' || key == 'providerThreadId') {
      return true;
    }
    if (key != 'id') {
      return false;
    }
    final parent = _nearestNamedParent(path);
    return parent == 'thread' || parent == 'response';
  }

  bool _isTurnIdPath(List<String> path) {
    final key = path.isEmpty ? '' : path.last;
    if (key == 'turnId') {
      return true;
    }
    if (key != 'id') {
      return false;
    }
    final parent = _nearestNamedParent(path);
    return parent == 'turns' || parent == 'turn';
  }

  bool _isItemIdPath(List<String> path) {
    final key = path.isEmpty ? '' : path.last;
    if (key == 'itemId') {
      return true;
    }
    if (key != 'id') {
      return false;
    }
    final parent = _nearestNamedParent(path);
    return parent == 'items' || parent == 'item';
  }

  bool _isRequestIdKey(String key) {
    return key == 'requestId';
  }

  String _nearestNamedParent(List<String> path) {
    for (var index = path.length - 2; index >= 0; index -= 1) {
      final segment = path[index];
      if (segment != '[]') {
        return segment;
      }
    }
    return '';
  }
}
