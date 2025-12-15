import 'package:aimi_app/viewmodels/home_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('HomeViewModel', () {
    late HomeViewModel viewModel;
    late FakeAnimeService fakeAnimeService;

    setUp(() {
      fakeAnimeService = FakeAnimeService();
      viewModel = HomeViewModel(fakeAnimeService);
    });

    // =========================================================================
    // Initial State Tests
    // =========================================================================
    group('Initial State', () {
      test('trendingAnime is empty initially', () {
        expect(viewModel.trendingAnime, isEmpty);
      });

      test('currentPage is 1 initially', () {
        expect(viewModel.currentPage, 1);
      });

      test('isLoading is false initially', () {
        expect(viewModel.isLoading, false);
      });

      test('errorMessage is null initially', () {
        expect(viewModel.errorMessage, isNull);
      });
    });

    // =========================================================================
    // fetchTrending Tests
    // =========================================================================
    group('fetchTrending', () {
      test('fetches trending anime successfully', () async {
        final anime = [
          TestAnimeFactory.createAnime(id: 1, englishTitle: 'Anime 1'),
          TestAnimeFactory.createAnime(id: 2, englishTitle: 'Anime 2'),
        ];
        fakeAnimeService.setTrendingAnime(anime);

        await viewModel.fetchTrending();

        expect(viewModel.trendingAnime, hasLength(2));
        expect(viewModel.trendingAnime.first.title.english, 'Anime 1');
      });

      test('sets isLoading during fetch', () async {
        fakeAnimeService.setTrendingAnime([]);

        bool wasLoading = false;
        viewModel.addListener(() {
          if (viewModel.isLoading) wasLoading = true;
        });

        await viewModel.fetchTrending();

        expect(wasLoading, true);
        expect(viewModel.isLoading, false); // After completion
      });

      test('notifies listeners on success', () async {
        fakeAnimeService.setTrendingAnime([TestAnimeFactory.createAnime(id: 1)]);

        int notifyCount = 0;
        viewModel.addListener(() => notifyCount++);

        await viewModel.fetchTrending();

        expect(notifyCount, greaterThan(0));
      });

      test('clears previous results on new fetch', () async {
        fakeAnimeService.setTrendingAnime([TestAnimeFactory.createAnime(id: 1), TestAnimeFactory.createAnime(id: 2)]);
        await viewModel.fetchTrending();

        fakeAnimeService.setTrendingAnime([TestAnimeFactory.createAnime(id: 3)]);
        await viewModel.fetchTrending();

        expect(viewModel.trendingAnime, hasLength(1));
        expect(viewModel.trendingAnime.first.id, 3);
      });

      test('resets page to 1', () async {
        fakeAnimeService.setTrendingAnime([TestAnimeFactory.createAnime(id: 1)]);

        await viewModel.fetchTrending();

        expect(viewModel.currentPage, 1);
      });

      test('handles errors and sets errorMessage', () async {
        fakeAnimeService.shouldThrow = true;
        fakeAnimeService.errorMessage = 'Network error';

        try {
          await viewModel.fetchTrending();
        } catch (_) {}

        expect(viewModel.errorMessage, contains('Failed to load'));
      });

      test('isLoading is false after error', () async {
        fakeAnimeService.shouldThrow = true;

        try {
          await viewModel.fetchTrending();
        } catch (_) {}

        expect(viewModel.isLoading, false);
      });
    });

    // =========================================================================
    // loadMoreTrendingAnime Tests
    // =========================================================================
    group('loadMoreTrendingAnime', () {
      test('appends new anime to existing list', () async {
        fakeAnimeService.setTrendingAnime([TestAnimeFactory.createAnime(id: 1, englishTitle: 'Page 1')]);
        await viewModel.fetchTrending();

        fakeAnimeService.setTrendingAnime([TestAnimeFactory.createAnime(id: 2, englishTitle: 'Page 2')]);
        await viewModel.loadMoreTrendingAnime();

        expect(viewModel.trendingAnime, hasLength(2));
        expect(viewModel.trendingAnime[0].id, 1);
        expect(viewModel.trendingAnime[1].id, 2);
      });

      test('increments currentPage', () async {
        fakeAnimeService.setTrendingAnime([]);
        await viewModel.fetchTrending();

        expect(viewModel.currentPage, 1);

        await viewModel.loadMoreTrendingAnime();
        expect(viewModel.currentPage, 2);

        await viewModel.loadMoreTrendingAnime();
        expect(viewModel.currentPage, 3);
      });

      test('sets isLoading during load', () async {
        fakeAnimeService.setTrendingAnime([]);

        bool wasLoading = false;
        viewModel.addListener(() {
          if (viewModel.isLoading) wasLoading = true;
        });

        await viewModel.loadMoreTrendingAnime();

        expect(wasLoading, true);
      });

      test('reverts page on error', () async {
        fakeAnimeService.setTrendingAnime([]);
        await viewModel.fetchTrending();
        expect(viewModel.currentPage, 1);

        fakeAnimeService.shouldThrow = true;

        try {
          await viewModel.loadMoreTrendingAnime();
        } catch (_) {}

        expect(viewModel.currentPage, 1); // Reverted
      });

      test('sets errorMessage on error', () async {
        fakeAnimeService.setTrendingAnime([]);
        await viewModel.fetchTrending();

        fakeAnimeService.shouldThrow = true;

        try {
          await viewModel.loadMoreTrendingAnime();
        } catch (_) {}

        expect(viewModel.errorMessage, contains('Failed to load more'));
      });
    });

    // =========================================================================
    // Listener Tests
    // =========================================================================
    group('Listeners', () {
      test('notifies at start and end of fetch', () async {
        fakeAnimeService.setTrendingAnime([]);

        List<bool> loadingStates = [];
        viewModel.addListener(() {
          loadingStates.add(viewModel.isLoading);
        });

        await viewModel.fetchTrending();

        expect(loadingStates, contains(true)); // During loading
        expect(loadingStates.last, false); // After completion
      });
    });
  });
}
