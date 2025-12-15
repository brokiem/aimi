import 'package:aimi_app/services/preferences_service.dart';
import 'package:aimi_app/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ThemeService', () {
    late ThemeService themeService;
    late PreferencesService preferencesService;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      preferencesService = PreferencesService();
      themeService = ThemeService(preferencesService);
    });

    // =========================================================================
    // Initial State Tests
    // =========================================================================
    group('Initial State', () {
      test('initial themeMode is system', () {
        expect(themeService.themeMode, ThemeMode.system);
      });

      test('initial seedColor is teal', () {
        expect(themeService.seedColor, Colors.teal);
      });
    });

    // =========================================================================
    // Theme Mode Tests
    // =========================================================================
    group('Theme Mode', () {
      test('setThemeMode updates state', () async {
        await themeService.setThemeMode(ThemeMode.dark);
        expect(themeService.themeMode, ThemeMode.dark);
      });

      test('setThemeMode notifies listeners', () async {
        bool notified = false;
        themeService.addListener(() => notified = true);

        await themeService.setThemeMode(ThemeMode.dark);

        expect(notified, true);
      });

      test('setThemeMode to light mode works', () async {
        await themeService.setThemeMode(ThemeMode.light);
        expect(themeService.themeMode, ThemeMode.light);
      });

      test('setThemeMode to system mode works', () async {
        await themeService.setThemeMode(ThemeMode.dark);
        await themeService.setThemeMode(ThemeMode.system);
        expect(themeService.themeMode, ThemeMode.system);
      });
    });

    // =========================================================================
    // Seed Color Tests
    // =========================================================================
    group('Seed Color', () {
      test('setSeedColor updates state', () async {
        await themeService.setSeedColor(Colors.red);
        expect(themeService.seedColor, Colors.red);
      });

      test('setSeedColor notifies listeners', () async {
        bool notified = false;
        themeService.addListener(() => notified = true);

        await themeService.setSeedColor(Colors.red);

        expect(notified, true);
      });

      test('setSeedColor works with various colors', () async {
        final colors = [Colors.blue, Colors.purple, Colors.green, Colors.orange, Colors.pink];

        for (final color in colors) {
          await themeService.setSeedColor(color);
          expect(themeService.seedColor, color);
        }
      });
    });

    // =========================================================================
    // Listener Tests
    // =========================================================================
    group('Listeners', () {
      test('multiple listeners are notified on change', () async {
        // Wait for async constructor initialization to complete
        await Future.delayed(const Duration(milliseconds: 50));

        int notifyCount = 0;
        themeService.addListener(() => notifyCount++);
        themeService.addListener(() => notifyCount++);

        await themeService.setThemeMode(ThemeMode.dark);

        expect(notifyCount, 2);
      });

      test('removed listener is not notified', () async {
        bool notified = false;
        void listener() => notified = true;

        themeService.addListener(listener);
        themeService.removeListener(listener);

        await themeService.setThemeMode(ThemeMode.dark);

        expect(notified, false);
      });
    });

    // =========================================================================
    // Persistence Tests
    // =========================================================================
    group('Persistence', () {
      test('themeMode persists across service instances', () async {
        // Set dark mode
        await themeService.setThemeMode(ThemeMode.dark);

        // Create new service instance
        final newService = ThemeService(preferencesService);

        // Wait for async load
        await Future.delayed(const Duration(milliseconds: 100));

        expect(newService.themeMode, ThemeMode.dark);
      });

      test('seedColor persists across service instances', () async {
        // Set custom color (use a simple Color, not MaterialColor)
        const testColor = Color(0xFF9C27B0); // Purple
        await themeService.setSeedColor(testColor);

        // Create new service instance
        final newService = ThemeService(preferencesService);

        // Wait for async load
        await Future.delayed(const Duration(milliseconds: 100));

        // Compare color values (not MaterialColor vs Color)
        expect(newService.seedColor.value, testColor.value);
      });
    });

    // =========================================================================
    // Edge Cases
    // =========================================================================
    group('Edge Cases', () {
      test('setting same themeMode does not notify listeners', () async {
        await themeService.setThemeMode(ThemeMode.dark);

        bool notified = false;
        themeService.addListener(() => notified = true);

        await themeService.setThemeMode(ThemeMode.dark);

        // Service optimizes by not notifying on same value
        expect(notified, false);
      });

      test('setting same seedColor does not notify listeners', () async {
        await themeService.setSeedColor(Colors.red);

        bool notified = false;
        themeService.addListener(() => notified = true);

        await themeService.setSeedColor(Colors.red);

        // Service optimizes by not notifying on same value
        expect(notified, false);
      });
    });
  });
}
