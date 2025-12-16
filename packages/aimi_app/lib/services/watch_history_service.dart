import 'dart:async';

import '../models/watch_history_entry.dart';
import 'storage_service.dart';

/// Service for managing watch history and playback progress.
///
/// Uses [StorageService] for persistent storage with provider-specific keys.
class WatchHistoryService {
  final StorageService _storageService;

  /// Maximum number of entries to keep in history
  static const int _maxHistoryEntries = 100;

  /// Threshold for marking an episode as completed (96%)
  static const double completionThreshold = 0.96;

  WatchHistoryService(this._storageService);

  final _updateController = StreamController<WatchHistoryEntry>.broadcast();
  final _dataChangedController = StreamController<void>.broadcast();

  /// Stream of watch history entries that have been updated.
  Stream<WatchHistoryEntry> get onProgressUpdated => _updateController.stream;

  /// Stream that fires when bulk data changes occur (import, clear).
  Stream<void> get onDataChanged => _dataChangedController.stream;

  /// Generate the dynamic key for a specific episode's progress.
  String _progressDynamicKey(int animeId, String episodeId) {
    return '$animeId/$episodeId';
  }

  /// Save playback progress for an episode.
  ///
  /// Automatically marks the episode as completed if progress exceeds [completionThreshold].
  Future<void> saveProgress(WatchHistoryEntry entry) async {
    // Determine if this should be marked as completed
    final isCompleted = entry.progress >= completionThreshold || entry.isCompleted;
    final updatedEntry = entry.copyWith(isCompleted: isCompleted, lastWatched: DateTime.now());

    // Save progress
    final dynamicKey = _progressDynamicKey(entry.animeId, entry.episodeId);
    await _storageService.saveDynamic(
      key: StorageKey.watchProgress,
      dynamicKey: dynamicKey,
      data: updatedEntry.toJson(),
      providerName: entry.streamProviderName,
    );

    // Update watch history list
    await _addToHistory(updatedEntry);

    // Notify listeners
    _updateController.add(updatedEntry);
  }

  /// Get the saved progress for a specific episode.
  ///
  /// Returns null if no progress is saved.
  Future<WatchHistoryEntry?> getProgress(String providerName, int animeId, String episodeId) async {
    final dynamicKey = _progressDynamicKey(animeId, episodeId);
    final data = await _storageService.getDynamic(
      key: StorageKey.watchProgress,
      dynamicKey: dynamicKey,
      providerName: providerName,
    );
    if (data != null) {
      return WatchHistoryEntry.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  /// Find the latest progress for a specific episode across ANY provider.
  ///
  /// This is useful when switching providers to resume playback.
  Future<WatchHistoryEntry?> findLatestProgress(int animeId, String episodeNumber) async {
    final history = await getWatchHistory();

    // Filter for matching animeId and episodeNumber
    final matches = history.where((e) => e.animeId == animeId && e.episodeNumber == episodeNumber);

    if (matches.isEmpty) return null;

    // Return the first match (history is already sorted by lastWatched descending)
    return matches.first;
  }

  /// Get the saved playback position for a specific episode.
  ///
  /// Returns Duration.zero if no progress is saved.
  Future<Duration> getPosition(String providerName, int animeId, String episodeId) async {
    final entry = await getProgress(providerName, animeId, episodeId);
    return entry?.position ?? Duration.zero;
  }

  /// Check if an episode has been watched to completion.
  Future<bool> isWatched(String providerName, int animeId, String episodeId) async {
    final entry = await getProgress(providerName, animeId, episodeId);
    return entry?.isCompleted ?? false;
  }

  /// Mark an episode as watched (completed).
  Future<void> markAsWatched(WatchHistoryEntry entry) async {
    final updatedEntry = entry.copyWith(isCompleted: true, lastWatched: DateTime.now());
    final dynamicKey = _progressDynamicKey(entry.animeId, entry.episodeId);
    await _storageService.saveDynamic(
      key: StorageKey.watchProgress,
      dynamicKey: dynamicKey,
      data: updatedEntry.toJson(),
      providerName: entry.streamProviderName,
    );
    await _addToHistory(updatedEntry);
  }

  /// Get all watched episodes for a specific anime and provider.
  Future<List<WatchHistoryEntry>> getWatchedEpisodesForAnime(String providerName, int animeId) async {
    final history = await getWatchHistory();
    return history.where((e) => e.streamProviderName == providerName && e.animeId == animeId && e.isCompleted).toList();
  }

  /// Get the watch history list, sorted by most recently watched.
  Future<List<WatchHistoryEntry>> getWatchHistory({int? limit}) async {
    final data = await _storageService.get(key: StorageKey.watchHistory);
    if (data == null) return [];

    final List<dynamic> historyList = data as List<dynamic>;
    final entries = historyList.map((e) => WatchHistoryEntry.fromJson(Map<String, dynamic>.from(e))).toList();

    // Sort by last watched (newest first)
    entries.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));

    if (limit != null && entries.length > limit) {
      return entries.take(limit).toList();
    }
    return entries;
  }

  /// Add or update an entry in the watch history list.
  Future<void> _addToHistory(WatchHistoryEntry entry) async {
    final history = await getWatchHistory();

    // Remove existing entry for the same episode if present
    history.removeWhere(
      (e) =>
          e.animeId == entry.animeId &&
          e.episodeId == entry.episodeId &&
          e.streamProviderName == entry.streamProviderName,
    );

    // Add new entry at the beginning
    history.insert(0, entry);

    // Trim to max size
    final trimmed = history.take(_maxHistoryEntries).toList();

    // Save updated history
    await _storageService.save(key: StorageKey.watchHistory, data: trimmed.map((e) => e.toJson()).toList());
  }

  /// Clear all watch progress for a specific episode.
  Future<void> clearProgress(String providerName, int animeId, String episodeId) async {
    final dynamicKey = _progressDynamicKey(animeId, episodeId);
    await _storageService.removeDynamic(
      key: StorageKey.watchProgress,
      dynamicKey: dynamicKey,
      providerName: providerName,
    );
  }

  /// Clear all watch history.
  Future<void> clearHistory() async {
    await _storageService.remove(key: StorageKey.watchHistory);
    _dataChangedController.add(null);
  }

  /// Notify listeners that bulk data has changed (e.g., after import).
  void notifyDataChanged() {
    _dataChangedController.add(null);
  }

  /// Get the best resume position for an episode, checking both exact provider match
  /// and cross-provider matches (if enabled/available).
  Future<ResumePositionResult> getResumePosition({
    required String providerName,
    required int animeId,
    required String episodeId,
    String? episodeNumber,
  }) async {
    Duration targetPosition = Duration.zero;
    bool isCrossProvider = false;
    int? matchDurationMs;

    // 1. Try to get progress for the current provider (Exact match)
    final exactEntry = await getProgress(providerName, animeId, episodeId);

    if (episodeNumber != null) {
      // 2. Fallback: Cross-provider match
      final crossMatch = await findLatestProgress(animeId, episodeNumber);

      // Use crossMatch if:
      // - No exactEntry yet, OR
      // - crossMatch is newer than exactEntry
      if (crossMatch != null) {
        if (exactEntry == null || crossMatch.lastWatched.isAfter(exactEntry.lastWatched)) {
          targetPosition = crossMatch.position;
          isCrossProvider = true;
          matchDurationMs = crossMatch.durationMs;
        } else {
          // exactEntry is newer (or same), use it
          targetPosition = exactEntry.position;
          isCrossProvider = false;
        }
      } else if (exactEntry != null) {
        targetPosition = exactEntry.position;
      }
    } else if (exactEntry != null) {
      targetPosition = exactEntry.position;
    }

    return ResumePositionResult(
      position: targetPosition,
      isCrossProvider: isCrossProvider,
      matchDurationMs: matchDurationMs,
    );
  }
}

class ResumePositionResult {
  final Duration position;
  final bool isCrossProvider;
  final int? matchDurationMs;

  const ResumePositionResult({required this.position, this.isCrossProvider = false, this.matchDurationMs});
}
