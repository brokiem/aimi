import 'package:aimi_app/models/anime_episode.dart';
import 'package:aimi_app/models/streaming_anime_result.dart';
import 'package:aimi_app/services/streaming_service.dart';
import 'package:aimi_lib/aimi_lib.dart' as lib;
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('StreamingService', () {
    late StreamingService service;
    late FakeStreamProvider provider;

    setUp(() {
      service = StreamingService();
      provider = FakeStreamProvider('TestProvider');
    });

    // =========================================================================
    // searchWithProvider Tests
    // =========================================================================
    group('searchWithProvider', () {
      test('returns search results for matching query', () async {
        provider.setSearchResults([
          lib.StreamableAnime(id: '1', title: 'Test Anime', availableEpisodes: 12),
          lib.StreamableAnime(id: '2', title: 'Test Series', availableEpisodes: 24),
        ]);

        final anime = TestAnimeFactory.createAnime(englishTitle: 'Test', romajiTitle: 'Tesuto');

        final results = await service.searchWithProvider(provider, anime);

        expect(results, hasLength(2));
        expect(results.first.title, 'Test Anime');
      });

      test('returns empty list when no matches', () async {
        provider.setSearchResults([]);

        final anime = TestAnimeFactory.createAnime(englishTitle: 'NonExistent', romajiTitle: 'NonExistent');

        final results = await service.searchWithProvider(provider, anime);

        expect(results, isEmpty);
      });

      test('tries romaji title then english title', () async {
        // Set up search results that would match the romaji title
        provider.setSearchResults([lib.StreamableAnime(id: '1', title: 'Romaji Title Match', availableEpisodes: 12)]);

        final anime = TestAnimeFactory.createAnime(
          englishTitle: 'English Title',
          romajiTitle: 'Romaji Title', // This will be searched first
        );

        final results = await service.searchWithProvider(provider, anime);

        // The service searches with romaji first, then english
        // Our fake provider matches on title containing the query
        // So "Romaji Title Match" should match "Romaji Title"
        expect(results, isNotEmpty);
        expect(results.first.title, contains('Romaji'));
      });

      test('handles provider errors gracefully', () async {
        provider.shouldThrow = true;

        final anime = TestAnimeFactory.createAnime();

        final results = await service.searchWithProvider(provider, anime);

        expect(results, isEmpty);
      });

      test('maps StreamableAnime to StreamingAnimeResult correctly', () async {
        provider.setSearchResults([lib.StreamableAnime(id: 'abc123', title: 'My Anime', availableEpisodes: 24)]);

        final anime = TestAnimeFactory.createAnime(englishTitle: 'My');

        final results = await service.searchWithProvider(provider, anime);

        expect(results.first.id, 'abc123');
        expect(results.first.title, 'My Anime');
        expect(results.first.availableEpisodes, 24);
      });
    });

    // =========================================================================
    // getEpisodesWithProvider Tests
    // =========================================================================
    group('getEpisodesWithProvider', () {
      test('returns episodes for anime', () async {
        provider.setEpisodes('anime-1', [
          lib.Episode(animeId: 'anime-1', number: '1', sourceId: 'ep-1'),
          lib.Episode(animeId: 'anime-1', number: '2', sourceId: 'ep-2'),
        ]);

        final streamingAnime = StreamingAnimeResult(id: 'anime-1', title: 'Test Anime', availableEpisodes: 2);

        final episodes = await service.getEpisodesWithProvider(provider, streamingAnime);

        expect(episodes, hasLength(2));
        expect(episodes.first.number, '1');
        expect(episodes.last.number, '2');
      });

      test('returns empty list when no episodes', () async {
        provider.setEpisodes('anime-1', []);

        final streamingAnime = StreamingAnimeResult(id: 'anime-1', title: 'Test Anime', availableEpisodes: 0);

        final episodes = await service.getEpisodesWithProvider(provider, streamingAnime);

        expect(episodes, isEmpty);
      });

      test('maps Episode to AnimeEpisode correctly', () async {
        provider.setEpisodes('anime-1', [
          lib.Episode(
            animeId: 'anime-1',
            number: '5',
            sourceId: 'source-123',
            title: 'Episode Title',
            thumbnail: 'https://example.com/thumb.jpg',
            duration: 1440,
          ),
        ]);

        final streamingAnime = StreamingAnimeResult(id: 'anime-1', title: 'Test', availableEpisodes: 1);

        final episodes = await service.getEpisodesWithProvider(provider, streamingAnime);

        final ep = episodes.first;
        expect(ep.id, 'source-123');
        expect(ep.animeId, 'anime-1');
        expect(ep.number, '5');
        expect(ep.title, 'Episode Title');
        expect(ep.thumbnail, 'https://example.com/thumb.jpg');
        expect(ep.duration, 1440);
      });

      test('throws when provider fails', () async {
        provider.shouldThrow = true;

        final streamingAnime = StreamingAnimeResult(id: 'anime-1', title: 'Test', availableEpisodes: 1);

        expect(() => service.getEpisodesWithProvider(provider, streamingAnime), throwsException);
      });
    });

    // =========================================================================
    // getSources Tests
    // =========================================================================
    group('getSources', () {
      test('returns sources for episode', () async {
        provider.setSources('ep-1', [
          lib.StreamSource(url: 'https://example.com/1080.m3u8', quality: '1080p', type: 'hls'),
          lib.StreamSource(url: 'https://example.com/720.m3u8', quality: '720p', type: 'hls'),
        ]);

        final episode = AnimeEpisode(id: 'ep-1', animeId: 'anime-1', number: '1');

        final sources = await service.getSources(provider, episode);

        expect(sources, hasLength(2));
        expect(sources.first.quality, '1080p');
      });

      test('returns empty list when no sources', () async {
        provider.setSources('ep-1', []);

        final episode = AnimeEpisode(id: 'ep-1', animeId: 'anime-1', number: '1');

        final sources = await service.getSources(provider, episode);

        expect(sources, isEmpty);
      });

      test('maps StreamSource to StreamingSource correctly', () async {
        provider.setSources('ep-1', [
          lib.StreamSource(
            url: 'https://cdn.example.com/video.m3u8',
            quality: '1080p',
            type: 'hls',
            subtitles: [
              lib.Subtitle(url: 'https://cdn.example.com/en.vtt', language: 'en', label: 'English', format: 'vtt'),
            ],
          ),
        ]);

        final episode = AnimeEpisode(id: 'ep-1', animeId: 'anime-1', number: '1');

        final sources = await service.getSources(provider, episode);

        final source = sources.first;
        expect(source.url, 'https://cdn.example.com/video.m3u8');
        expect(source.quality, '1080p');
        expect(source.isM3U8, isTrue);
        expect(source.subtitles, hasLength(1));
      });

      test('isM3U8 is false for non-hls types', () async {
        provider.setSources('ep-1', [
          lib.StreamSource(url: 'https://example.com/video.mp4', quality: '720p', type: 'mp4'),
        ]);

        final episode = AnimeEpisode(id: 'ep-1', animeId: 'anime-1', number: '1');

        final sources = await service.getSources(provider, episode);

        expect(sources.first.isM3U8, isFalse);
      });

      test('throws when provider fails', () async {
        provider.shouldThrow = true;

        final episode = AnimeEpisode(id: 'ep-1', animeId: 'anime-1', number: '1');

        expect(() => service.getSources(provider, episode), throwsException);
      });
    });

    // =========================================================================
    // In-Memory Caching Tests
    // =========================================================================
    group('In-Memory Caching', () {
      test('setCachedEpisodes and getCachedEpisodes work', () {
        final episodes = [
          TestAnimeFactory.createEpisode(id: 'ep-1', number: '1'),
          TestAnimeFactory.createEpisode(id: 'ep-2', number: '2'),
        ];

        service.setCachedEpisodes(123, 'TestProvider', episodes);

        final cached = service.getCachedEpisodes(123, 'TestProvider');

        expect(cached, isNotNull);
        expect(cached, hasLength(2));
      });

      test('getCachedEpisodes returns null for uncached', () {
        final cached = service.getCachedEpisodes(999, 'UnknownProvider');
        expect(cached, isNull);
      });

      test('different providers have separate caches', () {
        final episodesA = [TestAnimeFactory.createEpisode(id: 'ep-a')];
        final episodesB = [TestAnimeFactory.createEpisode(id: 'ep-b')];

        service.setCachedEpisodes(1, 'ProviderA', episodesA);
        service.setCachedEpisodes(1, 'ProviderB', episodesB);

        expect(service.getCachedEpisodes(1, 'ProviderA')?.first.id, 'ep-a');
        expect(service.getCachedEpisodes(1, 'ProviderB')?.first.id, 'ep-b');
      });

      test('setCachedSelectedAnime and getCachedSelectedAnime work', () {
        final result = TestAnimeFactory.createStreamingResult(id: 'stream-1', title: 'My Anime');

        service.setCachedSelectedAnime(123, 'TestProvider', result);

        final cached = service.getCachedSelectedAnime(123, 'TestProvider');

        expect(cached, isNotNull);
        expect(cached?.title, 'My Anime');
      });

      test('setCachedSelectedAnime with null removes cache', () {
        final result = TestAnimeFactory.createStreamingResult();

        service.setCachedSelectedAnime(1, 'Provider', result);
        expect(service.getCachedSelectedAnime(1, 'Provider'), isNotNull);

        service.setCachedSelectedAnime(1, 'Provider', null);
        expect(service.getCachedSelectedAnime(1, 'Provider'), isNull);
      });
    });
  });
}
