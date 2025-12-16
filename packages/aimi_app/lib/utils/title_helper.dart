import 'package:aimi_app/models/anime.dart';

/// Title language preference options
enum TitleLanguage {
  /// English title (falls back to Romaji if unavailable)
  english,

  /// Romaji title (romanized Japanese)
  romaji,

  /// Native title (Japanese characters)
  native,
}

/// Extension to convert string to TitleLanguage enum
extension TitleLanguageExtension on String {
  TitleLanguage toTitleLanguage() {
    switch (toLowerCase()) {
      case 'english':
        return TitleLanguage.english;
      case 'romaji':
        return TitleLanguage.romaji;
      case 'native':
        return TitleLanguage.native;
      default:
        return TitleLanguage.english;
    }
  }
}

/// Helper function to get the preferred title based on user preference
///
/// Falls back gracefully if the preferred language is not available:
/// - English preference: English -> Romaji -> Native
/// - Romaji preference: Romaji -> English -> Native
/// - Native preference: Native -> Romaji -> English
String getPreferredTitle(AnimeTitle title, TitleLanguage preference) {
  switch (preference) {
    case TitleLanguage.english:
      return title.english ?? title.romaji ?? title.native ?? '';
    case TitleLanguage.romaji:
      return title.romaji ?? title.english ?? title.native ?? '';
    case TitleLanguage.native:
      return title.native ?? title.romaji ?? title.english ?? '';
  }
}
