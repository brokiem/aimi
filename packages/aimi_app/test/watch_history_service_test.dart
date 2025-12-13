import 'dart:convert';
import 'package:aimi_app/models/watch_history_entry.dart';
import 'package:aimi_app/services/caching_service.dart';
import 'package:aimi_app/services/watch_history_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake CachingService for testing
class FakeCachingService implements CachingService {
  final Map<String, dynamic> _storage = {};

  @override
  Future<void> saveData({
    CacheKey? cacheKey,
    String? dynamicKey,
    required dynamic data,
    Duration? expiresIn,
    String? providerName,
  }) async {
    final key = cacheKey?.name ?? dynamicKey!;
    final fullKey = _generateKey(key, providerName);
    _storage[fullKey] = data;
  }

  @override
  Future<dynamic> getData({
    CacheKey? cacheKey,
    String? dynamicKey,
    String? providerName,
  }) async {
    final key = cacheKey?.name ?? dynamicKey!;
    final fullKey = _generateKey(key, providerName);
    return _storage[fullKey];
  }

  @override
  Future<void> removeData({
    CacheKey? cacheKey,
    String? dynamicKey,
    String? providerName,
  }) async {
    final key = cacheKey?.name ?? dynamicKey!;
    final fullKey = _generateKey(key, providerName);
    _storage.remove(fullKey);
  }

  String _generateKey(String key, String? providerName) {
    if (providerName != null) {
      final encodedProvider = base64Encode(utf8.encode(providerName));
      return 'aimi/$encodedProvider/$key';
    }
    return 'aimi/$key';
  }

  void clear() => _storage.clear();
}

void main() {
  late WatchHistoryService service;
  late FakeCachingService fakeCachingService;

  setUp(() {
    fakeCachingService = FakeCachingService();
    service = WatchHistoryService(fakeCachingService);
  });

  tearDown(() {
    fakeCachingService.clear();
  });

  group('WatchHistoryEntry', () {
    test('fromJson and toJson are symmetric', () {
      final entry = WatchHistoryEntry(
        animeId: 123,
        episodeId: 'ep-1',
        episodeNumber: '1',
        streamProviderName: 'TestStreamProvider',
        metadataProviderName: 'TestMetadataProvider',
        positionMs: 60000,
        durationMs: 1200000,
        lastWatched: DateTime(2025, 1, 1, 12, 0, 0),
        isCompleted: false,
        animeTitle: 'Test Anime',
        episodeTitle: 'Episode 1',
      );

      final json = entry.toJson();
      final restored = WatchHistoryEntry.fromJson(json);

      expect(restored.animeId, entry.animeId);
      expect(restored.episodeId, entry.episodeId);
      expect(restored.episodeNumber, entry.episodeNumber);
      expect(restored.streamProviderName, entry.streamProviderName);
      expect(restored.metadataProviderName, entry.metadataProviderName);
      expect(restored.positionMs, entry.positionMs);
      expect(restored.durationMs, entry.durationMs);
      expect(restored.isCompleted, entry.isCompleted);
      expect(restored.animeTitle, entry.animeTitle);
      expect(restored.episodeTitle, entry.episodeTitle);
    });

    test('progress calculation is correct', () {
      final entry = WatchHistoryEntry(
        animeId: 1,
        episodeId: 'ep',
        episodeNumber: '1',
        streamProviderName: 'StreamP',
        metadataProviderName: 'MetaP',
        positionMs: 300000, // 5 minutes
        durationMs: 1200000, // 20 minutes
        lastWatched: DateTime.now(),
      );

      expect(entry.progress, closeTo(0.25, 0.001)); // 25%
    });

    test('cacheKey is formatted correctly using streamProviderName', () {
      final entry = WatchHistoryEntry(
        animeId: 123,
        episodeId: 'ep-1',
        episodeNumber: '1',
        streamProviderName: 'AnimePahe',
        metadataProviderName: 'AniList',
        positionMs: 0,
        durationMs: 0,
        lastWatched: DateTime.now(),
      );

      expect(entry.cacheKey, 'AnimePahe/123/ep-1');
    });
  });

  group('WatchHistoryService', () {
    test('saveProgress stores entry and retrieves it', () async {
      final entry = WatchHistoryEntry(
        animeId: 1,
        episodeId: 'ep-1',
        episodeNumber: '1',
        streamProviderName: 'TestStreamProvider',
        metadataProviderName: 'TestMetadataProvider',
        positionMs: 60000,
        durationMs: 1200000,
        lastWatched: DateTime.now(),
      );

      await service.saveProgress(entry);

      final retrieved = await service.getProgress(
        'TestStreamProvider',
        1,
        'ep-1',
      );
      expect(retrieved, isNotNull);
      expect(retrieved!.animeId, 1);
      expect(retrieved.episodeId, 'ep-1');
      expect(retrieved.positionMs, 60000);
    });

    test('getPosition returns Duration.zero for unknown episode', () async {
      final position = await service.getPosition('Unknown', 999, 'ep-999');
      expect(position, Duration.zero);
    });

    test('isWatched returns false for unwatched episode', () async {
      final watched = await service.isWatched('TestStreamProvider', 1, 'ep-1');
      expect(watched, false);
    });

    test('auto-marks as completed when progress > 90%', () async {
      final entry = WatchHistoryEntry(
        animeId: 1,
        episodeId: 'ep-1',
        episodeNumber: '1',
        streamProviderName: 'TestStreamProvider',
        metadataProviderName: 'TestMetadataProvider',
        positionMs: 1100000, // 91%+ of 1200000
        durationMs: 1200000,
        lastWatched: DateTime.now(),
      );

      await service.saveProgress(entry);

      final watched = await service.isWatched('TestStreamProvider', 1, 'ep-1');
      expect(watched, true);
    });

    test('markAsWatched sets completed flag', () async {
      final entry = WatchHistoryEntry(
        animeId: 1,
        episodeId: 'ep-1',
        episodeNumber: '1',
        streamProviderName: 'TestStreamProvider',
        metadataProviderName: 'TestMetadataProvider',
        positionMs: 60000,
        durationMs: 1200000,
        lastWatched: DateTime.now(),
      );

      await service.markAsWatched(entry);

      final watched = await service.isWatched('TestStreamProvider', 1, 'ep-1');
      expect(watched, true);
    });

    test('different stream providers have separate history', () async {
      final entryA = WatchHistoryEntry(
        animeId: 1,
        episodeId: 'ep-1',
        episodeNumber: '1',
        streamProviderName: 'StreamProviderA',
        metadataProviderName: 'MetadataProvider',
        positionMs: 60000,
        durationMs: 1200000,
        lastWatched: DateTime.now(),
      );

      final entryB = WatchHistoryEntry(
        animeId: 1,
        episodeId: 'ep-1',
        episodeNumber: '1',
        streamProviderName: 'StreamProviderB',
        metadataProviderName: 'MetadataProvider',
        positionMs: 120000,
        durationMs: 1200000,
        lastWatched: DateTime.now(),
      );

      await service.saveProgress(entryA);
      await service.saveProgress(entryB);

      final progressA = await service.getProgress('StreamProviderA', 1, 'ep-1');
      final progressB = await service.getProgress('StreamProviderB', 1, 'ep-1');

      expect(progressA!.positionMs, 60000);
      expect(progressB!.positionMs, 120000);
    });

    test('getWatchHistory returns entries sorted by lastWatched', () async {
      final entry1 = WatchHistoryEntry(
        animeId: 1,
        episodeId: 'ep-1',
        episodeNumber: '1',
        streamProviderName: 'TestStreamProvider',
        metadataProviderName: 'TestMetadataProvider',
        positionMs: 60000,
        durationMs: 1200000,
        lastWatched: DateTime(2025, 1, 1),
      );

      final entry2 = WatchHistoryEntry(
        animeId: 1,
        episodeId: 'ep-2',
        episodeNumber: '2',
        streamProviderName: 'TestStreamProvider',
        metadataProviderName: 'TestMetadataProvider',
        positionMs: 60000,
        durationMs: 1200000,
        lastWatched: DateTime(2025, 1, 2),
      );

      await service.saveProgress(entry1);
      await service.saveProgress(entry2);

      final history = await service.getWatchHistory();

      expect(history.length, 2);
      // Most recent first
      expect(history[0].episodeNumber, '2');
      expect(history[1].episodeNumber, '1');
    });

    test('getWatchedEpisodesForAnime filters correctly', () async {
      await service.markAsWatched(
        WatchHistoryEntry(
          animeId: 1,
          episodeId: 'ep-1',
          episodeNumber: '1',
          streamProviderName: 'TestStreamProvider',
          metadataProviderName: 'TestMetadataProvider',
          positionMs: 1100000,
          durationMs: 1200000,
          lastWatched: DateTime.now(),
        ),
      );

      await service.saveProgress(
        WatchHistoryEntry(
          animeId: 1,
          episodeId: 'ep-2',
          episodeNumber: '2',
          streamProviderName: 'TestStreamProvider',
          metadataProviderName: 'TestMetadataProvider',
          positionMs: 60000, // Not completed
          durationMs: 1200000,
          lastWatched: DateTime.now(),
        ),
      );

      final watched = await service.getWatchedEpisodesForAnime(
        'TestStreamProvider',
        1,
      );

      expect(watched.length, 1);
      expect(watched[0].episodeNumber, '1');
    });

    test('clearProgress removes specific episode progress', () async {
      await service.saveProgress(
        WatchHistoryEntry(
          animeId: 1,
          episodeId: 'ep-1',
          episodeNumber: '1',
          streamProviderName: 'TestStreamProvider',
          metadataProviderName: 'TestMetadataProvider',
          positionMs: 60000,
          durationMs: 1200000,
          lastWatched: DateTime.now(),
        ),
      );

      await service.clearProgress('TestStreamProvider', 1, 'ep-1');

      final progress = await service.getProgress(
        'TestStreamProvider',
        1,
        'ep-1',
      );
      expect(progress, isNull);
    });
  });
}
