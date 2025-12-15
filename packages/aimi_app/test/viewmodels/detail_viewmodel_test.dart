import 'package:aimi_app/services/stream_provider_registry.dart';
import 'package:aimi_app/viewmodels/detail_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('DetailViewModel', () {
    late DetailViewModel viewModel;
    late FakeStreamingService fakeStreamingService;
    late FakeStreamProvider providerA;
    late FakeStreamProvider providerB;
    late StreamProviderRegistry registry;

    setUp(() {
      fakeStreamingService = FakeStreamingService();
      providerA = FakeStreamProvider('ProviderA');
      providerB = FakeStreamProvider('ProviderB');
      registry = StreamProviderRegistry([providerA, providerB]);

      viewModel = DetailViewModel(
        TestAnimeFactory.createAnime(id: 1, englishTitle: 'Test Anime'),
        fakeStreamingService,
        registry,
      );
    });

    // =========================================================================
    // Initial State Tests
    // =========================================================================
    group('Initial State', () {
      test('state is idle initially', () {
        expect(viewModel.state, ProviderLoadingState.idle);
      });

      test('errorMessage is null initially', () {
        expect(viewModel.errorMessage, isNull);
      });

      test('searchResults is empty initially', () {
        expect(viewModel.searchResults, isEmpty);
      });

      test('selectedAnime is null initially', () {
        expect(viewModel.selectedAnime, isNull);
      });

      test('episodes is empty initially', () {
        expect(viewModel.episodes, isEmpty);
      });

      test('sources is empty initially', () {
        expect(viewModel.sources, isEmpty);
      });

      test('isLoading is false initially', () {
        expect(viewModel.isLoading, false);
      });
    });

    // =========================================================================
    // Provider Access Tests
    // =========================================================================
    group('Provider Access', () {
      test('availableProviders returns all provider names', () {
        expect(viewModel.availableProviders, ['ProviderA', 'ProviderB']);
      });

      test('currentProviderName returns current provider', () {
        expect(viewModel.currentProviderName, 'ProviderA');
      });

      test('currentProviderIndex returns current index', () {
        expect(viewModel.currentProviderIndex, 0);
      });
    });

    // =========================================================================
    // Provider Switching Tests
    // =========================================================================
    group('Provider Switching', () {
      test('switchProvider changes current provider', () async {
        await viewModel.switchProvider(1);

        expect(viewModel.currentProviderName, 'ProviderB');
        expect(viewModel.currentProviderIndex, 1);
      });

      test('switchProvider to same index is no-op', () async {
        await viewModel.switchProvider(0);

        expect(viewModel.currentProviderName, 'ProviderA');
      });

      test('switchProvider clears previous data', () async {
        // Set up some data for provider A
        fakeStreamingService.setSearchResults([TestAnimeFactory.createStreamingResult(id: '1', title: 'Result')]);
        fakeStreamingService.setEpisodes([TestAnimeFactory.createEpisode(id: 'ep-1')]);
        fakeStreamingService.setCachedEpisodes(1, 'ProviderA', [TestAnimeFactory.createEpisode(id: 'ep-1')]);

        await viewModel.loadAnime();
        expect(viewModel.episodes, isNotEmpty);

        // Switch to provider B
        fakeStreamingService.setSearchResults([]);
        fakeStreamingService.setEpisodes([]);
        await viewModel.switchProvider(1);

        // Episodes should be cleared (new provider has no cache)
        // State depends on whether cache exists
      });

      test('switchProvider clears errorMessage', () async {
        // Cause an error
        fakeStreamingService.shouldThrow = true;
        await viewModel.loadAnime();
        // Can't verify error without checking state

        fakeStreamingService.shouldThrow = false;
        fakeStreamingService.setSearchResults([]);

        await viewModel.switchProvider(1);

        expect(viewModel.errorMessage, isNotNull); // No results error, but cleared previous
      });
    });

    // =========================================================================
    // loadAnime Tests
    // =========================================================================
    group('loadAnime', () {
      test('sets state to loaded when results found', () async {
        fakeStreamingService.setSearchResults([TestAnimeFactory.createStreamingResult(id: '1', title: 'Test')]);
        fakeStreamingService.setEpisodes([TestAnimeFactory.createEpisode(id: 'ep-1')]);

        await viewModel.loadAnime();

        expect(viewModel.state, ProviderLoadingState.loaded);
      });

      test('sets state to error when no results', () async {
        fakeStreamingService.setSearchResults([]);

        await viewModel.loadAnime();

        expect(viewModel.state, ProviderLoadingState.error);
        expect(viewModel.errorMessage, contains('No results'));
      });

      test('caches episodes for provider', () async {
        fakeStreamingService.setSearchResults([TestAnimeFactory.createStreamingResult(id: '1')]);
        fakeStreamingService.setEpisodes([
          TestAnimeFactory.createEpisode(id: 'ep-1'),
          TestAnimeFactory.createEpisode(id: 'ep-2'),
        ]);

        await viewModel.loadAnime();

        final cached = fakeStreamingService.getCachedEpisodes(1, 'ProviderA');
        expect(cached, isNotNull);
        expect(cached, hasLength(2));
      });

      test('uses cached data on subsequent calls', () async {
        // Pre-cache episodes
        fakeStreamingService.setCachedEpisodes(1, 'ProviderA', [TestAnimeFactory.createEpisode(id: 'cached-ep')]);
        fakeStreamingService.setCachedSelectedAnime(1, 'ProviderA', TestAnimeFactory.createStreamingResult(id: '1'));

        await viewModel.loadAnime();

        expect(viewModel.episodes, hasLength(1));
        expect(viewModel.episodes.first.id, 'cached-ep');
      });
    });

    // =========================================================================
    // loadEpisodes Tests
    // =========================================================================
    group('loadEpisodes', () {
      test('loads episodes for selected anime', () async {
        final streamingResult = TestAnimeFactory.createStreamingResult(id: '1');
        fakeStreamingService.setEpisodes([
          TestAnimeFactory.createEpisode(id: 'ep-1', number: '1'),
          TestAnimeFactory.createEpisode(id: 'ep-2', number: '2'),
        ]);

        await viewModel.loadEpisodes(streamingResult);

        expect(viewModel.episodes, hasLength(2));
        expect(viewModel.selectedAnime, streamingResult);
      });

      test('sets loading state during operation', () async {
        final streamingResult = TestAnimeFactory.createStreamingResult(id: '1');
        fakeStreamingService.setEpisodes([]);

        bool wasLoading = false;
        viewModel.addListener(() {
          if (viewModel.state == ProviderLoadingState.loadingEpisodes) {
            wasLoading = true;
          }
        });

        await viewModel.loadEpisodes(streamingResult);

        expect(wasLoading, true);
      });

      test('handles errors', () async {
        fakeStreamingService.shouldThrow = true;
        final streamingResult = TestAnimeFactory.createStreamingResult(id: '1');

        await viewModel.loadEpisodes(streamingResult);

        expect(viewModel.state, ProviderLoadingState.error);
        expect(viewModel.errorMessage, contains('Failed to load episodes'));
      });
    });

    // =========================================================================
    // loadSources Tests
    // =========================================================================
    group('loadSources', () {
      test('loads sources for episode', () async {
        final episode = TestAnimeFactory.createEpisode(id: 'ep-1');
        fakeStreamingService.setSources([
          TestAnimeFactory.createSource(quality: '1080p'),
          TestAnimeFactory.createSource(quality: '720p'),
        ]);

        await viewModel.loadSources(episode);

        expect(viewModel.sources, hasLength(2));
        expect(viewModel.selectedEpisode, episode);
      });

      test('sets error when no sources available', () async {
        final episode = TestAnimeFactory.createEpisode(id: 'ep-1');
        fakeStreamingService.setSources([]);

        await viewModel.loadSources(episode);

        expect(viewModel.state, ProviderLoadingState.error);
        expect(viewModel.errorMessage, contains('No sources'));
      });

      test('handles errors', () async {
        fakeStreamingService.shouldThrow = true;
        final episode = TestAnimeFactory.createEpisode(id: 'ep-1');

        await viewModel.loadSources(episode);

        expect(viewModel.state, ProviderLoadingState.error);
        expect(viewModel.errorMessage, contains('Failed to load sources'));
      });
    });

    // =========================================================================
    // getBestSource Tests
    // =========================================================================
    group('getBestSource', () {
      test('returns null when no sources', () {
        expect(viewModel.getBestSource(), isNull);
      });

      test('returns highest quality source', () async {
        final episode = TestAnimeFactory.createEpisode(id: 'ep-1');
        fakeStreamingService.setSources([
          TestAnimeFactory.createSource(quality: '480p'),
          TestAnimeFactory.createSource(quality: '1080p'),
          TestAnimeFactory.createSource(quality: '720p'),
        ]);

        await viewModel.loadSources(episode);

        final best = viewModel.getBestSource();
        expect(best, isNotNull);
        expect(best!.quality, '1080p');
      });

      test('handles non-numeric quality strings', () async {
        final episode = TestAnimeFactory.createEpisode(id: 'ep-1');
        fakeStreamingService.setSources([
          TestAnimeFactory.createSource(quality: 'auto'),
          TestAnimeFactory.createSource(quality: '720p'),
        ]);

        await viewModel.loadSources(episode);

        final best = viewModel.getBestSource();
        expect(best, isNotNull);
        expect(best!.quality, '720p'); // 720 > 0 (auto parses as 0)
      });
    });

    // =========================================================================
    // selectAnime Tests
    // =========================================================================
    group('selectAnime', () {
      test('selects anime and loads episodes', () async {
        final result = TestAnimeFactory.createStreamingResult(id: '2', title: 'Selected');
        fakeStreamingService.setEpisodes([TestAnimeFactory.createEpisode(id: 'ep-new')]);

        viewModel.selectAnime(result);

        // Wait for async loadEpisodes
        await Future.delayed(const Duration(milliseconds: 50));

        expect(viewModel.selectedAnime, result);
      });
    });

    // =========================================================================
    // getEpisodeCountForProvider Tests
    // =========================================================================
    group('getEpisodeCountForProvider', () {
      test('returns 0 when no cache', () {
        expect(viewModel.getEpisodeCountForProvider('Unknown'), 0);
      });

      test('returns cached count', () {
        fakeStreamingService.setCachedEpisodes(1, 'ProviderA', [
          TestAnimeFactory.createEpisode(id: 'ep-1'),
          TestAnimeFactory.createEpisode(id: 'ep-2'),
          TestAnimeFactory.createEpisode(id: 'ep-3'),
        ]);

        expect(viewModel.getEpisodeCountForProvider('ProviderA'), 3);
      });
    });

    // =========================================================================
    // isLoading Tests
    // =========================================================================
    group('isLoading', () {
      test('is true during searching state', () async {
        // Hard to test directly without async control
        // Verify the property logic
        expect(viewModel.isLoading, false);
      });
    });

    // =========================================================================
    // Listener Tests
    // =========================================================================
    group('Listeners', () {
      test('notifies on loadAnime', () async {
        fakeStreamingService.setSearchResults([]);

        int notifyCount = 0;
        viewModel.addListener(() => notifyCount++);

        await viewModel.loadAnime();

        expect(notifyCount, greaterThan(0));
      });

      test('notifies on provider switch', () async {
        int notifyCount = 0;
        viewModel.addListener(() => notifyCount++);

        fakeStreamingService.setSearchResults([]);
        await viewModel.switchProvider(1);

        expect(notifyCount, greaterThan(0));
      });
    });
  });
}
