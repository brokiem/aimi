import 'package:aimi_app/models/anime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Anime Model', () {
    // =========================================================================
    // AnimeTitle Tests
    // =========================================================================
    group('AnimeTitle', () {
      test('fromJson and toJson are symmetric', () {
        final title = AnimeTitle(romaji: 'Shingeki no Kyojin', english: 'Attack on Titan', native: '進撃の巨人');

        final json = title.toJson();
        final restored = AnimeTitle.fromJson(json);

        expect(restored.romaji, title.romaji);
        expect(restored.english, title.english);
        expect(restored.native, title.native);
      });

      test('preferred returns romaji when available', () {
        final title = AnimeTitle(romaji: 'Romaji Title', english: 'English Title', native: 'Native Title');

        expect(title.preferred, 'Romaji Title');
      });

      test('preferred returns english when romaji is null', () {
        final title = AnimeTitle(romaji: null, english: 'English Title', native: 'Native Title');

        expect(title.preferred, 'English Title');
      });

      test('preferred returns native when romaji and english are null', () {
        final title = AnimeTitle(romaji: null, english: null, native: 'Native Title');

        expect(title.preferred, 'Native Title');
      });

      test('handles null values in JSON', () {
        final json = {'romaji': null, 'english': null, 'native': 'Native Only'};

        final title = AnimeTitle.fromJson(json);

        expect(title.romaji, isNull);
        expect(title.english, isNull);
        expect(title.native, 'Native Only');
      });
    });

    // =========================================================================
    // CoverImage Tests
    // =========================================================================
    group('CoverImage', () {
      test('fromJson and toJson are symmetric', () {
        final cover = CoverImage(extraLarge: 'https://example.com/xl.jpg', large: 'https://example.com/l.jpg');

        final json = cover.toJson();
        final restored = CoverImage.fromJson(json);

        expect(restored.extraLarge, cover.extraLarge);
        expect(restored.large, cover.large);
      });
    });

    // =========================================================================
    // Character Tests
    // =========================================================================
    group('Character', () {
      test('fromJson and toJson are symmetric', () {
        final character = Character(
          id: 1,
          role: 'MAIN',
          name: 'Eren Yeager',
          image: 'https://example.com/eren.jpg',
          voiceActors: [
            VoiceActor(id: 100, name: 'Yuki Kaji', image: 'https://example.com/kaji.jpg', language: 'Japanese'),
          ],
        );

        final json = character.toJson();
        final restored = Character.fromJson(json);

        expect(restored.id, character.id);
        expect(restored.role, character.role);
        expect(restored.name, character.name);
        expect(restored.image, character.image);
        expect(restored.voiceActors.length, 1);
        expect(restored.voiceActors.first.name, 'Yuki Kaji');
      });

      test('handles nullable fields', () {
        final character = Character(id: 1, role: 'SUPPORTING', name: null, image: null, voiceActors: []);

        final json = character.toJson();
        final restored = Character.fromJson(json);

        expect(restored.name, isNull);
        expect(restored.image, isNull);
        expect(restored.voiceActors, isEmpty);
      });
    });

    // =========================================================================
    // VoiceActor Tests
    // =========================================================================
    group('VoiceActor', () {
      test('fromJson and toJson are symmetric', () {
        final va = VoiceActor(id: 1, name: 'Test Actor', image: 'https://example.com/actor.jpg', language: 'English');

        final json = va.toJson();
        final restored = VoiceActor.fromJson(json);

        expect(restored.id, va.id);
        expect(restored.name, va.name);
        expect(restored.image, va.image);
        expect(restored.language, va.language);
      });

      test('language can be null', () {
        final va = VoiceActor(id: 1, name: 'Unknown', image: '', language: null);

        final json = va.toJson();
        final restored = VoiceActor.fromJson(json);

        expect(restored.language, isNull);
      });
    });

    // =========================================================================
    // Staff Tests
    // =========================================================================
    group('Staff', () {
      test('fromJson and toJson are symmetric', () {
        final staff = Staff(
          id: 1,
          role: 'Director',
          name: 'Tetsuro Araki',
          image: 'https://example.com/araki.jpg',
          language: 'Japanese',
        );

        final json = staff.toJson();
        final restored = Staff.fromJson(json);

        expect(restored.id, staff.id);
        expect(restored.role, staff.role);
        expect(restored.name, staff.name);
        expect(restored.image, staff.image);
        expect(restored.language, staff.language);
      });
    });

    // =========================================================================
    // Studio Tests
    // =========================================================================
    group('Studio', () {
      test('fromJson and toJson are symmetric', () {
        final studio = Studio(isMain: true, id: 1, name: 'Wit Studio');

        final json = studio.toJson();
        final restored = Studio.fromJson(json);

        expect(restored.isMain, studio.isMain);
        expect(restored.id, studio.id);
        expect(restored.name, studio.name);
      });

      test('isMain can be false', () {
        final studio = Studio(isMain: false, id: 2, name: 'Production I.G');

        final json = studio.toJson();
        final restored = Studio.fromJson(json);

        expect(restored.isMain, false);
      });
    });

    // =========================================================================
    // Anime Tests
    // =========================================================================
    group('Anime', () {
      test('fromJson and toJson are symmetric', () {
        final anime = Anime(
          id: 16498,
          idMal: 16498,
          title: AnimeTitle(romaji: 'Shingeki no Kyojin', english: 'Attack on Titan', native: '進撃の巨人'),
          type: 'TV',
          format: 'TV',
          status: 'FINISHED',
          description: 'Test description',
          startDate: '2013-04-07',
          endDate: '2013-09-29',
          season: 'SPRING',
          seasonYear: 2013,
          episodes: 25,
          duration: 24,
          countryOfOrigin: 'JP',
          characters: [Character(id: 1, role: 'MAIN', name: 'Eren', voiceActors: [])],
          staff: [Staff(id: 1, role: 'Director', name: 'Araki', image: '')],
          studios: [Studio(isMain: true, id: 1, name: 'Wit Studio')],
          source: 'MANGA',
          hashtag: '#shingeki',
          coverImage: CoverImage(extraLarge: 'https://example.com/xl.jpg', large: 'https://example.com/l.jpg'),
          bannerImage: 'https://example.com/banner.jpg',
          genres: ['Action', 'Drama', 'Fantasy'],
          synonyms: ['AoT', 'SnK'],
          averageScore: 85,
          siteUrl: 'https://anilist.co/anime/16498',
        );

        final json = anime.toJson();
        final restored = Anime.fromJson(json);

        expect(restored.id, anime.id);
        expect(restored.idMal, anime.idMal);
        expect(restored.title.romaji, anime.title.romaji);
        expect(restored.title.english, anime.title.english);
        expect(restored.type, anime.type);
        expect(restored.format, anime.format);
        expect(restored.status, anime.status);
        expect(restored.description, anime.description);
        expect(restored.startDate, anime.startDate);
        expect(restored.endDate, anime.endDate);
        expect(restored.season, anime.season);
        expect(restored.seasonYear, anime.seasonYear);
        expect(restored.episodes, anime.episodes);
        expect(restored.duration, anime.duration);
        expect(restored.countryOfOrigin, anime.countryOfOrigin);
        expect(restored.characters.length, 1);
        expect(restored.staff.length, 1);
        expect(restored.studios.length, 1);
        expect(restored.source, anime.source);
        expect(restored.hashtag, anime.hashtag);
        expect(restored.coverImage.extraLarge, anime.coverImage.extraLarge);
        expect(restored.bannerImage, anime.bannerImage);
        expect(restored.genres, anime.genres);
        expect(restored.synonyms, anime.synonyms);
        expect(restored.averageScore, anime.averageScore);
        expect(restored.siteUrl, anime.siteUrl);
      });

      test('handles null optional fields', () {
        final anime = Anime(
          id: 1,
          title: AnimeTitle(native: 'Test'),
          type: 'TV',
          status: 'AIRING',
          description: '',
          countryOfOrigin: 'JP',
          characters: [],
          staff: [],
          studios: [],
          coverImage: CoverImage(extraLarge: '', large: ''),
          genres: [],
          synonyms: [],
          siteUrl: '',
        );

        final json = anime.toJson();
        final restored = Anime.fromJson(json);

        expect(restored.idMal, isNull);
        expect(restored.format, isNull);
        expect(restored.startDate, isNull);
        expect(restored.endDate, isNull);
        expect(restored.season, isNull);
        expect(restored.seasonYear, isNull);
        expect(restored.episodes, isNull);
        expect(restored.duration, isNull);
        expect(restored.source, isNull);
        expect(restored.hashtag, isNull);
        expect(restored.bannerImage, isNull);
        expect(restored.averageScore, isNull);
      });

      test('handles empty lists', () {
        final anime = Anime(
          id: 1,
          title: AnimeTitle(native: ''),
          type: 'TV',
          status: 'AIRING',
          description: '',
          countryOfOrigin: 'JP',
          characters: [],
          staff: [],
          studios: [],
          coverImage: CoverImage(extraLarge: '', large: ''),
          genres: [],
          synonyms: [],
          siteUrl: '',
        );

        final json = anime.toJson();
        final restored = Anime.fromJson(json);

        expect(restored.characters, isEmpty);
        expect(restored.staff, isEmpty);
        expect(restored.studios, isEmpty);
        expect(restored.genres, isEmpty);
        expect(restored.synonyms, isEmpty);
      });
    });
  });
}
