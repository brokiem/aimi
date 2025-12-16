import 'package:aimi_lib/aimi_lib.dart' as lib;

import '../models/anime.dart';
import '../services/caching_service.dart';
import '../services/storage_service.dart';

class AnimeService {
  final Map<String, lib.IMetadataProvider> _providers;
  final CachingService _cachingService;
  final StorageService _storageService;
  late final String _defaultProviderName;

  AnimeService(
    List<lib.IMetadataProvider> providers,
    this._cachingService,
    this._storageService, {
    String? defaultProviderName,
  }) : _providers = {for (var p in providers) p.name: p} {
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
      final cachedData = await _cachingService.get(key: CacheKey.trendingAnime, providerName: _defaultProviderName);
      if (cachedData != null) {
        return (cachedData as List).map((e) => Anime.fromJson(e)).toList();
      }
    }

    // 2. Fetch from API
    final List<lib.Media> rawList = await _getProvider().fetchTrending(page: page);
    final animeList = rawList.map((media) => Anime.fromMedia(media)).toList();

    // 3. Save to cache
    if (page > 1) {
      final existingData = await _cachingService.get(key: CacheKey.trendingAnime, providerName: _defaultProviderName);
      if (existingData != null && existingData is List) {
        final existingList = existingData.cast<Map<String, dynamic>>();
        final existingIds = existingList.map((e) => e['id']).toSet();
        final newItems = animeList.map((e) => e.toJson()).where((json) => !existingIds.contains(json['id'])).toList();
        await _cachingService.save(
          key: CacheKey.trendingAnime,
          data: [...existingList, ...newItems],
          expiresIn: const Duration(hours: 12),
          providerName: _defaultProviderName,
        );
      }
    } else {
      await _cachingService.save(
        key: CacheKey.trendingAnime,
        data: animeList.map((e) => e.toJson()).toList(),
        expiresIn: const Duration(hours: 12),
        providerName: _defaultProviderName,
      );
    }

    return animeList;
  }

  Future<Anime> getById(int id, {String? providerName, bool forceRefresh = false}) async {
    final targetProvider = providerName ?? _defaultProviderName;

    // 1. Try to get from storage
    if (!forceRefresh) {
      final storedData = await _storageService.getDynamic(
        key: StorageKey.animeDetails,
        dynamicKey: id.toString(),
        providerName: targetProvider,
      );
      if (storedData != null) {
        return Anime.fromJson(Map<String, dynamic>.from(storedData));
      }
    }

    // 2. Fetch from API
    final lib.Media rawMedia = await _getProvider(targetProvider).fetchAnimeById(id);
    final anime = Anime.fromMedia(rawMedia);

    // 3. Save to storage (Permanent storage for details)
    await _storageService.saveDynamic(
      key: StorageKey.animeDetails,
      dynamicKey: id.toString(),
      data: anime.toJson(),
      providerName: targetProvider,
    );

    return anime;
  }

  Future<List<Anime>> search(String query) async {
    final List<lib.Media> rawList = await _getProvider().searchAnime(query);
    return rawList.map((media) => Anime.fromMedia(media)).toList();
  }
}
