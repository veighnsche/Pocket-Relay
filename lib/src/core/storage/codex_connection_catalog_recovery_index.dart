part of 'codex_connection_catalog_recovery.dart';

List<String> _decodeCatalogIndex(String rawIndex) {
  final decoded = jsonDecode(rawIndex);
  if (decoded is! Map<String, dynamic>) {
    return const <String>[];
  }

  final rawOrderedConnectionIds = decoded['orderedConnectionIds'];
  if (rawOrderedConnectionIds is! List) {
    return const <String>[];
  }

  final orderedConnectionIds = <String>[];
  for (final value in rawOrderedConnectionIds) {
    if (value is! String) {
      continue;
    }
    final normalizedConnectionId = value.trim();
    if (normalizedConnectionId.isEmpty ||
        orderedConnectionIds.contains(normalizedConnectionId)) {
      continue;
    }
    orderedConnectionIds.add(normalizedConnectionId);
  }
  return orderedConnectionIds;
}
