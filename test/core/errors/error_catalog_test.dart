import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';

void main() {
  test('pocket error catalog codes are unique and carry meanings', () {
    final definitions = PocketErrorCatalog.allDefinitions;

    expect(definitions, isNotEmpty);
    expect(
      definitions.map((definition) => definition.code).toSet().length,
      definitions.length,
    );

    for (final definition in definitions) {
      expect(definition.code, startsWith('PR-'));
      expect(definition.meaning.trim(), isNotEmpty);
    }
  });

  test('pocket error catalog can look up a known code', () {
    final definition = PocketErrorCatalog.lookup('PR-CONN-2105');

    expect(definition, isNotNull);
    expect(definition, PocketErrorCatalog.connectionReconnectServerStopped);
  });
}
