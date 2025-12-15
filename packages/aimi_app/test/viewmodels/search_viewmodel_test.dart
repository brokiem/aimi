import 'package:aimi_app/viewmodels/search_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('SearchViewModel', () {
    late SearchViewModel viewModel;
    late FakeAnimeService fakeAnimeService;

    setUp(() async {
      fakeAnimeService = FakeAnimeService();
      viewModel = SearchViewModel(fakeAnimeService);
      // Wait for async history load in constructor
      await Future.delayed(Duration.zero);
    });

    // =========================================================================
    // Initial State Tests
    // =========================================================================
    group('Initial State', () {
      test('history is empty initially (no saved history)', () {
        expect(viewModel.history, isEmpty);
      });

      test('searchResults is empty initially', () {
        expect(viewModel.searchResults, isEmpty);
      });

      test('isLoading is false initially', () {
        expect(viewModel.isLoading, false);
      });

      test('errorMessage is null initially', () {
        expect(viewModel.errorMessage, isNull);
      });

      test('hasSearched is false initially', () {
        expect(viewModel.hasSearched, false);
      });
    });

    // =========================================================================
    // Search Tests
    // =========================================================================
    group('Search', () {
      test('search returns results', () async {
        fakeAnimeService.setSearchResults([
          TestAnimeFactory.createAnime(id: 1, englishTitle: 'Result 1'),
          TestAnimeFactory.createAnime(id: 2, englishTitle: 'Result 2'),
        ]);

        await viewModel.search('test');

        expect(viewModel.searchResults, hasLength(2));
      });

      test('search sets hasSearched to true', () async {
        fakeAnimeService.setSearchResults([]);

        await viewModel.search('test');

        expect(viewModel.hasSearched, true);
      });

      test('search adds query to history', () async {
        fakeAnimeService.setSearchResults([]);

        await viewModel.search('my query');
        // Wait for history reload
        await Future.delayed(Duration.zero);

        expect(viewModel.history, contains('my query'));
      });

      test('empty query is ignored', () async {
        fakeAnimeService.setSearchResults([TestAnimeFactory.createAnime(id: 1)]);

        await viewModel.search('');

        expect(viewModel.searchResults, isEmpty);
        expect(viewModel.hasSearched, false);
      });

      test('whitespace-only query is ignored', () async {
        fakeAnimeService.setSearchResults([TestAnimeFactory.createAnime(id: 1)]);

        await viewModel.search('   ');

        expect(viewModel.searchResults, isEmpty);
      });

      test('search sets isLoading during operation', () async {
        fakeAnimeService.setSearchResults([]);

        bool wasLoading = false;
        viewModel.addListener(() {
          if (viewModel.isLoading) wasLoading = true;
        });

        await viewModel.search('test');

        expect(wasLoading, true);
        expect(viewModel.isLoading, false);
      });

      test('search clears errorMessage on success', () async {
        // First, cause an error
        fakeAnimeService.shouldThrow = true;
        await viewModel.search('fail');
        expect(viewModel.errorMessage, isNotNull);

        // Then search successfully
        fakeAnimeService.shouldThrow = false;
        fakeAnimeService.setSearchResults([]);
        await viewModel.search('success');

        expect(viewModel.errorMessage, isNull);
      });

      test('search sets errorMessage on failure', () async {
        fakeAnimeService.shouldThrow = true;

        await viewModel.search('test');

        expect(viewModel.errorMessage, contains('Failed to search'));
      });
    });

    // =========================================================================
    // History Tests
    // =========================================================================
    group('History', () {
      test('removeFromHistory removes query', () async {
        await fakeAnimeService.addToSearchHistory('keep');
        await fakeAnimeService.addToSearchHistory('remove');
        viewModel = SearchViewModel(fakeAnimeService);
        await Future.delayed(Duration.zero);

        await viewModel.removeFromHistory('remove');

        expect(viewModel.history, contains('keep'));
        expect(viewModel.history, isNot(contains('remove')));
      });

      test('clearHistory removes all history', () async {
        await fakeAnimeService.addToSearchHistory('one');
        await fakeAnimeService.addToSearchHistory('two');
        viewModel = SearchViewModel(fakeAnimeService);
        await Future.delayed(Duration.zero);

        await viewModel.clearHistory();

        expect(viewModel.history, isEmpty);
      });

      test('duplicate search moves query to top of history', () async {
        await fakeAnimeService.addToSearchHistory('first');
        await fakeAnimeService.addToSearchHistory('second');
        viewModel = SearchViewModel(fakeAnimeService);
        await Future.delayed(Duration.zero);

        fakeAnimeService.setSearchResults([]);
        await viewModel.search('first');
        await Future.delayed(Duration.zero);

        expect(viewModel.history.first, 'first');
      });
    });

    // =========================================================================
    // clearResults Tests
    // =========================================================================
    group('clearResults', () {
      test('clears search results', () async {
        fakeAnimeService.setSearchResults([TestAnimeFactory.createAnime(id: 1)]);
        await viewModel.search('test');

        viewModel.clearResults();

        expect(viewModel.searchResults, isEmpty);
      });

      test('resets hasSearched to false', () async {
        fakeAnimeService.setSearchResults([]);
        await viewModel.search('test');
        expect(viewModel.hasSearched, true);

        viewModel.clearResults();

        expect(viewModel.hasSearched, false);
      });

      test('clears errorMessage', () async {
        fakeAnimeService.shouldThrow = true;
        await viewModel.search('test');
        expect(viewModel.errorMessage, isNotNull);

        viewModel.clearResults();

        expect(viewModel.errorMessage, isNull);
      });

      test('notifies listeners', () async {
        fakeAnimeService.setSearchResults([]);
        await viewModel.search('test');

        bool notified = false;
        viewModel.addListener(() => notified = true);

        viewModel.clearResults();

        expect(notified, true);
      });
    });

    // =========================================================================
    // Listener Tests
    // =========================================================================
    group('Listeners', () {
      test('notifies when history loads', () async {
        await fakeAnimeService.addToSearchHistory('test');

        int notifyCount = 0;
        final vm = SearchViewModel(fakeAnimeService);
        vm.addListener(() => notifyCount++);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(notifyCount, greaterThan(0));
      });

      test('notifies on search completion', () async {
        fakeAnimeService.setSearchResults([]);

        int notifyCount = 0;
        viewModel.addListener(() => notifyCount++);

        await viewModel.search('test');

        expect(notifyCount, greaterThan(0));
      });
    });
  });
}
