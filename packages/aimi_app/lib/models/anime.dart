import 'package:aimi_lib/aimi_lib.dart';

class Anime {
  final int id;
  final int? idMal;
  final AnimeTitle title;
  final String type;
  final String? format;
  final String status;
  final String description;
  final String? startDate;
  final String? endDate;
  final String? season;
  final int? seasonYear;
  final int? episodes;
  final int? duration;
  final String countryOfOrigin;
  final List<Character> characters;
  final List<Staff> staff;
  final List<Studio> studios;
  final String? source;
  final String? hashtag;
  final CoverImage coverImage;
  final String? bannerImage;
  final List<String> genres;
  final List<String> synonyms;
  final int? averageScore;
  final String siteUrl;

  Anime({
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
    required this.characters,
    required this.staff,
    required this.studios,
    this.source,
    this.hashtag,
    required this.coverImage,
    this.bannerImage,
    required this.genres,
    required this.synonyms,
    this.averageScore,
    required this.siteUrl,
  });

  factory Anime.fromMedia(Media media) {
    return Anime(
      id: media.id,
      idMal: media.idMal,
      title: AnimeTitle(romaji: media.title.romaji, english: media.title.english, native: media.title.native),
      type: media.type,
      format: media.format,
      status: media.status,
      description: media.description,
      startDate: media.startDate?.format(),
      endDate: media.endDate?.format(),
      season: media.season,
      seasonYear: media.seasonYear,
      episodes: media.episodes,
      duration: media.duration,
      countryOfOrigin: media.countryOfOrigin,
      characters: media.characterPreview
          .map(
            (cp) => Character(
              id: cp.id,
              role: cp.role,
              name: cp.node.name,
              image: cp.node.image,
              voiceActors: cp.voiceActors
                  .map((va) => VoiceActor(id: va.id, name: va.name, image: va.image, language: va.language))
                  .toList(),
            ),
          )
          .toList(),
      staff: media.staffPreview
          .map(
            (sp) =>
                Staff(id: sp.id, role: sp.role, name: sp.node.name, image: sp.node.image, language: sp.node.language),
          )
          .toList(),
      studios: media.studios.map((s) => Studio(isMain: s.isMain, id: s.id, name: s.name)).toList(),
      source: media.source,
      hashtag: media.hashtag,
      coverImage: CoverImage(extraLarge: media.coverImage.extraLarge, large: media.coverImage.large),
      bannerImage: media.bannerImage,
      genres: media.genres,
      synonyms: media.synonyms,
      averageScore: media.averageScore,
      siteUrl: media.siteUrl,
    );
  }

  factory Anime.fromJson(Map<String, dynamic> json) {
    return Anime(
      id: json['id'],
      idMal: json['idMal'],
      title: AnimeTitle.fromJson(json['title']),
      type: json['type'],
      format: json['format'],
      status: json['status'],
      description: json['description'],
      startDate: json['startDate'],
      endDate: json['endDate'],
      season: json['season'],
      seasonYear: json['seasonYear'],
      episodes: json['episodes'],
      duration: json['duration'],
      countryOfOrigin: json['countryOfOrigin'],
      characters: (json['characters'] as List).map((e) => Character.fromJson(e)).toList(),
      staff: (json['staff'] as List).map((e) => Staff.fromJson(e)).toList(),
      studios: (json['studios'] as List).map((e) => Studio.fromJson(e)).toList(),
      source: json['source'],
      hashtag: json['hashtag'],
      coverImage: CoverImage.fromJson(json['coverImage']),
      bannerImage: json['bannerImage'],
      genres: List<String>.from(json['genres']),
      synonyms: List<String>.from(json['synonyms']),
      averageScore: json['averageScore'],
      siteUrl: json['siteUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idMal': idMal,
      'title': title.toJson(),
      'type': type,
      'format': format,
      'status': status,
      'description': description,
      'startDate': startDate,
      'endDate': endDate,
      'season': season,
      'seasonYear': seasonYear,
      'episodes': episodes,
      'duration': duration,
      'countryOfOrigin': countryOfOrigin,
      'characters': characters.map((e) => e.toJson()).toList(),
      'staff': staff.map((e) => e.toJson()).toList(),
      'studios': studios.map((e) => e.toJson()).toList(),
      'source': source,
      'hashtag': hashtag,
      'coverImage': coverImage.toJson(),
      'bannerImage': bannerImage,
      'genres': genres,
      'synonyms': synonyms,
      'averageScore': averageScore,
      'siteUrl': siteUrl,
    };
  }
}

class AnimeTitle {
  final String? romaji;
  final String? english;
  final String native;

  AnimeTitle({this.romaji, this.english, required this.native});

  factory AnimeTitle.fromJson(Map<String, dynamic> json) {
    return AnimeTitle(romaji: json['romaji'], english: json['english'], native: json['native']);
  }

  Map<String, dynamic> toJson() {
    return {'romaji': romaji, 'english': english, 'native': native};
  }

  String get preferred => romaji ?? english ?? native;
}

class Character {
  final int id;
  final String role;
  final String? name;
  final String? image;
  final List<VoiceActor> voiceActors;

  Character({required this.id, required this.role, this.name, this.image, required this.voiceActors});

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'],
      role: json['role'],
      name: json['name'],
      image: json['image'],
      voiceActors: (json['voiceActors'] as List).map((e) => VoiceActor.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'name': name,
      'image': image,
      'voiceActors': voiceActors.map((e) => e.toJson()).toList(),
    };
  }
}

class VoiceActor {
  final int id;
  final String name;
  final String image;
  final String? language;

  VoiceActor({required this.id, required this.name, required this.image, this.language});

  factory VoiceActor.fromJson(Map<String, dynamic> json) {
    return VoiceActor(id: json['id'], name: json['name'], image: json['image'], language: json['language']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'image': image, 'language': language};
  }
}

class Staff {
  final int id;
  final String role;
  final String name;
  final String image;
  final String? language;

  Staff({required this.id, required this.role, required this.name, required this.image, this.language});

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'],
      role: json['role'],
      name: json['name'],
      image: json['image'],
      language: json['language'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'role': role, 'name': name, 'image': image, 'language': language};
  }
}

class Studio {
  final bool isMain;
  final int id;
  final String name;

  Studio({required this.isMain, required this.id, required this.name});

  factory Studio.fromJson(Map<String, dynamic> json) {
    return Studio(isMain: json['isMain'], id: json['id'], name: json['name']);
  }

  Map<String, dynamic> toJson() {
    return {'isMain': isMain, 'id': id, 'name': name};
  }
}

class CoverImage {
  final String extraLarge;
  final String large;

  CoverImage({required this.extraLarge, required this.large});

  factory CoverImage.fromJson(Map<String, dynamic> json) {
    return CoverImage(extraLarge: json['extraLarge'], large: json['large']);
  }

  Map<String, dynamic> toJson() {
    return {'extraLarge': extraLarge, 'large': large};
  }
}
