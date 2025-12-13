import 'package:aimi_lib/aimi_lib.dart' as lib;

/// Represents an external subtitle track
class AppSubtitle {
  final String label;
  final String language;
  final String url;
  final String format;

  AppSubtitle({required this.label, required this.language, required this.url, required this.format});

  /// Create from library model
  factory AppSubtitle.fromLib(lib.Subtitle subtitle) {
    return AppSubtitle(label: subtitle.label, language: subtitle.language, url: subtitle.url, format: subtitle.format);
  }
}

class StreamingSource {
  final String url;
  final String quality;
  final bool isM3U8;
  final List<AppSubtitle> subtitles;

  StreamingSource({required this.url, required this.quality, this.isM3U8 = false, this.subtitles = const []});
}
