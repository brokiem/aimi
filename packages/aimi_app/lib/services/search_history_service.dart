import 'storage_service.dart';

/// Service for managing search history.
///
/// Stores search queries in persistent storage and provides
/// methods for managing the history list.
class SearchHistoryService {
  final StorageService _storageService;

  /// Maximum number of entries to keep in history
  static const int _maxHistoryEntries = 20;

  SearchHistoryService(this._storageService);

  /// Get the search history list.
  ///
  /// Returns an empty list if no history exists.
  Future<List<String>> getHistory() async {
    final data = await _storageService.get(key: StorageKey.searchHistory);
    if (data != null) {
      return List<String>.from(data);
    }
    return [];
  }

  /// Add a query to search history.
  ///
  /// Moves existing queries to the top and limits history to [_maxHistoryEntries].
  Future<void> addToHistory(String query) async {
    if (query.trim().isEmpty) return;

    List<String> history = await getHistory();

    // Remove if exists to move to top
    history.remove(query);
    history.insert(0, query);

    // Limit history
    if (history.length > _maxHistoryEntries) {
      history = history.sublist(0, _maxHistoryEntries);
    }

    await _storageService.save(key: StorageKey.searchHistory, data: history);
  }

  /// Remove a specific query from history.
  Future<void> removeFromHistory(String query) async {
    List<String> history = await getHistory();
    history.remove(query);
    await _storageService.save(key: StorageKey.searchHistory, data: history);
  }

  /// Clear all search history.
  Future<void> clearHistory() async {
    await _storageService.remove(key: StorageKey.searchHistory);
  }
}
