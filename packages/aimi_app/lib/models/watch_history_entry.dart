/// Represents a watch history entry for an anime episode.
///
/// This model tracks playback progress and completion status,
/// tied to specific stream and metadata providers.
class WatchHistoryEntry {
  /// The anime ID from the metadata provider (e.g., AniList ID)
  final int animeId;

  /// The episode ID from the stream provider (sourceId)
  final String episodeId;

  /// The episode number (e.g., "1", "2", "OVA 1")
  final String episodeNumber;

  /// The name of the stream provider (e.g., "AnimePahe")
  final String streamProviderName;

  /// The name of the metadata provider (e.g., "AniList")
  final String metadataProviderName;

  /// The last playback position in milliseconds
  final int positionMs;

  /// The total episode duration in milliseconds
  final int durationMs;

  /// When this entry was last updated
  final DateTime lastWatched;

  /// True if the episode was watched to completion (>90%)
  final bool isCompleted;

  /// Optional anime title for display purposes
  final String? animeTitle;

  /// Optional episode title for display purposes
  final String? episodeTitle;

  WatchHistoryEntry({
    required this.animeId,
    required this.episodeId,
    required this.episodeNumber,
    required this.streamProviderName,
    required this.metadataProviderName,
    required this.positionMs,
    required this.durationMs,
    required this.lastWatched,
    this.isCompleted = false,
    this.animeTitle,
    this.episodeTitle,
  });

  /// The playback position as a Duration
  Duration get position => Duration(milliseconds: positionMs);

  /// The total duration as a Duration
  Duration get duration => Duration(milliseconds: durationMs);

  /// Progress as a percentage (0.0 to 1.0)
  double get progress => durationMs > 0 ? positionMs / durationMs : 0.0;

  /// Unique cache key for this entry (uses stream provider for episode-specific data)
  String get cacheKey => '$streamProviderName/$animeId/$episodeId';

  /// Create a copy with updated fields
  WatchHistoryEntry copyWith({
    int? animeId,
    String? episodeId,
    String? episodeNumber,
    String? streamProviderName,
    String? metadataProviderName,
    int? positionMs,
    int? durationMs,
    DateTime? lastWatched,
    bool? isCompleted,
    String? animeTitle,
    String? episodeTitle,
  }) {
    return WatchHistoryEntry(
      animeId: animeId ?? this.animeId,
      episodeId: episodeId ?? this.episodeId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      streamProviderName: streamProviderName ?? this.streamProviderName,
      metadataProviderName: metadataProviderName ?? this.metadataProviderName,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      lastWatched: lastWatched ?? this.lastWatched,
      isCompleted: isCompleted ?? this.isCompleted,
      animeTitle: animeTitle ?? this.animeTitle,
      episodeTitle: episodeTitle ?? this.episodeTitle,
    );
  }

  /// Create from JSON
  factory WatchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return WatchHistoryEntry(
      animeId: json['animeId'] as int,
      episodeId: json['episodeId'] as String,
      episodeNumber: json['episodeNumber'] as String,
      streamProviderName: json['streamProviderName'] as String,
      metadataProviderName: json['metadataProviderName'] as String,
      positionMs: json['positionMs'] as int,
      durationMs: json['durationMs'] as int,
      lastWatched: DateTime.parse(json['lastWatched'] as String),
      isCompleted: json['isCompleted'] as bool? ?? false,
      animeTitle: json['animeTitle'] as String?,
      episodeTitle: json['episodeTitle'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'animeId': animeId,
      'episodeId': episodeId,
      'episodeNumber': episodeNumber,
      'streamProviderName': streamProviderName,
      'metadataProviderName': metadataProviderName,
      'positionMs': positionMs,
      'durationMs': durationMs,
      'lastWatched': lastWatched.toIso8601String(),
      'isCompleted': isCompleted,
      'animeTitle': animeTitle,
      'episodeTitle': episodeTitle,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WatchHistoryEntry &&
        other.animeId == animeId &&
        other.episodeId == episodeId &&
        other.streamProviderName == streamProviderName;
  }

  @override
  int get hashCode => Object.hash(animeId, episodeId, streamProviderName);

  @override
  String toString() {
    return 'WatchHistoryEntry(animeId: $animeId, episodeId: $episodeId, '
        'episode: $episodeNumber, stream: $streamProviderName, '
        'metadata: $metadataProviderName, '
        'progress: ${(progress * 100).toStringAsFixed(1)}%, '
        'completed: $isCompleted)';
  }
}
