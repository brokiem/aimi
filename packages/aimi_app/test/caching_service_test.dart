import 'package:aimi_app/services/caching_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('CachingService (via FakeCachingService)', () {
    late FakeCachingService service;

    setUp(() {
      service = FakeCachingService();
    });

    tearDown(() {
      service.clear();
    });

    // =========================================================================
    // Simple Key Operations Tests
    // =========================================================================
    group('Simple Key Operations', () {
      test('save and get work with CacheKey', () async {
        await service.save(key: CacheKey.trendingAnime, data: ['anime1', 'anime2']);

        final data = await service.get(key: CacheKey.trendingAnime);

        expect(data, isA<List>());
        expect((data as List).length, 2);
      });

      test('remove works with CacheKey', () async {
        await service.save(key: CacheKey.trendingAnime, data: 'test');
        await service.remove(key: CacheKey.trendingAnime);

        final data = await service.get(key: CacheKey.trendingAnime);
        expect(data, isNull);
      });

      test('data with expiration works', () async {
        await service.save(key: CacheKey.trendingAnime, data: 'valid', expiresIn: const Duration(hours: 1));

        final data = await service.get(key: CacheKey.trendingAnime);
        expect(data, 'valid');
      });
    });

    // =========================================================================
    // Provider Namespacing Tests
    // =========================================================================
    group('Provider Namespacing', () {
      test('same key with different providers are separate', () async {
        await service.save(key: CacheKey.trendingAnime, data: 'provider_a_data', providerName: 'ProviderA');
        await service.save(key: CacheKey.trendingAnime, data: 'provider_b_data', providerName: 'ProviderB');

        final dataA = await service.get(key: CacheKey.trendingAnime, providerName: 'ProviderA');
        final dataB = await service.get(key: CacheKey.trendingAnime, providerName: 'ProviderB');

        expect(dataA, 'provider_a_data');
        expect(dataB, 'provider_b_data');
      });

      test('key without provider is separate from key with provider', () async {
        await service.save(key: CacheKey.trendingAnime, data: 'no_provider');
        await service.save(key: CacheKey.trendingAnime, data: 'with_provider', providerName: 'TestProvider');

        final noProvider = await service.get(key: CacheKey.trendingAnime);
        final withProvider = await service.get(key: CacheKey.trendingAnime, providerName: 'TestProvider');

        expect(noProvider, 'no_provider');
        expect(withProvider, 'with_provider');
      });
    });

    // =========================================================================
    // CacheKey Enum Tests
    // =========================================================================
    group('CacheKey Enum', () {
      test('all cache keys work correctly', () async {
        for (final cacheKey in CacheKey.values) {
          await service.save(key: cacheKey, data: cacheKey.name);
          final data = await service.get(key: cacheKey);
          expect(data, cacheKey.name);
        }
      });
    });
  });
}
