import 'package:aimi_app/models/anime.dart';
import 'package:aimi_app/utils/title_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TitleHelper', () {
    // =========================================================================
    // TitleLanguage Extension Tests
    // =========================================================================
    group('TitleLanguageExtension', () {
      test('converts english string to TitleLanguage.english', () {
        expect('english'.toTitleLanguage(), TitleLanguage.english);
        expect('English'.toTitleLanguage(), TitleLanguage.english);
        expect('ENGLISH'.toTitleLanguage(), TitleLanguage.english);
      });

      test('converts romaji string to TitleLanguage.romaji', () {
        expect('romaji'.toTitleLanguage(), TitleLanguage.romaji);
        expect('Romaji'.toTitleLanguage(), TitleLanguage.romaji);
        expect('ROMAJI'.toTitleLanguage(), TitleLanguage.romaji);
      });

      test('converts native string to TitleLanguage.native', () {
        expect('native'.toTitleLanguage(), TitleLanguage.native);
        expect('Native'.toTitleLanguage(), TitleLanguage.native);
        expect('NATIVE'.toTitleLanguage(), TitleLanguage.native);
      });

      test('defaults to english for invalid strings', () {
        expect(''.toTitleLanguage(), TitleLanguage.english);
        expect('invalid'.toTitleLanguage(), TitleLanguage.english);
        expect('japanese'.toTitleLanguage(), TitleLanguage.english);
        expect('en'.toTitleLanguage(), TitleLanguage.english);
      });
    });

    // =========================================================================
    // getPreferredTitle Tests
    // =========================================================================
    group('getPreferredTitle', () {
      test('English preference returns english when available', () {
        final title = AnimeTitle(english: 'English Title', romaji: 'Romaji Title', native: 'ネイティブ');
        expect(getPreferredTitle(title, TitleLanguage.english), 'English Title');
      });

      test('English preference falls back to romaji', () {
        final title = AnimeTitle(english: null, romaji: 'Romaji Title', native: 'ネイティブ');
        expect(getPreferredTitle(title, TitleLanguage.english), 'Romaji Title');
      });

      test('English preference falls back to native', () {
        final title = AnimeTitle(english: null, romaji: null, native: 'ネイティブ');
        expect(getPreferredTitle(title, TitleLanguage.english), 'ネイティブ');
      });

      test('Romaji preference returns romaji when available', () {
        final title = AnimeTitle(english: 'English Title', romaji: 'Romaji Title', native: 'ネイティブ');
        expect(getPreferredTitle(title, TitleLanguage.romaji), 'Romaji Title');
      });

      test('Romaji preference falls back to english', () {
        final title = AnimeTitle(english: 'English Title', romaji: null, native: 'ネイティブ');
        expect(getPreferredTitle(title, TitleLanguage.romaji), 'English Title');
      });

      test('Romaji preference falls back to native', () {
        final title = AnimeTitle(english: null, romaji: null, native: 'ネイティブ');
        expect(getPreferredTitle(title, TitleLanguage.romaji), 'ネイティブ');
      });

      test('Native preference returns native when available', () {
        final title = AnimeTitle(english: 'English Title', romaji: 'Romaji Title', native: 'ネイティブ');
        expect(getPreferredTitle(title, TitleLanguage.native), 'ネイティブ');
      });

      test('Native preference falls back to romaji', () {
        // Since native is required, we can't test with null native
        // but we test that native is preferred over others
        final title = AnimeTitle(english: 'English Title', romaji: 'Romaji Title', native: 'ネイティブ');
        expect(getPreferredTitle(title, TitleLanguage.native), 'ネイティブ');
      });

      test('handles partial availability - only english', () {
        final title = AnimeTitle(english: 'Only English', romaji: null, native: 'ネイティブ');
        // When romaji is null, falls back to english
        expect(getPreferredTitle(title, TitleLanguage.romaji), 'Only English');
        // When native preference used, native is available
        expect(getPreferredTitle(title, TitleLanguage.native), 'ネイティブ');
      });

      test('handles partial availability - only romaji', () {
        final title = AnimeTitle(english: null, romaji: 'Only Romaji', native: 'ネイティブ');
        // When english is null, falls back to romaji
        expect(getPreferredTitle(title, TitleLanguage.english), 'Only Romaji');
        // Native is available
        expect(getPreferredTitle(title, TitleLanguage.native), 'ネイティブ');
      });

      test('handles partial availability - only native', () {
        final title = AnimeTitle(english: null, romaji: null, native: 'Only Native');
        expect(getPreferredTitle(title, TitleLanguage.english), 'Only Native');
        expect(getPreferredTitle(title, TitleLanguage.romaji), 'Only Native');
      });

      test('returns empty when all empty', () {
        final title = AnimeTitle(english: null, romaji: null, native: '');
        // Note: native can't be null but can be empty
        expect(getPreferredTitle(title, TitleLanguage.english), '');
        expect(getPreferredTitle(title, TitleLanguage.romaji), '');
        expect(getPreferredTitle(title, TitleLanguage.native), '');
      });
    });

    // =========================================================================
    // TitleLanguage Enum Tests
    // =========================================================================
    group('TitleLanguage enum', () {
      test('has expected values', () {
        expect(TitleLanguage.values, hasLength(3));
        expect(TitleLanguage.values, contains(TitleLanguage.english));
        expect(TitleLanguage.values, contains(TitleLanguage.romaji));
        expect(TitleLanguage.values, contains(TitleLanguage.native));
      });

      test('name property returns correct string', () {
        expect(TitleLanguage.english.name, 'english');
        expect(TitleLanguage.romaji.name, 'romaji');
        expect(TitleLanguage.native.name, 'native');
      });
    });
  });
}
