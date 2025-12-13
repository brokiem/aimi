/// Domain model for anime or manga metadata
/// Provider-agnostic representation of information
class Media {
  final int id;
  final int? idMal;
  final AnimeTitle title;
  final String type;
  final String? format;
  final String status;
  final String description;
  final AnimeDate? startDate;
  final AnimeDate? endDate;
  final String? season;
  final int? seasonYear;
  final int? episodes;
  final int? duration;
  final String countryOfOrigin;
  final NextAiringEpisode? nextAiringEpisode;
  final List<CharacterPreview> characterPreview;
  final List<StaffPreview> staffPreview;
  final List<Studio> studios;
  final String? source;
  final String? hashtag;
  final Trailer? trailer;
  final int updatedAt;
  final CoverImage coverImage;
  final String? bannerImage;
  final List<String> genres;
  final List<String> synonyms;
  final int? averageScore;
  final List<Tag> tags;
  final String siteUrl;

  Media({
    required this.id,
    this.idMal,
    required this.title,
    required this.type,
    this.format,
    required this.status,
    required this.description,
    this.startDate,
    this.endDate,
    this.season,
    this.seasonYear,
    this.episodes,
    this.duration,
    required this.countryOfOrigin,
    this.nextAiringEpisode,
    this.characterPreview = const [],
    this.staffPreview = const [],
    this.studios = const [],
    this.source,
    this.hashtag,
    this.trailer,
    required this.updatedAt,
    required this.coverImage,
    this.bannerImage,
    this.genres = const [],
    this.synonyms = const [],
    this.averageScore,
    this.tags = const [],
    required this.siteUrl,
  });

  factory Media.empty() {
    return Media(
      id: 0,
      title: AnimeTitle.empty(),
      type: '',
      status: '',
      description: '',
      countryOfOrigin: '',
      updatedAt: 0,
      coverImage: CoverImage.empty(),
      siteUrl: '',
    );
  }
}

class AnimeTitle {
  final String? romaji;
  final String? english;
  final String native;

  AnimeTitle({
    this.romaji,
    this.english,
    required this.native,
  });

  factory AnimeTitle.empty() {
    return AnimeTitle(native: '');
  }

  String get preferred => english ?? romaji ?? native;
  String get any => english ?? romaji ?? native;
}

class AnimeDate {
  final int? year;
  final int? month;
  final int? day;

  AnimeDate({this.year, this.month, this.day});

  String format() {
    if (year == null || month == null || day == null) return '-';
    return '${_monthName(month!)} $day, $year';
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}

class CoverImage {
  final String extraLarge;
  final String large;

  CoverImage({required this.extraLarge, required this.large});

  factory CoverImage.empty() {
    return CoverImage(extraLarge: '', large: '');
  }
}

class Tag {
  final int id;
  final String name;
  final String category;

  Tag({required this.id, required this.name, required this.category});
}

class Trailer {
  final String id;
  final String site;
  final String thumbnail;

  Trailer({required this.id, required this.site, required this.thumbnail});
}

class NextAiringEpisode {
  final int airingAt;
  final int timeUntilAiring;
  final int episode;

  NextAiringEpisode({
    required this.airingAt,
    required this.timeUntilAiring,
    required this.episode,
  });

  factory NextAiringEpisode.empty() {
    return NextAiringEpisode(airingAt: 0, timeUntilAiring: 0, episode: 0);
  }
}

class CharacterPreview {
  final int id;
  final String role;
  final String? name;
  final List<VoiceActor> voiceActors;
  final VoiceActor node;

  CharacterPreview({
    required this.id,
    required this.role,
    this.name,
    required this.voiceActors,
    required this.node,
  });
}

class StaffPreview {
  final int id;
  final String role;
  final VoiceActor node;

  StaffPreview({required this.id, required this.role, required this.node});
}

class VoiceActor {
  final int id;
  final String name;
  final String image;
  final String? language;

  VoiceActor({
    required this.id,
    required this.name,
    required this.image,
    this.language,
  });
}

class Studio {
  final bool isMain;
  final int id;
  final String name;

  Studio({required this.isMain, required this.id, required this.name});
}

