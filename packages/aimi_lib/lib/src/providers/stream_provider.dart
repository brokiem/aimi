import '../models/episode.dart';
import '../models/stream_source.dart';
import '../models/streamable_anime.dart';

/// Abstract interface for anime streaming providers (e.g., AnimePahe, Gogoanime, 9anime)
///
/// Stream providers are responsible for:
/// - Searching for anime on their streaming platform
/// - Getting episode lists for an anime
/// - Extracting stream URLs for episodes
///
/// They work independently from metadata providers.
abstract class IStreamProvider {
  /// Provider name (e.g., "AnimePahe", "Anizone")
  String get name;

  /// Provider version or identifier
  String get version => '1.0.0';

  /// Search for anime on the streaming platform
  ///
  /// [query] - Can be a String (title) or an Anime object from a metadata provider
  /// Returns a list of anime available on this streaming platform
  Future<List<StreamableAnime>> search(dynamic query);

  /// Get all episodes for a specific anime
  ///
  /// [anime] - The streamable anime to get episodes for
  /// Returns a list of episodes with their metadata
  Future<List<Episode>> getEpisodes(StreamableAnime anime);

  /// Get stream sources for a specific episode
  ///
  /// [episode] - The episode to get streams for
  /// [options] - Provider-specific options (e.g., {"mode": "sub"} or {"mode": "dub"})
  /// Returns a list of stream sources with different qualities
  Future<List<StreamSource>> getSources(
    Episode episode, {
    Map<String, dynamic>? options,
  });

  /// Clean up resources (close HTTP clients, etc.)
  void dispose() {}
}

/// Options for stream extraction
class StreamOptions {
  /// Audio mode: 'sub' for subtitled, 'dub' for dubbed
  final String? mode;

  /// Preferred quality (e.g., '1080p', '720p')
  final String? quality;

  /// Additional provider-specific options
  final Map<String, dynamic>? extra;

  StreamOptions({
    this.mode = 'sub',
    this.quality,
    this.extra,
  });

  Map<String, dynamic> toMap() {
    return {
      if (mode != null) 'mode': mode,
      if (quality != null) 'quality': quality,
      if (extra != null) ...extra!,
    };
  }
}

