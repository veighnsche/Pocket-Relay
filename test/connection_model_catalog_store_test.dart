import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferencesAsyncPlatform? originalAsyncPlatform;

  setUp(() {
    originalAsyncPlatform = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = originalAsyncPlatform;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('memory store saves, loads, and deletes per connection', () async {
    final store = MemoryConnectionModelCatalogStore();
    final catalog = _catalog(
      connectionId: 'conn_primary',
      fetchedAt: DateTime.utc(2026, 3, 22, 12),
    );

    await store.save(catalog);

    expect(await store.load('conn_primary'), catalog);
    expect(await store.load('conn_secondary'), isNull);

    await store.delete('conn_primary');

    expect(await store.load('conn_primary'), isNull);
  });

  test('secure store round-trips the persisted catalog', () async {
    final preferences = SharedPreferencesAsync();
    final store = SecureConnectionModelCatalogStore(preferences: preferences);
    final catalog = _catalog(
      connectionId: 'conn_primary',
      fetchedAt: DateTime.utc(2026, 3, 22, 12, 34, 56),
    );

    await store.save(catalog);

    expect(
      await preferences.getString(
        'pocket_relay.connection.conn_primary.model_catalog',
      ),
      isNotNull,
    );
    expect(await store.load('conn_primary'), catalog);
  });

  test('secure store delete removes the persisted catalog entry', () async {
    final preferences = SharedPreferencesAsync();
    final store = SecureConnectionModelCatalogStore(preferences: preferences);
    final catalog = _catalog(
      connectionId: 'conn_primary',
      fetchedAt: DateTime.utc(2026, 3, 22, 12),
    );

    await store.save(catalog);
    await store.delete('conn_primary');

    expect(await store.load('conn_primary'), isNull);
    expect(
      await preferences.getString(
        'pocket_relay.connection.conn_primary.model_catalog',
      ),
      isNull,
    );
  });

  test(
    'secure store ignores corrupted entries with mismatched connection ids',
    () async {
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        'pocket_relay.connection.conn_primary.model_catalog',
        '{"connectionId":"conn_secondary","fetchedAt":"2026-03-22T12:00:00.000Z","models":[]}',
      );
      final store = SecureConnectionModelCatalogStore(preferences: preferences);

      expect(await store.load('conn_primary'), isNull);
    },
  );
}

ConnectionModelCatalog _catalog({
  required String connectionId,
  required DateTime fetchedAt,
}) {
  return ConnectionModelCatalog(
    connectionId: connectionId,
    fetchedAt: fetchedAt,
    models: <ConnectionAvailableModel>[
      ConnectionAvailableModel(
        id: 'preset_gpt_54',
        model: 'gpt-5.4',
        displayName: 'GPT-5.4',
        description: 'Latest frontier agentic coding model.',
        hidden: false,
        supportedReasoningEfforts:
            <ConnectionAvailableModelReasoningEffortOption>[
              const ConnectionAvailableModelReasoningEffortOption(
                reasoningEffort: CodexReasoningEffort.medium,
                description: 'Balanced default for general work.',
              ),
              const ConnectionAvailableModelReasoningEffortOption(
                reasoningEffort: CodexReasoningEffort.high,
                description: 'Spend more reasoning on harder tasks.',
              ),
            ],
        defaultReasoningEffort: CodexReasoningEffort.medium,
        inputModalities: const <String>['text'],
        supportsPersonality: true,
        isDefault: true,
        upgrade: 'gpt-5.5',
        upgradeInfo: const ConnectionAvailableModelUpgradeInfo(
          model: 'gpt-5.5',
          upgradeCopy: 'Upgrade available',
          modelLink: 'https://example.com/models/gpt-5.5',
          migrationMarkdown: 'Use the newer model.',
        ),
        availabilityNuxMessage: 'Enable billing to access this model.',
      ),
    ],
  );
}
