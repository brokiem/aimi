import 'package:aimi_app/services/watch_history_service.dart';
import 'package:flutter/foundation.dart';

import '../models/anime.dart';
import '../models/watch_history_entry.dart';
import '../services/anime_service.dart';

class HomeViewModel extends ChangeNotifier {
  final AnimeService _animeService;
  final WatchHistoryService? _watchHistoryService;

  HomeViewModel(this._animeService, [this._watchHistoryService]);

  final List<Anime> _trendingAnime = [];

  List<Anime> get trendingAnime => _trendingAnime;

  int _currentPage = 1;

  int get currentPage => _currentPage;

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  String? _errorMessage;

  String? get errorMessage => _errorMessage;

  // Watch history state
  final List<WatchHistoryEntry> _watchHistory = [];
  final List<Anime> _watchedAnime = [];
  bool _isLoadingHistory = false;
  String? _historyError;

  List<WatchHistoryEntry> get watchHistory => _watchHistory;

  List<Anime> get watchedAnime => _watchedAnime;

  bool get isLoadingHistory => _isLoadingHistory;

  String? get historyError => _historyError;

  Future<void> fetchTrending() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _trendingAnime.clear();

      final animeList = await _animeService.fetchTrending(page: 1);
      _trendingAnime.addAll(animeList);

      _currentPage = 1;
    } catch (e) {
      _errorMessage = 'Failed to load trending anime: ${e.toString()}';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreTrendingAnime() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _currentPage++;

      final animeList = await _animeService.fetchTrending(page: _currentPage, forceRefresh: true);
      _trendingAnime.addAll(animeList);
    } catch (e) {
      _errorMessage = 'Failed to load more trending anime: ${e.toString()}';
      _currentPage--; // Revert page increment on error
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch watch history and load anime details for each unique anime
  Future<void> fetchWatchHistory() async {
    if (_watchHistoryService == null) return;

    try {
      _isLoadingHistory = true;
      _historyError = null;
      notifyListeners();

      // Get watch history entries
      final history = await _watchHistoryService.getWatchHistory();
      _watchHistory.clear();
      _watchHistory.addAll(history);

      // Get unique anime IDs from history
      final uniqueAnimeIds = history.map((e) => e.animeId).toSet().toList();

      // Fetch anime details for each unique anime ID
      _watchedAnime.clear();
      for (final animeId in uniqueAnimeIds) {
        try {
          // 1. Try to get from memory cache first (trending anime)
          final memCached = _trendingAnime.where((a) => a.id == animeId).firstOrNull;
          if (memCached != null) {
            _watchedAnime.add(memCached);
            continue;
          }

          // 2. Fetch from Repo (Service handles persistence checks)
          // Use metadataProviderName for anime details lookup
          final entry = history.firstWhere((e) => e.animeId == animeId);
          final metadataProviderName = entry.metadataProviderName;

          final anime = await _animeService.getById(animeId, providerName: metadataProviderName);
          _watchedAnime.add(anime);
        } catch (e) {
          // Skip anime that fail to load
          debugPrint('Failed to load anime $animeId: $e');
        }
      }
    } catch (e) {
      _historyError = 'Failed to load watch history: ${e.toString()}';
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }
}
