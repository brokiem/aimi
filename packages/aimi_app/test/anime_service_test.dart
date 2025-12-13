import 'package:aimi_app/services/anime_service.dart';
import 'package:aimi_app/services/caching_service.dart';
import 'package:aimi_lib/aimi_lib.dart' as lib;
import 'package:flutter_test/flutter_test.dart';

class FakeMetadataProvider implements lib.IMetadataProvider {
  final String _name;
  final Map<int, lib.Media> _animeMap = {};

  FakeMetadataProvider(this._name);

  void addAnime(lib.Media anime) {
    _animeMap[anime.id] = anime;
  }

  @override
  String get name => _name;

  @override
  String get version => '1.0.0';

  @override
  Future<lib.Media> fetchAnimeById(int id) async {
    if (_animeMap.containsKey(id)) {
      return _animeMap[id]!;
    }
    throw Exception('Anime $id not found in $_name');
  }

  @override
  Future<List<lib.Media>> fetchTrending({int page = 1}) async {
    return _animeMap.values.toList();
  }

  @override
  Future<List<lib.Media>> searchAnime(String query, {int page = 1}) async {
    return _animeMap.values
        .where((a) => a.title.english?.contains(query) ?? false)
        .toList();
  }

  @override
  void dispose() {}
}

class FakeCachingService extends CachingService {
  @override
  Future<void> saveData({
    CacheKey? cacheKey,
    String? dynamicKey,
    required dynamic data,
    Duration? expiresIn,
    String? providerName,
  }) async {}

  @override
  Future<dynamic> getData({
    CacheKey? cacheKey,
    String? dynamicKey,
    String? providerName,
  }) async {
    return null;
  }
}

void main() {
  group('AnimeService Multi-Provider', () {
    late AnimeService service;
    late FakeMetadataProvider providerA;
    late FakeMetadataProvider providerB;
    late FakeCachingService cachingService;

    setUp(() {
      providerA = FakeMetadataProvider('ProviderA');
      providerB = FakeMetadataProvider('ProviderB');
      cachingService = FakeCachingService();

      // Add dummy data
      providerA.addAnime(
        lib.Media(
          id: 1,
          title: lib.AnimeTitle(english: 'Anime A', native: ''),
          type: 'TV',
          status: 'FINISHED',
          description: '',
          countryOfOrigin: 'JP',
          updatedAt: 0,
          coverImage: lib.CoverImage(extraLarge: '', large: ''),
          siteUrl: '',
        ),
      );

      providerB.addAnime(
        lib.Media(
          id: 1, // Same ID but different content/context
          title: lib.AnimeTitle(english: 'Anime B', native: ''),
          type: 'TV',
          status: 'FINISHED',
          description: '',
          countryOfOrigin: 'JP',
          updatedAt: 0,
          coverImage: lib.CoverImage(extraLarge: '', large: ''),
          siteUrl: '',
        ),
      );

      service = AnimeService(
        [providerA, providerB],
        cachingService,
        defaultProviderName: 'ProviderA',
      );
    });

    test('getById uses default provider when no name specified', () async {
      final anime = await service.getById(1);
      expect(anime.title.english, 'Anime A');
    });

    test('getById uses specified provider', () async {
      final anime = await service.getById(1, providerName: 'ProviderB');
      expect(anime.title.english, 'Anime B');
    });

    test('getById throws if provider not found', () async {
      expect(
        () => service.getById(1, providerName: 'UnknownProvider'),
        throwsException,
      );
    });

    test('fetchTrending uses default provider', () async {
      final trending = await service.fetchTrending();
      expect(trending.first.title.english, 'Anime A');
    });

    test('providerName returns default provider name', () {
      expect(service.providerName, 'ProviderA');
    });
  });
}
