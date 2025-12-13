import '../models/media.dart';

/// Abstract interface for anime metadata providers (e.g., AniList, MyAnimeList, Kitsu)
///
/// Metadata providers are responsible for providing anime information like:
/// - Anime details (title, description, cover image, etc.)
/// - Trending/popular anime
/// - Search functionality
/// - Anime metadata and relationships
///
/// They do NOT provide streaming links - use [IStreamProvider] for that.
abstract class IMetadataProvider {
  /// Provider name (e.g., "AniList", "MyAnimeList")
  String get name;

  /// Provider version or identifier
  String get version => '1.0.0';

  /// Fetch trending anime with pagination
  ///
  /// [page] - Page number for pagination (default: 1)
  /// Returns a list of trending anime
  Future<List<Media>> fetchTrending({int page = 1});

  /// Fetch a specific anime by ID
  ///
  /// [id] - The anime ID from this provider
  /// Returns detailed anime information
  Future<Media> fetchAnimeById(int id);

  /// Search for anime by query
  ///
  /// [query] - Search query string
  /// [page] - Page number for pagination (default: 1)
  /// Returns a list of anime matching the query
  Future<List<Media>> searchAnime(String query, {int page = 1});

  /// Clean up resources (close HTTP clients, etc.)
  void dispose() {}
}

