import 'package:aimi_lib/aimi_lib.dart';
import 'package:test/test.dart';

void main() {
  group('Provider Registry Tests', () {
    test('Anime model should create empty instance', () {
      final anime = Media.empty();
      expect(anime.id, equals(0));
      expect(anime.title.native, equals(''));
    });

    test('Episode model should be created', () {
      final episode = Episode(animeId: 'test', number: '1');
      expect(episode.animeId, equals('test'));
      expect(episode.number, equals('1'));
    });
  });
}
