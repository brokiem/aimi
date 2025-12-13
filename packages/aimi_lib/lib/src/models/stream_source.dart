import 'subtitle.dart';

/// Domain model for a video stream source
/// Represents a streamable video URL with quality and metadata
class StreamSource {
  /// The direct URL to the video stream
  final String url;

  /// Quality indicator (e.g., "1080p", "720p", "480p")
  final String quality;

  /// Stream type (e.g., "hls", "mp4", "dash")
  final String type;

  /// HTTP headers required for accessing the stream
  final Map<String, String>? headers;

  /// Additional metadata about the stream
  final Map<String, dynamic>? metadata;

  /// External subtitle tracks available for this stream
  final List<Subtitle> subtitles;

  StreamSource({
    required this.url,
    required this.quality,
    required this.type,
    this.headers,
    this.metadata,
    this.subtitles = const [],
  });

  /// Create a copy with modified fields
  StreamSource copyWith({
    String? url,
    String? quality,
    String? type,
    Map<String, String>? headers,
    Map<String, dynamic>? metadata,
    List<Subtitle>? subtitles,
  }) {
    return StreamSource(
      url: url ?? this.url,
      quality: quality ?? this.quality,
      type: type ?? this.type,
      headers: headers ?? this.headers,
      metadata: metadata ?? this.metadata,
      subtitles: subtitles ?? this.subtitles,
    );
  }
}
