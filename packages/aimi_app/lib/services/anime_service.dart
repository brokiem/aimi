import 'package:aimi_lib/aimi_lib.dart' as lib;

import '../models/anime.dart';
import '../services/caching_service.dart';

class AnimeService {
  final Map<String, lib.IMetadataProvider> _providers;
  final CachingService _cachingService;
  late final String _defaultProviderName;

  AnimeService(List<lib.IMetadataProvider> providers, this._cachingService, {String? defaultProviderName})
    : _providers = {for (var p in providers) p.name: p} {
    if (_providers.isEmpty) {
      throw Exception('At least one provider must be provided');
    }
    _defaultProviderName = defaultProviderName ?? providers.first.name;
    if (!_providers.containsKey(_defaultProviderName)) {
      throw Exception('Default provider $_defaultProviderName not found');
    }
  }

  String get providerName => _defaultProviderName;

  lib.IMetadataProvider _getProvider([String? providerName]) {
    final name = providerName ?? _defaultProviderName;
    final provider = _providers[name];
    if (provider == null) {
      throw Exception('Provider $name not found');
    }
    return provider;
  }

  Future<List<Anime>> fetchTrending({int page = 1, bool forceRefresh = false}) async {
    // 1. Try to get from cache if not forcing refresh
    if (!forceRefresh) {
      final cachedData = await _cachingService.getData(
        cacheKey: CacheKey.trendingAnime,
        providerName: _defaultProviderName,
      );

      if (cachedData != null) {
        return (cachedData as List).map((e) => Anime.fromJson(e)).toList();
      }
    }

    // 2. Fetch from API
    final List<lib.Media> rawList = await _getProvider().fetchTrending(page: page);
    final animeList = rawList.map((media) => Anime.fromMedia(media)).toList();

    // 3. Save to cache
    // If page > 1, we want to append to existing cache instead of overwriting
    if (page > 1) {
      final existingData = await _cachingService.getData(
        cacheKey: CacheKey.trendingAnime,
        providerName: _defaultProviderName,
      );

      if (existingData != null && existingData is List) {
        final existingList = existingData.cast<Map<String, dynamic>>();

        // Create a set of existing IDs for simple deduplication
        final existingIds = existingList.map((e) => e['id']).toSet();

        final newItems = animeList.map((e) => e.toJson()).where((json) => !existingIds.contains(json['id'])).toList();

        await _cachingService.saveData(
          cacheKey: CacheKey.trendingAnime,
          data: [...existingList, ...newItems],
          expiresIn: const Duration(hours: 12),
          providerName: _defaultProviderName,
        );
      } else {
        // Fallback if cache thinks it exists but is invalid/expired mid-session
        await _cachingService.saveData(
          cacheKey: CacheKey.trendingAnime,
          data: animeList.map((e) => e.toJson()).toList(),
          expiresIn: const Duration(hours: 12),
          providerName: _defaultProviderName,
        );
      }
    } else {
      // Page 1 - overwrite cache (fresh start)
      await _cachingService.saveData(
        cacheKey: CacheKey.trendingAnime,
        data: animeList.map((e) => e.toJson()).toList(),
        expiresIn: const Duration(hours: 12),
        providerName: _defaultProviderName,
      );
    }

    return animeList;
  }

  Future<Anime> getById(int id, {String? providerName, bool forceRefresh = false}) async {
    final targetProvider = providerName ?? _defaultProviderName;
    final cacheKey = 'anime_details/$id';

    // 1. Try to get from cache
    if (!forceRefresh) {
      final cachedData = await _cachingService.getData(dynamicKey: cacheKey, providerName: targetProvider);
      if (cachedData != null) {
        return Anime.fromJson(Map<String, dynamic>.from(cachedData));
      }
    }

    // 2. Fetch from API
    final lib.Media rawMedia = await _getProvider(targetProvider).fetchAnimeById(id);
    final anime = Anime.fromMedia(rawMedia);

    // 3. Save to cache (Permanent cache for details)
    await _cachingService.saveData(dynamicKey: cacheKey, data: anime.toJson(), providerName: targetProvider);

    return anime;
  }

  Future<List<Anime>> search(String query) async {
    // Search is usually not cached aggressively or handled differently
    // But we can cache specific queries if needed.
    // For now, let's keep it direct, but maybe add simple caching later.
    final List<lib.Media> rawList = await _getProvider().searchAnime(query);
    return rawList.map((media) => Anime.fromMedia(media)).toList();
  }

  // --- Search History ---

  Future<List<String>> getSearchHistory() async {
    final data = await _cachingService.getData(cacheKey: CacheKey.searchHistory, providerName: _defaultProviderName);
    if (data != null) {
      return List<String>.from(data);
    }
    return [];
  }

  Future<void> addToSearchHistory(String query) async {
    if (query.trim().isEmpty) return;

    List<String> history = await getSearchHistory();

    // Remove if exists to move to top
    history.remove(query);
    history.insert(0, query);

    // Limit history to 20 items
    if (history.length > 20) {
      history = history.sublist(0, 20);
    }

    await _cachingService.saveData(cacheKey: CacheKey.searchHistory, data: history, providerName: _defaultProviderName);
  }

  Future<void> removeFromSearchHistory(String query) async {
    List<String> history = await getSearchHistory();
    history.remove(query);
    await _cachingService.saveData(cacheKey: CacheKey.searchHistory, data: history, providerName: _defaultProviderName);
  }

  Future<void> clearSearchHistory() async {
    await _cachingService.removeData(cacheKey: CacheKey.searchHistory, providerName: _defaultProviderName);
  }
}
