import 'package:aimi_app/models/watch_history_entry.dart';
import 'package:aimi_app/services/watch_history_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  late WatchHistoryService service;
  late FakeStorageService fakeStorageService;

  setUp(() {
    fakeStorageService = FakeStorageService();
    service = WatchHistoryService(fakeStorageService);
  });

  tearDown(() {
    fakeStorageService.clear();
  });

  // ===========================================================================
  // WatchHistoryEntry Model Tests
  // ===========================================================================
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
        positionMs: 300000,
        // 5 minutes
        durationMs: 1200000,
        // 20 minutes
        lastWatched: DateTime.now(),
      );

      expect(entry.progress, closeTo(0.25, 0.001)); // 25%
    });

    test('progress is 0 when duration is 0', () {
      final entry = WatchHistoryEntry(
        animeId: 1,
        episodeId: 'ep',
        episodeNumber: '1',
        streamProviderName: 'StreamP',
        metadataProviderName: 'MetaP',
        positionMs: 100,
        durationMs: 0,
        lastWatched: DateTime.now(),
      );

      expect(entry.progress, 0.0);
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

    test('position getter returns correct Duration', () {
      final entry = WatchHistoryEntry(
        animeId: 1,
        episodeId: 'ep',
        episodeNumber: '1',
        streamProviderName: 'Provider',
        metadataProviderName: 'Meta',
        positionMs: 65000,
        // 1 minute 5 seconds
        durationMs: 1200000,
        lastWatched: DateTime.now(),
      );

      expect(entry.position, const Duration(milliseconds: 65000));
      expect(entry.position.inSeconds, 65);
    });

    test('duration getter returns correct Duration', () {
      final entry = WatchHistoryEntry(
        animeId: 1,
        episodeId: 'ep',
        episodeNumber: '1',
        streamProviderName: 'Provider',
        metadataProviderName: 'Meta',
        positionMs: 0,
        durationMs: 1200000,
        // 20 minutes
        lastWatched: DateTime.now(),
      );

      expect(entry.duration, const Duration(milliseconds: 1200000));
      expect(entry.duration.inMinutes, 20);
    });

    test('copyWith creates copy with updated fields', () {
      final original = WatchHistoryEntry(
        animeId: 1,
        episodeId: 'ep-1',
        episodeNumber: '1',
        streamProviderName: 'Provider',
        metadataProviderName: 'Meta',
        positionMs: 1000,
        durationMs: 10000,
        lastWatched: DateTime(2025, 1, 1),
      );

      final updated = original.copyWith(positionMs: 5000, isCompleted: true);

      expect(updated.animeId, 1); // Unchanged
      expect(updated.positionMs, 5000); // Changed
      expect(updated.isCompleted, true); // Changed
      expect(updated.episodeId, 'ep-1'); // Unchanged
    });

    test('equality is based on animeId, episodeId, and streamProviderName', () {
      final entry1 = WatchHistoryEntry(
        animeId: 1,
        episodeId: 'ep-1',
        episodeNumber: '1',
        streamProviderName: 'Provider',
        metadataProviderName: 'Meta',
        positionMs: 1000,
        durationMs: 10000,
        lastWatched: DateTime(2025, 1, 1),
      );

      final entry2 = WatchHistoryEntry(
        animeId: 1,
        episodeId: 'ep-1',
        episodeNumber: '1',
        streamProviderName: 'Provider',
        metadataProviderName: 'DifferentMeta',
        // Different but should still be equal
        positionMs: 5000,
        // Different position
        durationMs: 10000,
        lastWatched: DateTime(2025, 1, 2), // Different date
      );

      expect(entry1, equals(entry2));
      expect(entry1.hashCode, entry2.hashCode);
    });
  });

  // ===========================================================================
  // WatchHistoryService Tests
  // ===========================================================================
  group('WatchHistoryService', () {
    // =========================================================================
    // Basic Progress Tests
    // =========================================================================
    group('Progress Management', () {
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

        final retrieved = await service.getProgress('TestStreamProvider', 1, 'ep-1');
        expect(retrieved, isNotNull);
        expect(retrieved!.animeId, 1);
        expect(retrieved.episodeId, 'ep-1');
        expect(retrieved.positionMs, 60000);
      });

      test('getProgress returns null for unknown episode', () async {
        final progress = await service.getProgress('Unknown', 999, 'ep-999');
        expect(progress, isNull);
      });

      test('getPosition returns Duration.zero for unknown episode', () async {
        final position = await service.getPosition('Unknown', 999, 'ep-999');
        expect(position, Duration.zero);
      });

      test('getPosition returns correct position for saved entry', () async {
        final entry = WatchHistoryEntry(
          animeId: 1,
          episodeId: 'ep-1',
          episodeNumber: '1',
          streamProviderName: 'Provider',
          metadataProviderName: 'Meta',
          positionMs: 120000,
          durationMs: 1200000,
          lastWatched: DateTime.now(),
        );

        await service.saveProgress(entry);

        final position = await service.getPosition('Provider', 1, 'ep-1');
        expect(position, const Duration(milliseconds: 120000));
      });
    });

    // =========================================================================
    // Completion Tests
    // =========================================================================
    group('Completion', () {
      test('isWatched returns false for unwatched episode', () async {
        final watched = await service.isWatched('TestStreamProvider', 1, 'ep-1');
        expect(watched, false);
      });

      test('auto-marks as completed when progress >= 96%', () async {
        final entry = WatchHistoryEntry(
          animeId: 1,
          episodeId: 'ep-1',
          episodeNumber: '1',
          streamProviderName: 'TestStreamProvider',
          metadataProviderName: 'TestMetadataProvider',
          positionMs: 1152000,
          // 96% of 1200000
          durationMs: 1200000,
          lastWatched: DateTime.now(),
        );

        await service.saveProgress(entry);

        final watched = await service.isWatched('TestStreamProvider', 1, 'ep-1');
        expect(watched, true);
      });

      test('does not auto-mark when progress < 96%', () async {
        final entry = WatchHistoryEntry(
          animeId: 1,
          episodeId: 'ep-1',
          episodeNumber: '1',
          streamProviderName: 'TestStreamProvider',
          metadataProviderName: 'TestMetadataProvider',
          positionMs: 1140000,
          // ~95%
          durationMs: 1200000,
          lastWatched: DateTime.now(),
        );

        await service.saveProgress(entry);

        final watched = await service.isWatched('TestStreamProvider', 1, 'ep-1');
        expect(watched, false);
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
    });

    // =========================================================================
    // Provider Separation Tests
    // =========================================================================
    group('Provider Separation', () {
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
    });

    // =========================================================================
    // Watch History List Tests
    // =========================================================================
    group('Watch History List', () {
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

      test('getWatchHistory with limit returns limited entries', () async {
        for (int i = 1; i <= 5; i++) {
          await service.saveProgress(
            WatchHistoryEntry(
              animeId: 1,
              episodeId: 'ep-$i',
              episodeNumber: '$i',
              streamProviderName: 'Provider',
              metadataProviderName: 'Meta',
              positionMs: 1000,
              durationMs: 10000,
              lastWatched: DateTime(2025, 1, i),
            ),
          );
        }

        final limited = await service.getWatchHistory(limit: 3);
        expect(limited.length, 3);
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
            positionMs: 60000,
            // Not completed
            durationMs: 1200000,
            lastWatched: DateTime.now(),
          ),
        );

        final watched = await service.getWatchedEpisodesForAnime('TestStreamProvider', 1);

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

        final progress = await service.getProgress('TestStreamProvider', 1, 'ep-1');
        expect(progress, isNull);
      });

      test('clearHistory removes all history', () async {
        await service.saveProgress(
          WatchHistoryEntry(
            animeId: 1,
            episodeId: 'ep-1',
            episodeNumber: '1',
            streamProviderName: 'Provider',
            metadataProviderName: 'Meta',
            positionMs: 1000,
            durationMs: 10000,
            lastWatched: DateTime.now(),
          ),
        );

        await service.clearHistory();

        final history = await service.getWatchHistory();
        expect(history, isEmpty);
      });
    });

    // =========================================================================
    // Cross-Provider Lookup Tests
    // =========================================================================
    group('Cross-Provider Lookup', () {
      test('findLatestProgress finds entry across providers', () async {
        await service.saveProgress(
          WatchHistoryEntry(
            animeId: 1,
            episodeId: 'old-ep',
            episodeNumber: '5',
            streamProviderName: 'OldProvider',
            metadataProviderName: 'Meta',
            positionMs: 60000,
            durationMs: 1200000,
            lastWatched: DateTime(2025, 1, 1),
          ),
        );

        await service.saveProgress(
          WatchHistoryEntry(
            animeId: 1,
            episodeId: 'new-ep',
            episodeNumber: '5',
            streamProviderName: 'NewProvider',
            metadataProviderName: 'Meta',
            positionMs: 120000,
            durationMs: 1200000,
            lastWatched: DateTime(2025, 1, 2),
          ),
        );

        final latest = await service.findLatestProgress(1, '5');

        expect(latest, isNotNull);
        expect(latest!.streamProviderName, 'NewProvider');
        expect(latest.positionMs, 120000);
      });

      test('findLatestProgress returns null when no match', () async {
        final result = await service.findLatestProgress(999, '1');
        expect(result, isNull);
      });
    });

    // =========================================================================
    // Resume Position Tests
    // =========================================================================
    group('Resume Position', () {
      test('getResumePosition returns exact match when available', () async {
        await service.saveProgress(
          WatchHistoryEntry(
            animeId: 1,
            episodeId: 'ep-1',
            episodeNumber: '1',
            streamProviderName: 'Provider',
            metadataProviderName: 'Meta',
            positionMs: 60000,
            durationMs: 1200000,
            lastWatched: DateTime.now(),
          ),
        );

        final result = await service.getResumePosition(
          providerName: 'Provider',
          animeId: 1,
          episodeId: 'ep-1',
          episodeNumber: '1',
        );

        expect(result.position, const Duration(milliseconds: 60000));
        expect(result.isCrossProvider, isFalse);
      });

      test('getResumePosition falls back to cross-provider when no exact match', () async {
        await service.saveProgress(
          WatchHistoryEntry(
            animeId: 1,
            episodeId: 'old-ep',
            episodeNumber: '1',
            streamProviderName: 'OldProvider',
            metadataProviderName: 'Meta',
            positionMs: 90000,
            durationMs: 1200000,
            lastWatched: DateTime.now(),
          ),
        );

        final result = await service.getResumePosition(
          providerName: 'NewProvider',
          animeId: 1,
          episodeId: 'new-ep',
          episodeNumber: '1',
        );

        expect(result.position, const Duration(milliseconds: 90000));
        expect(result.isCrossProvider, isTrue);
      });

      test('getResumePosition uses cross-provider if it is newer', () async {
        // Old exact match - save first
        await service.saveProgress(
          WatchHistoryEntry(
            animeId: 1,
            episodeId: 'ep-1',
            episodeNumber: '1',
            streamProviderName: 'Provider',
            metadataProviderName: 'Meta',
            positionMs: 60000,
            durationMs: 1200000,
            lastWatched: DateTime.now(), // Will be overwritten by saveProgress
          ),
        );

        // Small delay to ensure timestamps differ
        await Future.delayed(const Duration(milliseconds: 10));

        // Newer cross-provider - save after delay so it's definitely newer
        await service.saveProgress(
          WatchHistoryEntry(
            animeId: 1,
            episodeId: 'other-ep',
            episodeNumber: '1',
            streamProviderName: 'OtherProvider',
            metadataProviderName: 'Meta',
            positionMs: 120000,
            durationMs: 1200000,
            lastWatched: DateTime.now(), // Will be overwritten by saveProgress
          ),
        );

        final result = await service.getResumePosition(
          providerName: 'Provider',
          animeId: 1,
          episodeId: 'ep-1',
          episodeNumber: '1',
        );

        expect(result.position, const Duration(milliseconds: 120000));
        expect(result.isCrossProvider, isTrue);
      });

      test('getResumePosition returns zero when no progress found', () async {
        final result = await service.getResumePosition(
          providerName: 'Provider',
          animeId: 999,
          episodeId: 'ep-999',
          episodeNumber: '1',
        );

        expect(result.position, Duration.zero);
        expect(result.isCrossProvider, isFalse);
      });
    });

    // =========================================================================
    // Stream Events Tests
    // =========================================================================
    group('Stream Events', () {
      test('onProgressUpdated emits when progress is saved', () async {
        final updates = <WatchHistoryEntry>[];
        final subscription = service.onProgressUpdated.listen(updates.add);

        await service.saveProgress(
          WatchHistoryEntry(
            animeId: 1,
            episodeId: 'ep-1',
            episodeNumber: '1',
            streamProviderName: 'Provider',
            metadataProviderName: 'Meta',
            positionMs: 60000,
            durationMs: 1200000,
            lastWatched: DateTime.now(),
          ),
        );

        // Allow stream to emit
        await Future.delayed(Duration.zero);

        expect(updates, hasLength(1));
        expect(updates.first.episodeId, 'ep-1');

        await subscription.cancel();
      });
    });
  });
}
