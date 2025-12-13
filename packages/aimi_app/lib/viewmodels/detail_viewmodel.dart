import 'package:flutter/foundation.dart';

import '../models/anime.dart';
import '../models/anime_episode.dart';
import '../models/streaming_anime_result.dart';
import '../models/streaming_source.dart';
import '../services/stream_provider_registry.dart';
import '../services/streaming_service.dart';

enum ProviderLoadingState { idle, searching, loadingEpisodes, loadingSources, loaded, error }

class DetailViewModel extends ChangeNotifier {
  final Anime anime;
  final StreamingService _streamingService;
  final StreamProviderRegistry _providerRegistry;

  DetailViewModel(this.anime, this._streamingService, this._providerRegistry);

  ProviderLoadingState _state = ProviderLoadingState.idle;
  String? _errorMessage;

  // Stream provider data
  List<StreamingAnimeResult> _searchResults = [];
  StreamingAnimeResult? _selectedAnime;
  List<AnimeEpisode> _episodes = [];
  AnimeEpisode? _selectedEpisode;
  List<StreamingSource> _sources = [];

  // Per-provider episode cache: providerName -> episodes
  // We now delegate caching to StreamingService for persistence, but we can keep local references for UI binding if needed
  // changing _episodeCache to just be a helper or verify if we need it.
  // Actually, DetailViewModel needs to expose _episodes for the CURRENT provider.
  // But for the tabs, it needs episode counts.
  // We should fetch from service cache.

  // Getters
  ProviderLoadingState get state => _state;

  String? get errorMessage => _errorMessage;

  List<StreamingAnimeResult> get searchResults => _searchResults;

  StreamingAnimeResult? get selectedAnime => _selectedAnime;

  List<AnimeEpisode> get episodes => _episodes;

  AnimeEpisode? get selectedEpisode => _selectedEpisode;

  List<StreamingSource> get sources => _sources;

  bool get isLoading =>
      _state == ProviderLoadingState.searching ||
      _state == ProviderLoadingState.loadingEpisodes ||
      _state == ProviderLoadingState.loadingSources;

  /// Provider registry access
  List<String> get availableProviders => _providerRegistry.providerNames;

  String get currentProviderName => _providerRegistry.currentName;

  int get currentProviderIndex => _providerRegistry.currentIndex;

  /// Get episode count for a specific provider (from persistence cache)
  int getEpisodeCountForProvider(String providerName) {
    final cached = _streamingService.getCachedEpisodes(anime.id, providerName);
    return cached?.length ?? 0;
  }

  /// Get episodes for a specific provider (from persistence cache)
  List<AnimeEpisode>? getEpisodesForProvider(String providerName) {
    return _streamingService.getCachedEpisodes(anime.id, providerName);
  }

  /// Switch to a different provider by index
  Future<void> switchProvider(int index) async {
    if (index == _providerRegistry.currentIndex) return;

    _providerRegistry.switchToIndex(index);
    // Providers are lightweight, no need to "switch" in service anymore

    // Clear any previous error message immediately
    _errorMessage = null;

    // Reset state before loading
    _episodes = [];
    _selectedAnime = null;
    _searchResults = [];

    // Load anime (will check cache or search)
    await loadAnime();
  }

  /// Search for anime on all providers simultaneously
  Future<void> loadAllProviders({bool forceRefresh = false}) async {
    final currentName = _providerRegistry.currentName;

    // Load current provider first to show immediate feedback
    final currentLoad = _loadForProvider(currentName, isCurrent: true, forceRefresh: forceRefresh);

    // Load other providers in parallel
    for (final name in availableProviders) {
      if (name != currentName) {
        // Unawaited background load
        _loadForProvider(
          name, // Explicitly load for this provider name
          isCurrent: false,
          forceRefresh: forceRefresh,
        );
      }
    }

    await currentLoad;
  }

  /// Search for anime on the active stream provider
  Future<void> loadAnime({bool forceRefresh = false}) async {
    await loadAllProviders(forceRefresh: forceRefresh);
  }

  // Track in-flight loads to prevent duplicate requests
  final Map<String, Future<void>> _inFlightLoads = {};

  /// Check if a specific provider is currently loading in the background
  bool isProviderLoading(String providerName) {
    return _inFlightLoads.containsKey(providerName);
  }

  /// Internal helper to load data for a specific provider
  Future<void> _loadForProvider(String providerName, {required bool isCurrent, bool forceRefresh = false}) async {
    // Check global cache first, ONLY if not forcing refresh
    if (!forceRefresh) {
      final cachedEpisodes = _streamingService.getCachedEpisodes(anime.id, providerName);

      // If we have ANY cached result (even empty), usage it.
      // This prevents reloading for providers that genuinely have no results.
      if (cachedEpisodes != null) {
        if (isCurrent) {
          _episodes = cachedEpisodes;
          _selectedAnime = _streamingService.getCachedSelectedAnime(anime.id, providerName);

          if (cachedEpisodes.isNotEmpty) {
            _state = ProviderLoadingState.loaded;
          } else {
            // Cached empty result = Valid "No results" state
            _state = ProviderLoadingState.error;
            _errorMessage = 'No results found on $providerName';
          }
          notifyListeners();
        }
        return;
      }
    }

    // Only update UI state if we are modifying the current provider
    if (isCurrent) {
      if (isLoading) return;
      _state = ProviderLoadingState.searching;
      _errorMessage = null;
      notifyListeners();
    }

    await _fetchData(providerName);

    // After fetch, update UI if current
    if (isCurrent) {
      // Re-check cache - should be populated now if successful
      final newCachedEpisodes = _streamingService.getCachedEpisodes(anime.id, providerName);

      if (newCachedEpisodes != null) {
        if (newCachedEpisodes.isNotEmpty) {
          // Success path
          _episodes = newCachedEpisodes;
          _selectedAnime = _streamingService.getCachedSelectedAnime(anime.id, providerName);
          _searchResults = _searchResults.isEmpty && _selectedAnime != null ? [_selectedAnime!] : _searchResults;
          _state = ProviderLoadingState.loaded;
        } else {
          // Valid empty result path
          _episodes = [];
          _state = ProviderLoadingState.error;
          _errorMessage ??= 'No results found on $providerName';
        }
      } else {
        // Cache is null -> Fetch failed and didn't cache result (Error case)
        // Ensure error state is shown if it wasn't already set by _fetchData
        _state = ProviderLoadingState.error;
        _errorMessage ??= 'Failed to load data';
      }
      notifyListeners();
    } else {
      // Also notify for non-current providers to update their episode counts in the UI
      notifyListeners();
    }
  }

  /// Deduplicated data fetching logic
  Future<void> _fetchData(String providerName) {
    if (_inFlightLoads.containsKey(providerName)) {
      return _inFlightLoads[providerName]!;
    }

    final future = _performFetch(providerName);
    _inFlightLoads[providerName] = future;

    return future.whenComplete(() {
      _inFlightLoads.remove(providerName);
    });
  }

  Future<void> _performFetch(String providerName) async {
    final provider = _providerRegistry.getByName(providerName);
    if (provider == null) return;

    try {
      final searchResults = await _streamingService.searchWithProvider(provider, anime);

      if (searchResults.isEmpty) {
        // Cache empty result? Maybe not needed to persist empty failures globally,
        // but for session consistency, maybe.
        // For now, if empty, we just don't set the global cache or set empty list.
        _streamingService.setCachedEpisodes(anime.id, providerName, []);
        _streamingService.setCachedSelectedAnime(anime.id, providerName, null);
      } else {
        // Auto-select first result
        final selected = searchResults.first;
        _streamingService.setCachedSelectedAnime(anime.id, providerName, selected);

        // Automatically load episodes for the first result
        try {
          final episodes = await _streamingService.getEpisodesWithProvider(provider, selected);
          _streamingService.setCachedEpisodes(anime.id, providerName, episodes);
        } catch (e) {
          // Error loading episodes: Do NOT cache empty list.
          // Keeping cache null allows retry.
          if (providerName == currentProviderName) {
            _errorMessage = 'Failed to load episodes: ${e.toString()}';
          }
        }
      }
    } catch (e) {
      // Search failed: Do NOT cache empty list.
      // Keeping cache null allows retry when user switches tabs back and forth.
      if (providerName == currentProviderName) {
        _errorMessage = 'Failed to search on $providerName: ${e.toString()}';
      }
    }
  }

  /// Load episodes for a specific anime (manual trigger only usually)
  Future<void> loadEpisodes(StreamingAnimeResult anime) async {
    final providerName = _providerRegistry.currentName;
    final provider = _providerRegistry.current;

    _state = ProviderLoadingState.loadingEpisodes;
    _errorMessage = null;
    _selectedAnime = anime;
    _streamingService.setCachedSelectedAnime(this.anime.id, providerName, anime);
    _episodes = [];
    notifyListeners();

    try {
      _episodes = await _streamingService.getEpisodesWithProvider(provider, anime);
      _streamingService.setCachedEpisodes(this.anime.id, providerName, _episodes);
      _state = ProviderLoadingState.loaded;
    } catch (e) {
      _state = ProviderLoadingState.error;
      _errorMessage = 'Failed to load episodes: ${e.toString()}';
      // Do NOT cache empty list on error
    }

    notifyListeners();
  }

  /// Load stream sources for a specific episode
  Future<void> loadSources(AnimeEpisode episode) async {
    _state = ProviderLoadingState.loadingSources;
    _errorMessage = null;
    _selectedEpisode = episode;
    _sources = [];
    notifyListeners();

    try {
      final provider =
          _providerRegistry.getByName(
            episode.id.isNotEmpty ? episode.id.split('|').last : _providerRegistry.currentName,
          ) ??
          _providerRegistry.current;
      // Note: Episode sourceId usually doesn't contain provider info, so we rely on current provider or registry.
      // Actually, we should know which provider this episode belongs to.
      // Current architecture assumes DetailViewModel is viewing "Current Provider"'s episodes.
      // So using _providerRegistry.current is correct for generating sources for THE current episode list.

      _sources = await _streamingService.getSources(provider, episode);
      // Wait, is 'provider' correct? provider is resolved from episode ID or current.
      // If episode ID has provider, we use it. If not, current.
      // This is safer than _providerRegistry.current if we ever support mixed lists.

      if (_sources.isEmpty) {
        _state = ProviderLoadingState.error;
        _errorMessage = 'No sources available for this episode';
      } else {
        _state = ProviderLoadingState.loaded;
      }
    } catch (e) {
      _state = ProviderLoadingState.error;
      _errorMessage = 'Failed to load sources: ${e.toString()}';
    }

    notifyListeners();
  }

  /// Select a different anime from search results
  void selectAnime(StreamingAnimeResult anime) {
    _selectedAnime = anime;
    _episodes = [];
    notifyListeners();
    loadEpisodes(anime);
  }

  /// Get the best quality source (preferring highest resolution)
  StreamingSource? getBestSource() {
    if (_sources.isEmpty) return null;

    // Sort by quality (assuming higher numbers are better)
    final sortedSources = List<StreamingSource>.from(_sources);
    sortedSources.sort((a, b) {
      final aQuality = int.tryParse(a.quality.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
      final bQuality = int.tryParse(b.quality.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
      return bQuality.compareTo(aQuality);
    });

    return sortedSources.first;
  }
}
