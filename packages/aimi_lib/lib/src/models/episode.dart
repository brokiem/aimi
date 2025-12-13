/// Domain model for an anime episode
/// Provider-agnostic representation of episode information
class Episode {
  /// The anime ID this episode belongs to
  final String animeId;

  /// Episode number (e.g., "1", "2", "12.5")
  final String number;

  /// Provider-specific session/source ID for fetching streams
  final String? sourceId;

  /// Episode title if available
  final String? title;

  /// Episode thumbnail if available
  final String? thumbnail;

  /// Episode duration in seconds if available
  final int? duration;

  Episode({
    required this.animeId,
    required this.number,
    this.sourceId,
    this.title,
    this.thumbnail,
    this.duration,
  });
}

