import 'package:aimi_lib/aimi_lib.dart' as lib;

import '../models/anime.dart';
import '../models/anime_episode.dart';
import '../models/streaming_anime_result.dart';
import '../models/streaming_source.dart';

class StreamingService {
  StreamingService();

  Future<List<StreamingAnimeResult>> searchWithProvider(lib.IStreamProvider provider, Anime anime) async {
    // Try titles in order: Romaji -> English
    final queries = [
      anime.title.romaji,
      anime.title.english,
    ].where((t) => t != null && t.isNotEmpty).cast<String>().toSet().toList();

    for (final query in queries) {
      try {
        final List<lib.StreamableAnime> rawList = await provider.search(query);

        if (rawList.isNotEmpty) {
          return rawList
              .map(
                (item) =>
                    StreamingAnimeResult(id: item.id, title: item.title, availableEpisodes: item.availableEpisodes),
              )
              .toList();
        }
      } catch (e) {
        // If search fails for one title, try the next one
        continue;
      }
    }

    // No results found for any title
    return [];
  }

  Future<List<AnimeEpisode>> getEpisodesWithProvider(lib.IStreamProvider provider, StreamingAnimeResult anime) async {
    final lib.StreamableAnime libAnime = lib.StreamableAnime(
      id: anime.id,
      title: anime.title,
      availableEpisodes: anime.availableEpisodes,
    );

    final List<lib.Episode> rawList = await provider.getEpisodes(libAnime);

    return rawList
        .map(
          (ep) => AnimeEpisode(
            id: ep.sourceId ?? '',
            animeId: ep.animeId,
            number: ep.number,
            title: ep.title,
            thumbnail: ep.thumbnail,
            duration: ep.duration,
          ),
        )
        .toList();
  }

  Future<List<StreamingSource>> getSources(lib.IStreamProvider provider, AnimeEpisode episode) async {
    final lib.Episode libEpisode = lib.Episode(
      animeId: episode.animeId,
      number: episode.number,
      sourceId: episode.id,
      title: episode.title,
      thumbnail: episode.thumbnail,
      duration: episode.duration,
    );

    final List<lib.StreamSource> rawList = await provider.getSources(libEpisode);

    return rawList
        .map(
          (source) => StreamingSource(
            url: source.url,
            quality: source.quality,
            isM3U8: source.type == 'hls',
            subtitles: source.subtitles.map((s) => AppSubtitle.fromLib(s)).toList(),
          ),
        )
        .toList();
  }

  // In-memory cache for persistence across UI sessions
  // Keys are format: "${animeId}_${providerName}"
  final Map<String, List<AnimeEpisode>> _episodeGlobalCache = {};
  final Map<String, StreamingAnimeResult> _selectedAnimeGlobalCache = {};

  String _getCacheKey(int animeId, String providerName) => '${animeId}_$providerName';

  List<AnimeEpisode>? getCachedEpisodes(int animeId, String providerName) {
    return _episodeGlobalCache[_getCacheKey(animeId, providerName)];
  }

  void setCachedEpisodes(int animeId, String providerName, List<AnimeEpisode> episodes) {
    _episodeGlobalCache[_getCacheKey(animeId, providerName)] = episodes;
  }

  StreamingAnimeResult? getCachedSelectedAnime(int animeId, String providerName) {
    return _selectedAnimeGlobalCache[_getCacheKey(animeId, providerName)];
  }

  void setCachedSelectedAnime(int animeId, String providerName, StreamingAnimeResult? anime) {
    if (anime == null) {
      _selectedAnimeGlobalCache.remove(_getCacheKey(animeId, providerName));
    } else {
      _selectedAnimeGlobalCache[_getCacheKey(animeId, providerName)] = anime;
    }
  }
}
