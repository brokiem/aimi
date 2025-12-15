import 'package:aimi_app/services/preferences_service.dart';
import 'package:aimi_app/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ThemeService Tests', () {
    late ThemeService themeService;
    late PreferencesService preferencesService;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      preferencesService = PreferencesService();
      themeService = ThemeService(preferencesService);
      // Wait for async constructor load logic if any, but ThemeService loads in constructor via async method which is unawaited.
      // Ideally we should wait, but for now we'll test the setter/getter interactions.
      // A better design would be to have an init method we can await, but for this simple service we can just test the state changes.
    });

    test('Initial state is default', () {
      expect(themeService.themeMode, ThemeMode.system);
      expect(themeService.seedColor, Colors.teal);
    });

    test('Setting theme mode updates state and notifies listeners', () async {
      bool notified = false;
      themeService.addListener(() => notified = true);

      await themeService.setThemeMode(ThemeMode.dark);

      expect(themeService.themeMode, ThemeMode.dark);
      expect(notified, true);
    });

    test('Setting seed color updates state and notifies listeners', () async {
      bool notified = false;
      themeService.addListener(() => notified = true);

      await themeService.setSeedColor(Colors.red);

      expect(themeService.seedColor, Colors.red);
      expect(notified, true);
    });

    // We can't easily test persistence without mocking SharedPreferences more thoroughly or refactoring,
    // but this covers the core logic of the service.
  });
}
