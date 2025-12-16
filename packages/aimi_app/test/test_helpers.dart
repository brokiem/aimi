import 'dart:convert';

import 'package:aimi_app/models/anime.dart';
import 'package:aimi_app/models/anime_episode.dart';
import 'package:aimi_app/models/streaming_anime_result.dart';
import 'package:aimi_app/models/streaming_source.dart';
import 'package:aimi_app/services/anime_service.dart';
import 'package:aimi_app/services/caching_service.dart';
import 'package:aimi_app/services/search_history_service.dart';
import 'package:aimi_app/services/storage_service.dart';
import 'package:aimi_app/services/streaming_service.dart';
import 'package:aimi_app/services/watch_history_service.dart';
import 'package:aimi_lib/aimi_lib.dart' as lib;

// =============================================================================
// FAKE CACHING SERVICE
// =============================================================================

/// Fake implementation of CachingService for testing.
///
/// Stores data in memory with optional expiration simulation.
class FakeCachingService implements CachingService {
  final Map<String, _CacheEntry> _storage = {};

  // ===========================================================================
  // Simple Key Methods
  // ===========================================================================

  @override
  Future<void> save({required CacheKey key, required dynamic data, Duration? expiresIn, String? providerName}) async {
    final fullKey = _generateKey(key.name, null, providerName);
    _storage[fullKey] = _CacheEntry(data: data, expiresAt: expiresIn != null ? DateTime.now().add(expiresIn) : null);
  }

  @override
  Future<dynamic> get({required CacheKey key, String? providerName}) async {
    final fullKey = _generateKey(key.name, null, providerName);
    return _getWithExpiration(fullKey);
  }

  @override
  Future<void> remove({required CacheKey key, String? providerName}) async {
    final fullKey = _generateKey(key.name, null, providerName);
    _storage.remove(fullKey);
  }

  // ===========================================================================
  // Dynamic Key Methods
  // ===========================================================================

  @override
  Future<void> saveDynamic({
    required CacheKey key,
    required String dynamicKey,
    required dynamic data,
    Duration? expiresIn,
    String? providerName,
  }) async {
    final fullKey = _generateKey(key.name, dynamicKey, providerName);
    _storage[fullKey] = _CacheEntry(data: data, expiresAt: expiresIn != null ? DateTime.now().add(expiresIn) : null);
  }

  @override
  Future<dynamic> getDynamic({required CacheKey key, required String dynamicKey, String? providerName}) async {
    final fullKey = _generateKey(key.name, dynamicKey, providerName);
    return _getWithExpiration(fullKey);
  }

  @override
  Future<void> removeDynamic({required CacheKey key, required String dynamicKey, String? providerName}) async {
    final fullKey = _generateKey(key.name, dynamicKey, providerName);
    _storage.remove(fullKey);
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  dynamic _getWithExpiration(String fullKey) {
    final entry = _storage[fullKey];
    if (entry == null) return null;

    // Check expiration
    if (entry.expiresAt != null && entry.expiresAt!.isBefore(DateTime.now())) {
      _storage.remove(fullKey);
      return null;
    }

    return entry.data;
  }

  String _generateKey(String keyName, String? dynamicKey, String? providerName) {
    final parts = <String>['cache'];
    if (providerName != null) {
      parts.add(base64Encode(utf8.encode(providerName)));
    }
    parts.add(keyName);
    if (dynamicKey != null) {
      parts.add(dynamicKey);
    }
    return parts.join('/');
  }

  /// Clear all stored data (useful for test cleanup)
  void clear() => _storage.clear();

  /// Check if a key exists (useful for assertions)
  bool containsKey(String key, {String? dynamicKey, String? providerName}) {
    return _storage.containsKey(_generateKey(key, dynamicKey, providerName));
  }

  @override
  Future<void> clearAll() async {
    _storage.clear();
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime? expiresAt;

  _CacheEntry({required this.data, this.expiresAt});
}

// =============================================================================
// FAKE STORAGE SERVICE
// =============================================================================

/// Fake implementation of StorageService for testing.
///
/// Stores persistent data in memory.
class FakeStorageService implements StorageService {
  final Map<String, dynamic> _storage = {};

  // ===========================================================================
  // Simple Key Methods
  // ===========================================================================

  @override
  Future<void> save({required StorageKey key, required dynamic data, String? providerName}) async {
    final fullKey = _generateKey(key.name, null, providerName);
    _storage[fullKey] = data;
  }

  @override
  Future<dynamic> get({required StorageKey key, String? providerName}) async {
    final fullKey = _generateKey(key.name, null, providerName);
    return _storage[fullKey];
  }

  @override
  Future<void> remove({required StorageKey key, String? providerName}) async {
    final fullKey = _generateKey(key.name, null, providerName);
    _storage.remove(fullKey);
  }

  // ===========================================================================
  // Dynamic Key Methods
  // ===========================================================================

  @override
  Future<void> saveDynamic({
    required StorageKey key,
    required String dynamicKey,
    required dynamic data,
    String? providerName,
  }) async {
    final fullKey = _generateKey(key.name, dynamicKey, providerName);
    _storage[fullKey] = data;
  }

  @override
  Future<dynamic> getDynamic({required StorageKey key, required String dynamicKey, String? providerName}) async {
    final fullKey = _generateKey(key.name, dynamicKey, providerName);
    return _storage[fullKey];
  }

  @override
  Future<void> removeDynamic({required StorageKey key, required String dynamicKey, String? providerName}) async {
    final fullKey = _generateKey(key.name, dynamicKey, providerName);
    _storage.remove(fullKey);
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  String _generateKey(String keyName, String? dynamicKey, String? providerName) {
    final parts = <String>['storage'];
    if (providerName != null) {
      parts.add(base64Encode(utf8.encode(providerName)));
    }
    parts.add(keyName);
    if (dynamicKey != null) {
      parts.add(dynamicKey);
    }
    return parts.join('/');
  }

  /// Clear all stored data (useful for test cleanup)
  void clear() => _storage.clear();

  /// Check if a key exists (useful for assertions)
  bool containsKey(String key, {String? dynamicKey, String? providerName}) {
    return _storage.containsKey(_generateKey(key, dynamicKey, providerName));
  }

  @override
  Future<Map<String, dynamic>> getAllData() async {
    return Map.from(_storage);
  }

  @override
  Future<void> importData(Map<String, dynamic> data) async {
    _storage.addAll(data);
  }

  @override
  Future<void> clearAll() async {
    _storage.clear();
  }
}

// =============================================================================
// FAKE SEARCH HISTORY SERVICE
// =============================================================================

/// Fake implementation of SearchHistoryService for testing.
class FakeSearchHistoryService implements SearchHistoryService {
  List<String> _history = [];

  @override
  Future<List<String>> getHistory() async {
    return List.from(_history);
  }

  @override
  Future<void> addToHistory(String query) async {
    if (query.trim().isEmpty) return;
    _history.remove(query);
    _history.insert(0, query);
    if (_history.length > 20) {
      _history = _history.sublist(0, 20);
    }
  }

  @override
  Future<void> removeFromHistory(String query) async {
    _history.remove(query);
  }

  @override
  Future<void> clearHistory() async {
    _history.clear();
  }

  /// Clear all stored data (useful for test cleanup)
  void clear() => _history.clear();
}

// =============================================================================
// FAKE METADATA PROVIDER
// =============================================================================

/// Fake implementation of IMetadataProvider for testing.
class FakeMetadataProvider implements lib.IMetadataProvider {
  final String _name;
  final Map<int, lib.Media> _animeMap = {};
  bool shouldThrow = false;
  String? errorMessage;

  FakeMetadataProvider(this._name);

  void addAnime(lib.Media anime) {
    _animeMap[anime.id] = anime;
  }

  void setAnimeList(List<lib.Media> animeList) {
    _animeMap.clear();
    for (final anime in animeList) {
      _animeMap[anime.id] = anime;
    }
  }

  @override
  String get name => _name;

  @override
  String get version => '1.0.0';

  @override
  Future<lib.Media> fetchAnimeById(int id) async {
    if (shouldThrow) {
      throw Exception(errorMessage ?? 'Test error');
    }
    if (_animeMap.containsKey(id)) {
      return _animeMap[id]!;
    }
    throw Exception('Anime $id not found in $_name');
  }

  @override
  Future<List<lib.Media>> fetchTrending({int page = 1}) async {
    if (shouldThrow) {
      throw Exception(errorMessage ?? 'Test error');
    }
    return _animeMap.values.toList();
  }

  @override
  Future<List<lib.Media>> searchAnime(String query, {int page = 1}) async {
    if (shouldThrow) {
      throw Exception(errorMessage ?? 'Test error');
    }
    return _animeMap.values
        .where(
          (a) =>
              (a.title.english?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
              (a.title.romaji?.toLowerCase().contains(query.toLowerCase()) ?? false),
        )
        .toList();
  }

  @override
  void dispose() {}
}

// =============================================================================
// FAKE STREAM PROVIDER
// =============================================================================

/// Fake implementation of IStreamProvider for testing.
class FakeStreamProvider implements lib.IStreamProvider {
  final String _name;
  final List<lib.StreamableAnime> _searchResults = [];
  final Map<String, List<lib.Episode>> _episodes = {};
  final Map<String, List<lib.StreamSource>> _sources = {};
  bool shouldThrow = false;
  String? errorMessage;

  FakeStreamProvider(this._name);

  void setSearchResults(List<lib.StreamableAnime> results) {
    _searchResults.clear();
    _searchResults.addAll(results);
  }

  void setEpisodes(String animeId, List<lib.Episode> episodes) {
    _episodes[animeId] = episodes;
  }

  void setSources(String episodeId, List<lib.StreamSource> sources) {
    _sources[episodeId] = sources;
  }

  @override
  String get name => _name;

  @override
  String get version => '1.0.0';

  @override
  Future<List<lib.StreamableAnime>> search(dynamic query) async {
    if (shouldThrow) {
      throw Exception(errorMessage ?? 'Test error');
    }
    final searchQuery = query is String ? query : query.toString();
    return _searchResults.where((a) => a.title.toLowerCase().contains(searchQuery.toLowerCase())).toList();
  }

  @override
  Future<List<lib.Episode>> getEpisodes(lib.StreamableAnime anime) async {
    if (shouldThrow) {
      throw Exception(errorMessage ?? 'Test error');
    }
    return _episodes[anime.id] ?? [];
  }

  @override
  Future<List<lib.StreamSource>> getSources(lib.Episode episode, {Map<String, dynamic>? options}) async {
    if (shouldThrow) {
      throw Exception(errorMessage ?? 'Test error');
    }
    return _sources[episode.sourceId] ?? [];
  }

  @override
  void dispose() {}
}

// =============================================================================
// FAKE ANIME SERVICE
// =============================================================================

/// Fake implementation of AnimeService for testing ViewModels.
class FakeAnimeService implements AnimeService {
  final List<Anime> _trendingAnime = [];
  final List<Anime> _searchResults = [];
  final Map<int, Anime> _animeById = {};
  bool shouldThrow = false;
  String? errorMessage;

  void setTrendingAnime(List<Anime> anime) {
    _trendingAnime.clear();
    _trendingAnime.addAll(anime);
  }

  void setSearchResults(List<Anime> results) {
    _searchResults.clear();
    _searchResults.addAll(results);
  }

  void setAnimeById(int id, Anime anime) {
    _animeById[id] = anime;
  }

  @override
  String get providerName => 'FakeProvider';

  @override
  Future<List<Anime>> fetchTrending({int page = 1, bool forceRefresh = false}) async {
    if (shouldThrow) throw Exception(errorMessage ?? 'Test error');
    return _trendingAnime;
  }

  @override
  Future<Anime> getById(int id, {String? providerName, bool forceRefresh = false}) async {
    if (shouldThrow) throw Exception(errorMessage ?? 'Test error');
    if (_animeById.containsKey(id)) {
      return _animeById[id]!;
    }
    throw Exception('Anime $id not found');
  }

  @override
  Future<List<Anime>> search(String query) async {
    if (shouldThrow) throw Exception(errorMessage ?? 'Test error');
    return _searchResults;
  }
}

// =============================================================================
// FAKE STREAMING SERVICE
// =============================================================================

/// Fake implementation of StreamingService for testing ViewModels.
class FakeStreamingService implements StreamingService {
  final Map<String, List<AnimeEpisode>> _cachedEpisodes = {};
  final Map<String, StreamingAnimeResult?> _cachedSelectedAnime = {};
  List<StreamingAnimeResult> _searchResults = [];
  List<AnimeEpisode> _episodes = [];
  List<StreamingSource> _sources = [];
  bool shouldThrow = false;

  void setSearchResults(List<StreamingAnimeResult> results) {
    _searchResults = results;
  }

  void setEpisodes(List<AnimeEpisode> episodes) {
    _episodes = episodes;
  }

  void setSources(List<StreamingSource> sources) {
    _sources = sources;
  }

  @override
  Future<List<StreamingAnimeResult>> searchWithProvider(lib.IStreamProvider provider, Anime anime) async {
    if (shouldThrow) throw Exception('Test error');
    return _searchResults;
  }

  @override
  Future<List<AnimeEpisode>> getEpisodesWithProvider(lib.IStreamProvider provider, StreamingAnimeResult anime) async {
    if (shouldThrow) throw Exception('Test error');
    return _episodes;
  }

  @override
  Future<List<StreamingSource>> getSources(lib.IStreamProvider provider, AnimeEpisode episode) async {
    if (shouldThrow) throw Exception('Test error');
    return _sources;
  }

  @override
  List<AnimeEpisode>? getCachedEpisodes(int animeId, String providerName) {
    return _cachedEpisodes['${animeId}_$providerName'];
  }

  @override
  void setCachedEpisodes(int animeId, String providerName, List<AnimeEpisode> episodes) {
    _cachedEpisodes['${animeId}_$providerName'] = episodes;
  }

  @override
  StreamingAnimeResult? getCachedSelectedAnime(int animeId, String providerName) {
    return _cachedSelectedAnime['${animeId}_$providerName'];
  }

  @override
  void setCachedSelectedAnime(int animeId, String providerName, StreamingAnimeResult? anime) {
    _cachedSelectedAnime['${animeId}_$providerName'] = anime;
  }
}

// =============================================================================
// FAKE WATCH HISTORY SERVICE
// =============================================================================

/// Fake implementation of WatchHistoryService for testing ViewModels.
class FakeWatchHistoryService extends WatchHistoryService {
  FakeWatchHistoryService(super.cachingService);
}

// =============================================================================
// TEST DATA FACTORIES
// =============================================================================

/// Factory for creating test Anime objects.
class TestAnimeFactory {
  static Anime createAnime({
    int id = 1,
    String? englishTitle,
    String? romajiTitle,
    String nativeTitle = 'テスト',
    String type = 'TV',
    String status = 'FINISHED',
    String description = 'Test description',
    int? episodes,
    List<String> genres = const ['Action'],
  }) {
    return Anime(
      id: id,
      title: AnimeTitle(
        english: englishTitle ?? 'Test Anime $id',
        romaji: romajiTitle ?? 'Tesuto Anime $id',
        native: nativeTitle,
      ),
      type: type,
      status: status,
      description: description,
      episodes: episodes,
      countryOfOrigin: 'JP',
      characters: [],
      staff: [],
      studios: [],
      coverImage: CoverImage(extraLarge: 'https://example.com/xl.jpg', large: 'https://example.com/l.jpg'),
      genres: genres,
      synonyms: [],
      siteUrl: 'https://example.com/anime/$id',
    );
  }

  static lib.Media createMedia({
    int id = 1,
    String? englishTitle,
    String? romajiTitle,
    String nativeTitle = 'テスト',
    String type = 'TV',
    String status = 'FINISHED',
    String description = 'Test description',
  }) {
    return lib.Media(
      id: id,
      title: lib.AnimeTitle(
        english: englishTitle ?? 'Test Anime $id',
        romaji: romajiTitle ?? 'Tesuto Anime $id',
        native: nativeTitle,
      ),
      type: type,
      status: status,
      description: description,
      countryOfOrigin: 'JP',
      updatedAt: 0,
      coverImage: lib.CoverImage(extraLarge: 'https://example.com/xl.jpg', large: 'https://example.com/l.jpg'),
      siteUrl: 'https://example.com/anime/$id',
    );
  }

  static AnimeEpisode createEpisode({
    String id = 'ep-1',
    String animeId = 'anime-1',
    String number = '1',
    String? title,
    String? thumbnail,
    int? duration,
  }) {
    return AnimeEpisode(
      id: id,
      animeId: animeId,
      number: number,
      title: title,
      thumbnail: thumbnail,
      duration: duration,
    );
  }

  static StreamingAnimeResult createStreamingResult({
    String id = 'stream-1',
    String title = 'Test Anime',
    int availableEpisodes = 12,
  }) {
    return StreamingAnimeResult(id: id, title: title, availableEpisodes: availableEpisodes);
  }

  static StreamingSource createSource({
    String url = 'https://example.com/stream.m3u8',
    String quality = '1080p',
    bool isM3U8 = true,
  }) {
    return StreamingSource(url: url, quality: quality, isM3U8: isM3U8, subtitles: []);
  }
}

// =============================================================================
// FAKE PREFERENCES SERVICE
// =============================================================================

/// Fake implementation of PreferencesService for testing.
///
/// Stores preferences in memory without SharedPreferences dependency.
class FakePreferencesService {
  final Map<String, dynamic> _prefs = {};

  Future<T?> get<T>(PrefKey key) async {
    return _prefs[key.name] as T?;
  }

  Future<void> set<T>(PrefKey key, T value) async {
    _prefs[key.name] = value;
  }

  Future<void> remove(PrefKey key) async {
    _prefs.remove(key.name);
  }

  Future<Map<String, dynamic>> getAllPreferences() async {
    return Map.from(_prefs);
  }

  Future<void> clearAll() async {
    _prefs.clear();
  }

  /// Test helper to pre-populate preferences
  void setAll(Map<String, dynamic> values) {
    _prefs.addAll(values);
  }

  /// Test helper to check if empty
  bool get isEmpty => _prefs.isEmpty;
}

/// Preference keys enum copy for tests (avoids importing preferences_service.dart)
enum PrefKey {
  subtitlePreference,
  audioPreference,
  videoVolume,
  themeMode,
  seedColor,
  enableHeroAnimation,
  titleLanguagePreference,
}

// =============================================================================
// FAKE SETTINGS SERVICE
// =============================================================================

/// Fake implementation of SettingsService for testing.
///
/// Provides controllable settings values without persistence.
class FakeSettingsService {
  bool enableHeroAnimation = true;
  String titleLanguagePreference = 'english';

  int notifyCount = 0;

  void setEnableHeroAnimation(bool value) {
    enableHeroAnimation = value;
    notifyCount++;
  }

  void setTitleLanguagePreference(String value) {
    titleLanguagePreference = value;
    notifyCount++;
  }

  void reset() {
    enableHeroAnimation = true;
    titleLanguagePreference = 'english';
    notifyCount = 0;
  }
}
