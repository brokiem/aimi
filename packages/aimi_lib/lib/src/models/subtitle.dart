/// Domain model for an external subtitle track
class Subtitle {
  /// Display label (e.g., "English - Commie")
  final String label;

  /// Language code (e.g., "en", "es", "ja")
  final String language;

  /// URL to the subtitle file
  final String url;

  /// Subtitle format (e.g., "ass", "srt", "vtt")
  final String format;

  Subtitle({
    required this.label,
    required this.language,
    required this.url,
    required this.format,
  });

  @override
  String toString() => 'Subtitle($label, $language, $format)';
}
