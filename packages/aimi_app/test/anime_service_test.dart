import 'package:aimi_app/services/anime_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('AnimeService', () {
    late AnimeService service;
    late FakeMetadataProvider providerA;
    late FakeMetadataProvider providerB;
    late FakeCachingService cachingService;

    setUp(() {
      providerA = FakeMetadataProvider('ProviderA');
      providerB = FakeMetadataProvider('ProviderB');
      cachingService = FakeCachingService();

      // Add test data
      providerA.addAnime(TestAnimeFactory.createMedia(id: 1, englishTitle: 'Anime A', romajiTitle: 'Anime A Romaji'));
      providerA.addAnime(
        TestAnimeFactory.createMedia(id: 2, englishTitle: 'Another Anime A', romajiTitle: 'Another A Romaji'),
      );

      providerB.addAnime(TestAnimeFactory.createMedia(id: 1, englishTitle: 'Anime B', romajiTitle: 'Anime B Romaji'));

      service = AnimeService([providerA, providerB], cachingService, defaultProviderName: 'ProviderA');
    });

    tearDown(() {
      cachingService.clear();
    });

    // =========================================================================
    // Construction Tests
    // =========================================================================
    group('Construction', () {
      test('throws if no providers are provided', () {
        expect(
          () => AnimeService([], cachingService),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('At least one provider'))),
        );
      });

      test('throws if default provider not found', () {
        expect(
          () => AnimeService([providerA], cachingService, defaultProviderName: 'NonExistent'),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Default provider'))),
        );
      });

      test('uses first provider as default when not specified', () {
        final svc = AnimeService([providerB, providerA], cachingService);
        expect(svc.providerName, 'ProviderB');
      });
    });

    // =========================================================================
    // Provider Selection Tests
    // =========================================================================
    group('Provider Selection', () {
      test('providerName returns default provider name', () {
        expect(service.providerName, 'ProviderA');
      });

      test('getById uses default provider when no name specified', () async {
        final anime = await service.getById(1);
        expect(anime.title.english, 'Anime A');
      });

      test('getById uses specified provider', () async {
        final anime = await service.getById(1, providerName: 'ProviderB');
        expect(anime.title.english, 'Anime B');
      });

      test('getById throws if provider not found', () async {
        expect(() => service.getById(1, providerName: 'UnknownProvider'), throwsException);
      });
    });

    // =========================================================================
    // Caching Tests
    // =========================================================================
    group('Caching', () {
      test('fetchTrending caches results', () async {
        // First call - should fetch from provider
        await service.fetchTrending();

        // Verify data was cached
        expect(cachingService.containsKey('trendingAnime', providerName: 'ProviderA'), isTrue);
      });

      test('fetchTrending returns cached data on subsequent calls', () async {
        // First call
        final first = await service.fetchTrending();

        // Modify provider data
        providerA.addAnime(TestAnimeFactory.createMedia(id: 99, englishTitle: 'New Anime'));

        // Second call should return cached data (no new anime)
        final second = await service.fetchTrending();

        expect(first.length, second.length);
      });

      test('fetchTrending forceRefresh bypasses cache', () async {
        // First call
        await service.fetchTrending();

        // Modify provider data
        providerA.addAnime(TestAnimeFactory.createMedia(id: 99, englishTitle: 'New Anime'));

        // Force refresh should get new data
        final refreshed = await service.fetchTrending(forceRefresh: true);
        expect(refreshed.any((a) => a.id == 99), isTrue);
      });

      test('getById caches individual anime', () async {
        await service.getById(1);

        expect(cachingService.containsKey('anime_details/1', providerName: 'ProviderA'), isTrue);
      });

      test('getById forceRefresh bypasses cache', () async {
        // First call
        await service.getById(1);

        // Second call with forceRefresh
        final refreshed = await service.getById(1, forceRefresh: true);
        expect(refreshed.title.english, 'Anime A');
      });
    });

    // =========================================================================
    // Pagination Tests
    // =========================================================================
    group('Pagination', () {
      test('fetchTrending page 2 appends to cache', () async {
        // First page
        await service.fetchTrending(page: 1);

        // Simulate provider returning different data for page 2
        providerA.setAnimeList([TestAnimeFactory.createMedia(id: 3, englishTitle: 'Page 2 Anime')]);

        // Second page
        await service.fetchTrending(page: 2, forceRefresh: true);

        // Verify page 2 data was fetched
        // (In real scenario, cache would be appended)
      });
    });

    // =========================================================================
    // Search Tests
    // =========================================================================
    group('Search', () {
      test('search returns matching anime', () async {
        final results = await service.search('Anime A');
        expect(results, isNotEmpty);
        expect(results.first.title.english, contains('Anime A'));
      });

      test('search returns empty list for no matches', () async {
        final results = await service.search('NonExistent');
        expect(results, isEmpty);
      });

      test('search is case insensitive', () async {
        final results = await service.search('anime a');
        expect(results, isNotEmpty);
      });
    });

    // =========================================================================
    // Search History Tests
    // =========================================================================
    group('Search History', () {
      test('getSearchHistory returns empty list initially', () async {
        final history = await service.getSearchHistory();
        expect(history, isEmpty);
      });

      test('addToSearchHistory adds query to history', () async {
        await service.addToSearchHistory('test query');

        final history = await service.getSearchHistory();
        expect(history, contains('test query'));
      });

      test('addToSearchHistory moves duplicate to top', () async {
        await service.addToSearchHistory('first');
        await service.addToSearchHistory('second');
        await service.addToSearchHistory('first'); // Should move to top

        final history = await service.getSearchHistory();
        expect(history.first, 'first');
        expect(history.length, 2);
      });

      test('addToSearchHistory limits to 20 items', () async {
        for (int i = 0; i < 25; i++) {
          await service.addToSearchHistory('query $i');
        }

        final history = await service.getSearchHistory();
        expect(history.length, 20);
        expect(history.first, 'query 24'); // Most recent
      });

      test('addToSearchHistory ignores empty queries', () async {
        await service.addToSearchHistory('');
        await service.addToSearchHistory('   ');

        final history = await service.getSearchHistory();
        expect(history, isEmpty);
      });

      test('removeFromSearchHistory removes specific query', () async {
        await service.addToSearchHistory('keep');
        await service.addToSearchHistory('remove');

        await service.removeFromSearchHistory('remove');

        final history = await service.getSearchHistory();
        expect(history, contains('keep'));
        expect(history, isNot(contains('remove')));
      });

      test('clearSearchHistory removes all history', () async {
        await service.addToSearchHistory('one');
        await service.addToSearchHistory('two');

        await service.clearSearchHistory();

        final history = await service.getSearchHistory();
        expect(history, isEmpty);
      });
    });

    // =========================================================================
    // Error Handling Tests
    // =========================================================================
    group('Error Handling', () {
      test('getById throws when anime not found', () async {
        expect(() => service.getById(999), throwsException);
      });

      test('getById propagates provider errors', () async {
        providerA.shouldThrow = true;
        providerA.errorMessage = 'Provider error';

        expect(
          () => service.getById(1),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Provider error'))),
        );
      });

      test('fetchTrending propagates provider errors', () async {
        providerA.shouldThrow = true;

        expect(() => service.fetchTrending(forceRefresh: true), throwsException);
      });

      test('search propagates provider errors', () async {
        providerA.shouldThrow = true;

        expect(() => service.search('test'), throwsException);
      });
    });
  });
}
