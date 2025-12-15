import 'package:aimi_app/services/caching_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CachingService', () {
    late CachingService service;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      service = CachingService();
    });

    // =========================================================================
    // Basic Operations Tests
    // =========================================================================
    group('Basic Operations', () {
      test('saveData and getData work with cacheKey', () async {
        await service.saveData(cacheKey: CacheKey.trendingAnime, data: ['anime1', 'anime2']);

        final data = await service.getData(cacheKey: CacheKey.trendingAnime);

        expect(data, isA<List>());
        expect((data as List).length, 2);
      });

      test('saveData and getData work with dynamicKey', () async {
        await service.saveData(dynamicKey: 'custom_key_123', data: {'id': 123, 'name': 'Test'});

        final data = await service.getData(dynamicKey: 'custom_key_123');

        expect(data, isA<Map>());
        expect(data['id'], 123);
      });

      test('getData returns null for non-existent key', () async {
        final data = await service.getData(dynamicKey: 'non_existent');
        expect(data, isNull);
      });

      test('removeData removes cached data', () async {
        await service.saveData(dynamicKey: 'to_remove', data: 'test data');

        await service.removeData(dynamicKey: 'to_remove');

        final data = await service.getData(dynamicKey: 'to_remove');
        expect(data, isNull);
      });
    });

    // =========================================================================
    // Expiration Tests
    // =========================================================================
    group('Expiration', () {
      test('data without expiration persists', () async {
        await service.saveData(dynamicKey: 'no_expiry', data: 'persistent');

        final data = await service.getData(dynamicKey: 'no_expiry');
        expect(data, 'persistent');
      });

      test('data with future expiration is returned', () async {
        await service.saveData(dynamicKey: 'future_expiry', data: 'valid', expiresIn: const Duration(hours: 1));

        final data = await service.getData(dynamicKey: 'future_expiry');
        expect(data, 'valid');
      });

      // Note: Testing expired data is tricky without mocking DateTime.now()
      // In a real test suite, you might use package:clock for this
    });

    // =========================================================================
    // Provider Namespacing Tests
    // =========================================================================
    group('Provider Namespacing', () {
      test('same key with different providers are separate', () async {
        await service.saveData(dynamicKey: 'shared_key', data: 'provider_a_data', providerName: 'ProviderA');

        await service.saveData(dynamicKey: 'shared_key', data: 'provider_b_data', providerName: 'ProviderB');

        final dataA = await service.getData(dynamicKey: 'shared_key', providerName: 'ProviderA');
        final dataB = await service.getData(dynamicKey: 'shared_key', providerName: 'ProviderB');

        expect(dataA, 'provider_a_data');
        expect(dataB, 'provider_b_data');
      });

      test('key without provider is separate from key with provider', () async {
        await service.saveData(dynamicKey: 'test_key', data: 'no_provider');

        await service.saveData(dynamicKey: 'test_key', data: 'with_provider', providerName: 'TestProvider');

        final noProvider = await service.getData(dynamicKey: 'test_key');
        final withProvider = await service.getData(dynamicKey: 'test_key', providerName: 'TestProvider');

        expect(noProvider, 'no_provider');
        expect(withProvider, 'with_provider');
      });

      test('removeData respects provider namespace', () async {
        await service.saveData(dynamicKey: 'remove_test', data: 'keep', providerName: 'ProviderA');

        await service.saveData(dynamicKey: 'remove_test', data: 'remove', providerName: 'ProviderB');

        await service.removeData(dynamicKey: 'remove_test', providerName: 'ProviderB');

        final dataA = await service.getData(dynamicKey: 'remove_test', providerName: 'ProviderA');
        final dataB = await service.getData(dynamicKey: 'remove_test', providerName: 'ProviderB');

        expect(dataA, 'keep');
        expect(dataB, isNull);
      });
    });

    // =========================================================================
    // Complex Data Types Tests
    // =========================================================================
    group('Complex Data Types', () {
      test('handles nested objects', () async {
        final complexData = {
          'anime': {
            'id': 1,
            'title': {'english': 'Test', 'romaji': 'Tesuto'},
            'genres': ['Action', 'Adventure'],
          },
          'episodes': [
            {'number': 1, 'title': 'Episode 1'},
            {'number': 2, 'title': 'Episode 2'},
          ],
        };

        await service.saveData(dynamicKey: 'complex', data: complexData);

        final retrieved = await service.getData(dynamicKey: 'complex');

        expect(retrieved['anime']['title']['english'], 'Test');
        expect(retrieved['episodes'].length, 2);
      });

      test('handles empty lists and maps', () async {
        await service.saveData(dynamicKey: 'empty_list', data: []);
        await service.saveData(dynamicKey: 'empty_map', data: {});

        final list = await service.getData(dynamicKey: 'empty_list');
        final map = await service.getData(dynamicKey: 'empty_map');

        expect(list, isEmpty);
        expect(map, isEmpty);
      });

      test('handles boolean and numeric values', () async {
        await service.saveData(dynamicKey: 'bool', data: true);
        await service.saveData(dynamicKey: 'int', data: 42);
        await service.saveData(dynamicKey: 'double', data: 3.14);

        expect(await service.getData(dynamicKey: 'bool'), true);
        expect(await service.getData(dynamicKey: 'int'), 42);
        expect(await service.getData(dynamicKey: 'double'), 3.14);
      });
    });

    // =========================================================================
    // CacheKey Enum Tests
    // =========================================================================
    group('CacheKey Enum', () {
      test('all cache keys work correctly', () async {
        for (final key in CacheKey.values) {
          await service.saveData(cacheKey: key, data: key.name);
          final data = await service.getData(cacheKey: key);
          expect(data, key.name);
        }
      });
    });
  });
}
