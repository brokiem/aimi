/// Domain model for streamable anime metadata from a streaming provider
/// This represents anime as found on streaming sites (distinct from metadata providers)
class StreamableAnime {
  /// Provider-specific anime ID
  final String id;

  /// Anime title from the streaming provider
  final String title;

  /// Number of episodes available on this provider
  final int availableEpisodes;

  /// Additional metadata from the provider
  final Map<String, dynamic>? metadata;

  StreamableAnime({
    required this.id,
    required this.title,
    required this.availableEpisodes,
    this.metadata,
  });
}

