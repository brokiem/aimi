import 'dart:async';

import 'package:aimi_app/models/anime.dart';
import 'package:aimi_app/models/watch_history_entry.dart';
import 'package:aimi_app/services/anime_service.dart';
import 'package:aimi_app/services/watch_history_service.dart';
import 'package:flutter/foundation.dart';

class HistoryViewModel extends ChangeNotifier {
  final WatchHistoryService _watchHistoryService;
  final AnimeService _animeService;

  StreamSubscription<WatchHistoryEntry>? _historyUpdateSubscription;
  StreamSubscription<void>? _dataChangedSubscription;

  HistoryViewModel(this._watchHistoryService, this._animeService) {
    // Listen to watch history updates
    _historyUpdateSubscription = _watchHistoryService.onProgressUpdated.listen((entry) {
      fetchWatchHistory();
    });
    // Listen to bulk data changes (import/clear)
    _dataChangedSubscription = _watchHistoryService.onDataChanged.listen((_) {
      fetchWatchHistory();
    });
  }

  final List<WatchHistoryEntry> _watchHistory = [];
  final List<Anime> _watchedAnime = [];
  bool _isLoadingHistory = false;
  String? _historyError;

  List<WatchHistoryEntry> get watchHistory => _watchHistory;

  List<Anime> get watchedAnime => _watchedAnime;

  bool get isLoadingHistory => _isLoadingHistory;

  String? get historyError => _historyError;

  /// Fetch watch history and load anime details for each unique anime
  Future<void> fetchWatchHistory() async {
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
          // We don't have access to trending cache here directly, but AnimeService should handle caching.
          // If we strictly want to leverage memory cache of HomeViewModel, we'd need a shared cache service
          // or pass it in. However, AnimeService uses CachingService which is memory+disk based,
          // so it should be fast enough.

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

  @override
  void dispose() {
    _historyUpdateSubscription?.cancel();
    _dataChangedSubscription?.cancel();
    super.dispose();
  }
}
