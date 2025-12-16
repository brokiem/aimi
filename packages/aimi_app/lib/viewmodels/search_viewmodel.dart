import 'package:flutter/foundation.dart';

import '../models/anime.dart';
import '../services/anime_service.dart';
import '../services/search_history_service.dart';

class SearchViewModel extends ChangeNotifier {
  final AnimeService _animeService;
  final SearchHistoryService _searchHistoryService;

  SearchViewModel(this._animeService, this._searchHistoryService) {
    _loadHistory();
  }

  List<String> _history = [];

  List<String> get history => _history;

  List<Anime> _searchResults = [];

  List<Anime> get searchResults => _searchResults;

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  String? _errorMessage;

  String? get errorMessage => _errorMessage;

  bool _hasSearched = false;

  bool get hasSearched => _hasSearched;

  Future<void> _loadHistory() async {
    _history = await _searchHistoryService.getHistory();
    notifyListeners();
  }

  Future<void> removeFromHistory(String query) async {
    await _searchHistoryService.removeFromHistory(query);
    await _loadHistory(); // Reload to update UI
  }

  Future<void> clearHistory() async {
    await _searchHistoryService.clearHistory();
    await _loadHistory();
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;

    try {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
      notifyListeners();

      await _searchHistoryService.addToHistory(query);
      // Reload history to show the new item immediately if we switch views or it's visible
      _loadHistory();

      _searchResults = await _animeService.search(query);
    } catch (e) {
      _errorMessage = 'Failed to search anime: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearResults() {
    _searchResults = [];
    _hasSearched = false;
    _errorMessage = null;
    notifyListeners();
  }
}
