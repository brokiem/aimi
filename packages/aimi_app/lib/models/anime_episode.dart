class AnimeEpisode {
  final String id; // This maps to sourceId in lib
  final String animeId; // Needed to map back to lib Episode
  final String number;
  final String? title;
  final String? thumbnail;
  final int? duration;

  AnimeEpisode({
    required this.id,
    required this.animeId,
    required this.number,
    this.title,
    this.thumbnail,
    this.duration,
  });
}
