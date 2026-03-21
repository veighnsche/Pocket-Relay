import 'codex_app_server_models.dart';

/// Decodes the upstream `thread/read` response shape into the current app
/// thread model.
///
/// Phase 0 intentionally hardens this boundary before larger history-restoration
/// refactors. The app-server reference currently shows two envelope variants:
///
/// - nested: `{ "thread": { ...thread fields..., "turns": [...] } }`
/// - flat: `{ "threadId": "...", "turns": [...] }`
///
/// This decoder accepts both forms so the rest of the app can work against one
/// seam while the full historical contract is still being verified.
class CodexAppServerThreadReadDecoder {
  const CodexAppServerThreadReadDecoder();

  CodexAppServerThread decodeResponse(
    Object? response, {
    required String fallbackThreadId,
  }) {
    final payload = _requireObject(response, 'thread/read response');
    final rawThread = _extractThreadPayload(
      payload,
      fallbackThreadId: fallbackThreadId,
    );
    if (rawThread == null) {
      throw const CodexAppServerException(
        'thread/read response did not include a thread object.',
      );
    }
    return _decodeThread(rawThread, fallbackThreadId: fallbackThreadId);
  }

  Map<String, dynamic>? _extractThreadPayload(
    Map<String, dynamic> payload, {
    required String fallbackThreadId,
  }) {
    final nestedThread = _asObject(payload['thread']);
    if (nestedThread != null) {
      return <String, dynamic>{
        ...nestedThread,
        if (!nestedThread.containsKey('id') &&
            _asString(payload['threadId']) != null)
          'id': _asString(payload['threadId']),
        if (!nestedThread.containsKey('turns') && payload['turns'] is List)
          'turns': payload['turns'],
      };
    }

    final directThreadId =
        _asString(payload['id']) ??
        _asString(payload['threadId']) ??
        _asString(fallbackThreadId);
    if (directThreadId == null || directThreadId.isEmpty) {
      return null;
    }

    if (!_looksLikeFlatThreadReadPayload(payload)) {
      return null;
    }

    return <String, dynamic>{...payload, 'id': directThreadId};
  }

  bool _looksLikeFlatThreadReadPayload(Map<String, dynamic> payload) {
    return payload['turns'] is List ||
        payload.containsKey('threadId') ||
        payload.containsKey('id') ||
        payload.containsKey('preview') ||
        payload.containsKey('cwd') ||
        payload.containsKey('name');
  }

  CodexAppServerThread _decodeThread(
    Map<String, dynamic> thread, {
    required String fallbackThreadId,
  }) {
    final threadId =
        _asString(thread['id']) ??
        _asString(thread['threadId']) ??
        _asString(fallbackThreadId) ??
        '';
    if (threadId.isEmpty) {
      throw const CodexAppServerException(
        'thread/read response did not include a thread id.',
      );
    }

    return CodexAppServerThread(
      id: threadId,
      preview: _asString(thread['preview']) ?? '',
      ephemeral: thread['ephemeral'] as bool? ?? false,
      modelProvider: _asString(thread['modelProvider']) ?? '',
      createdAt: _parseUnixTimestamp(thread['createdAt']),
      updatedAt: _parseUnixTimestamp(thread['updatedAt']),
      path: _asString(thread['path']),
      cwd: _asString(thread['cwd']),
      promptCount:
          _asInt(thread['promptCount']) ??
          _countUserPromptItems(thread['turns']),
      name: _asString(thread['name']),
      sourceKind: _sourceKind(thread['source']),
      agentNickname: _asString(thread['agentNickname']),
      agentRole: _asString(thread['agentRole']),
      turns: _asObjectList(thread['turns']) ?? const <Map<String, dynamic>>[],
    );
  }

  Map<String, dynamic>? _asObject(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Map<String, dynamic> _requireObject(Object? value, String label) {
    final object = _asObject(value);
    if (object == null) {
      throw CodexAppServerException('$label was not an object.');
    }
    return object;
  }

  List<Map<String, dynamic>>? _asObjectList(Object? value) {
    if (value is! List) {
      return null;
    }

    final objects = value
        .map(_asObject)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    return objects.isEmpty ? null : objects;
  }

  String? _asString(Object? value) {
    return value is String ? value : null;
  }

  int? _asInt(Object? value) {
    return value is num ? value.toInt() : null;
  }

  String? _sourceKind(Object? raw) {
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }

    final object = _asObject(raw);
    return _asString(object?['kind']) ?? _asString(object?['type']);
  }

  DateTime? _parseUnixTimestamp(Object? raw) {
    if (raw is! num) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(
      raw.toInt() * 1000,
      isUtc: true,
    ).toLocal();
  }

  int? _countUserPromptItems(Object? rawTurns) {
    if (rawTurns is! List) {
      return null;
    }

    var count = 0;
    for (final turn in rawTurns.whereType<Map>()) {
      final items = turn['items'];
      if (items is! List) {
        continue;
      }
      for (final item in items.whereType<Map>()) {
        if (_asString(item['type']) == 'userMessage') {
          count += 1;
        }
      }
    }
    return count;
  }
}
