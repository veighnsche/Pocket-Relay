part of 'codex_app_server_request_api.dart';

Future<CodexAppServerModelListPage> _listModels(
  CodexAppServerConnection connection, {
  String? cursor,
  int? limit,
  bool? includeHidden,
}) async {
  connection.requireConnected();

  final normalizedCursor = cursor?.trim();
  final params = <String, Object?>{};
  if (normalizedCursor != null && normalizedCursor.isNotEmpty) {
    params['cursor'] = normalizedCursor;
  }
  if (limit != null) {
    params['limit'] = limit;
  }
  if (includeHidden != null) {
    params['includeHidden'] = includeHidden;
  }

  final response = await connection.sendRequest('model/list', params);
  final payload = _requireObject(response, 'model/list response');
  final data = payload['data'];
  if (data is! List) {
    throw const CodexAppServerException(
      'model/list response did not include a model list.',
    );
  }

  return CodexAppServerModelListPage(
    models: data
        .map(_asModel)
        .whereType<CodexAppServerModel>()
        .toList(growable: false),
    nextCursor: _asString(payload['nextCursor']),
  );
}
