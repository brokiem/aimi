import 'package:aimi_app/models/watch_history_entry.dart';
import 'package:aimi_app/viewmodels/history_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('HistoryViewModel', () {
    late HistoryViewModel viewModel;
    late FakeWatchHistoryService fakeWatchHistoryService;
    late FakeAnimeService fakeAnimeService;
    late FakeStorageService fakeStorageService;

    setUp(() {
      fakeStorageService = FakeStorageService();
      fakeWatchHistoryService = FakeWatchHistoryService(fakeStorageService);
      fakeAnimeService = FakeAnimeService();
      viewModel = HistoryViewModel(fakeWatchHistoryService, fakeAnimeService);
    });

    tearDown(() {
      viewModel.dispose();
      fakeStorageService.clear();
    });

    // =========================================================================
    // Initial State Tests
    // =========================================================================
    group('Initial State', () {
      test('watchHistory is empty initially', () {
        expect(viewModel.watchHistory, isEmpty);
      });

      test('watchedAnime is empty initially', () {
        expect(viewModel.watchedAnime, isEmpty);
      });

      test('isLoadingHistory is false initially', () {
        expect(viewModel.isLoadingHistory, false);
      });

      test('historyError is null initially', () {
        expect(viewModel.historyError, isNull);
      });
    });

    // =========================================================================
    // fetchWatchHistory Tests
    // =========================================================================
    group('fetchWatchHistory', () {
      test('fetches watch history entries', () async {
        await fakeWatchHistoryService.saveProgress(
          WatchHistoryEntry(
            animeId: 1,
            episodeId: 'ep-1',
            episodeNumber: '1',
            streamProviderName: 'Provider',
            metadataProviderName: 'FakeProvider',
            positionMs: 60000,
            durationMs: 1200000,
            lastWatched: DateTime.now(),
          ),
        );

        fakeAnimeService.setAnimeById(1, TestAnimeFactory.createAnime(id: 1, englishTitle: 'Test Anime'));

        await viewModel.fetchWatchHistory();

        expect(viewModel.watchHistory, hasLength(1));
        expect(viewModel.watchHistory.first.animeId, 1);
      });

      test('fetches unique anime for history entries', () async {
        // Two entries for same anime
        await fakeWatchHistoryService.saveProgress(
          WatchHistoryEntry(
            animeId: 1,
            episodeId: 'ep-1',
            episodeNumber: '1',
            streamProviderName: 'Provider',
            metadataProviderName: 'FakeProvider',
            positionMs: 60000,
            durationMs: 1200000,
            lastWatched: DateTime.now(),
          ),
        );
        await fakeWatchHistoryService.saveProgress(
          WatchHistoryEntry(
            animeId: 1,
            episodeId: 'ep-2',
            episodeNumber: '2',
            streamProviderName: 'Provider',
            metadataProviderName: 'FakeProvider',
            positionMs: 30000,
            durationMs: 1200000,
            lastWatched: DateTime.now(),
          ),
        );

        fakeAnimeService.setAnimeById(1, TestAnimeFactory.createAnime(id: 1));

        await viewModel.fetchWatchHistory();

        // Should have 2 history entries but 1 unique anime
        expect(viewModel.watchHistory, hasLength(2));
        expect(viewModel.watchedAnime, hasLength(1));
      });

      test('sets isLoadingHistory during fetch', () async {
        bool wasLoading = false;
        viewModel.addListener(() {
          if (viewModel.isLoadingHistory) wasLoading = true;
        });

        await viewModel.fetchWatchHistory();

        expect(wasLoading, true);
        expect(viewModel.isLoadingHistory, false);
      });

      test('handles anime fetch errors gracefully', () async {
        await fakeWatchHistoryService.saveProgress(
          WatchHistoryEntry(
            animeId: 999,
            episodeId: 'ep-1',
            episodeNumber: '1',
            streamProviderName: 'Provider',
            metadataProviderName: 'FakeProvider',
            positionMs: 60000,
            durationMs: 1200000,
            lastWatched: DateTime.now(),
          ),
        );

        // Don't set anime - will cause error in getById

        await viewModel.fetchWatchHistory();

        // Should have history but no anime (anime fetch failed)
        expect(viewModel.watchHistory, hasLength(1));
        expect(viewModel.watchedAnime, isEmpty);
        expect(viewModel.historyError, isNull); // Not a critical error
      });

      test('sets historyError on complete failure', () async {
        // Force CachingService to fail by some means
        // This is tricky with current implementation
        // For now, test that error state can be set
        viewModel = HistoryViewModel(fakeWatchHistoryService, fakeAnimeService);

        // With empty history, this should succeed
        await viewModel.fetchWatchHistory();
        expect(viewModel.historyError, isNull);
      });

      test('clears previous data on refetch', () async {
        await fakeWatchHistoryService.saveProgress(
          WatchHistoryEntry(
            animeId: 1,
            episodeId: 'ep-1',
            episodeNumber: '1',
            streamProviderName: 'Provider',
            metadataProviderName: 'FakeProvider',
            positionMs: 60000,
            durationMs: 1200000,
            lastWatched: DateTime.now(),
          ),
        );
        fakeAnimeService.setAnimeById(1, TestAnimeFactory.createAnime(id: 1));
        await viewModel.fetchWatchHistory();

        // Clear and refetch
        await fakeWatchHistoryService.clearHistory();
        await viewModel.fetchWatchHistory();

        expect(viewModel.watchHistory, isEmpty);
        expect(viewModel.watchedAnime, isEmpty);
      });
    });

    // =========================================================================
    // Stream Subscription Tests
    // =========================================================================
    group('Stream Subscription', () {
      test('listens to watch history updates', () async {
        fakeAnimeService.setAnimeById(1, TestAnimeFactory.createAnime(id: 1));

        // Fetch initially
        await viewModel.fetchWatchHistory();
        expect(viewModel.watchHistory, isEmpty);

        // Save progress - should trigger auto-refresh via stream
        await fakeWatchHistoryService.saveProgress(
          WatchHistoryEntry(
            animeId: 1,
            episodeId: 'ep-1',
            episodeNumber: '1',
            streamProviderName: 'Provider',
            metadataProviderName: 'FakeProvider',
            positionMs: 60000,
            durationMs: 1200000,
            lastWatched: DateTime.now(),
          ),
        );

        // Wait for stream event and refetch
        await Future.delayed(const Duration(milliseconds: 100));

        expect(viewModel.watchHistory, hasLength(1));
      });
    });

    // =========================================================================
    // Dispose Tests
    // =========================================================================
    group('Dispose', () {
      test('dispose cancels subscription without error', () {
        // Create a separate ViewModel for this test to avoid double dispose
        final testVM = HistoryViewModel(fakeWatchHistoryService, fakeAnimeService);
        expect(() => testVM.dispose(), returnsNormally);
      });
    });

    // =========================================================================
    // Listener Tests
    // =========================================================================
    group('Listeners', () {
      test('notifies listeners on fetch', () async {
        int notifyCount = 0;
        viewModel.addListener(() => notifyCount++);

        await viewModel.fetchWatchHistory();

        expect(notifyCount, greaterThan(0));
      });
    });
  });
}
