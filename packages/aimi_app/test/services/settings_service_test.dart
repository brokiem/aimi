import 'package:aimi_app/services/preferences_service.dart';
import 'package:aimi_app/services/settings_service.dart';
import 'package:aimi_app/utils/title_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsService', () {
    late SettingsService settingsService;
    late PreferencesService preferencesService;

    setUp(() async {
      // Initialize with empty SharedPreferences
      SharedPreferences.setMockInitialValues({});
      preferencesService = PreferencesService();
      settingsService = SettingsService(preferencesService);
      // Allow async initialization to complete
      await Future.delayed(const Duration(milliseconds: 50));
    });

    // =========================================================================
    // Initial State Tests
    // =========================================================================
    group('Initial State', () {
      test('enableHeroAnimation defaults to true', () {
        expect(settingsService.enableHeroAnimation, true);
      });

      test('titleLanguagePreference defaults to english', () {
        expect(settingsService.titleLanguagePreference, TitleLanguage.english);
      });
    });

    // =========================================================================
    // Hero Animation Tests
    // =========================================================================
    group('Hero Animation', () {
      test('setEnableHeroAnimation updates value', () async {
        await settingsService.setEnableHeroAnimation(false);

        expect(settingsService.enableHeroAnimation, false);
      });

      test('setEnableHeroAnimation persists to preferences', () async {
        await settingsService.setEnableHeroAnimation(false);

        final saved = await preferencesService.get<bool>(PrefKey.enableHeroAnimation);
        expect(saved, false);
      });

      test('setEnableHeroAnimation skips identical value', () async {
        int notifyCount = 0;
        settingsService.addListener(() => notifyCount++);

        await settingsService.setEnableHeroAnimation(true); // Same as default

        expect(notifyCount, 0);
      });

      test('setEnableHeroAnimation notifies listeners', () async {
        int notifyCount = 0;
        settingsService.addListener(() => notifyCount++);

        await settingsService.setEnableHeroAnimation(false);

        expect(notifyCount, 1);
      });
    });

    // =========================================================================
    // Title Language Tests
    // =========================================================================
    group('Title Language', () {
      test('setTitleLanguagePreference updates value', () async {
        await settingsService.setTitleLanguagePreference(TitleLanguage.romaji);

        expect(settingsService.titleLanguagePreference, TitleLanguage.romaji);
      });

      test('setTitleLanguagePreference persists to preferences', () async {
        await settingsService.setTitleLanguagePreference(TitleLanguage.native);

        final saved = await preferencesService.get<String>(PrefKey.titleLanguagePreference);
        expect(saved, 'native');
      });

      test('setTitleLanguagePreference works for all enum values', () async {
        for (final language in TitleLanguage.values) {
          await settingsService.setTitleLanguagePreference(language);
          expect(settingsService.titleLanguagePreference, language);
        }
      });

      test('setTitleLanguagePreference skips identical value', () async {
        int notifyCount = 0;
        settingsService.addListener(() => notifyCount++);

        await settingsService.setTitleLanguagePreference(TitleLanguage.english);

        expect(notifyCount, 0);
      });

      test('setTitleLanguagePreference notifies listeners', () async {
        int notifyCount = 0;
        settingsService.addListener(() => notifyCount++);

        await settingsService.setTitleLanguagePreference(TitleLanguage.romaji);

        expect(notifyCount, 1);
      });
    });

    // =========================================================================
    // Reload Tests
    // =========================================================================
    group('Reload Settings', () {
      test('reloadSettings loads from preferences', () async {
        // Set values directly in preferences
        await preferencesService.set(PrefKey.enableHeroAnimation, false);
        await preferencesService.set(PrefKey.titleLanguagePreference, 'native');

        await settingsService.reloadSettings();

        expect(settingsService.enableHeroAnimation, false);
        expect(settingsService.titleLanguagePreference, TitleLanguage.native);
      });

      test('reloadSettings notifies listeners', () async {
        int notifyCount = 0;
        settingsService.addListener(() => notifyCount++);

        await settingsService.reloadSettings();

        expect(notifyCount, 1);
      });
    });

    // =========================================================================
    // Persistence Tests (Integration)
    // =========================================================================
    group('Persistence', () {
      test('settings survive service recreation', () async {
        // Set values
        await settingsService.setEnableHeroAnimation(false);
        await settingsService.setTitleLanguagePreference(TitleLanguage.romaji);

        // Create new service instance
        final newService = SettingsService(preferencesService);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(newService.enableHeroAnimation, false);
        expect(newService.titleLanguagePreference, TitleLanguage.romaji);
      });
    });
  });

  group('PreferencesService', () {
    late PreferencesService preferencesService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      preferencesService = PreferencesService();
    });

    // =========================================================================
    // Type Support Tests
    // =========================================================================
    group('Type Support', () {
      test('supports String type', () async {
        await preferencesService.set(PrefKey.subtitlePreference, 'English');
        final result = await preferencesService.get<String>(PrefKey.subtitlePreference);
        expect(result, 'English');
      });

      test('supports int type', () async {
        await preferencesService.set(PrefKey.videoVolume, 75);
        final result = await preferencesService.get<int>(PrefKey.videoVolume);
        expect(result, 75);
      });

      test('supports bool type', () async {
        await preferencesService.set(PrefKey.enableHeroAnimation, false);
        final result = await preferencesService.get<bool>(PrefKey.enableHeroAnimation);
        expect(result, false);
      });
    });

    // =========================================================================
    // CRUD Tests
    // =========================================================================
    group('CRUD', () {
      test('get returns null for missing key', () async {
        final result = await preferencesService.get<String>(PrefKey.subtitlePreference);
        expect(result, isNull);
      });

      test('set then get roundtrip', () async {
        await preferencesService.set(PrefKey.themeMode, 'dark');
        final result = await preferencesService.get<String>(PrefKey.themeMode);
        expect(result, 'dark');
      });

      test('remove deletes value', () async {
        await preferencesService.set(PrefKey.audioPreference, 'Japanese');
        await preferencesService.remove(PrefKey.audioPreference);
        final result = await preferencesService.get<String>(PrefKey.audioPreference);
        expect(result, isNull);
      });
    });

    // =========================================================================
    // Export Tests
    // =========================================================================
    group('Export', () {
      test('getAllPreferences returns all set values', () async {
        await preferencesService.set(PrefKey.videoVolume, 50);
        await preferencesService.set(PrefKey.themeMode, 'light');

        final all = await preferencesService.getAllPreferences();

        expect(all['videoVolume'], 50);
        expect(all['themeMode'], 'light');
      });

      test('getAllPreferences excludes unset values', () async {
        await preferencesService.set(PrefKey.videoVolume, 50);

        final all = await preferencesService.getAllPreferences();

        expect(all.containsKey('videoVolume'), true);
        expect(all.containsKey('themeMode'), false);
      });
    });

    // =========================================================================
    // Clear Tests
    // =========================================================================
    group('Clear', () {
      test('clearAll removes all preferences', () async {
        await preferencesService.set(PrefKey.videoVolume, 50);
        await preferencesService.set(PrefKey.themeMode, 'dark');

        await preferencesService.clearAll();

        final all = await preferencesService.getAllPreferences();
        expect(all, isEmpty);
      });
    });
  });
}
