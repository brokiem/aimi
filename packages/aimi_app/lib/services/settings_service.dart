import 'package:aimi_app/services/preferences_service.dart';
import 'package:aimi_app/utils/title_helper.dart';
import 'package:flutter/material.dart';

/// Service for managing app settings with reactive updates.
///
/// This service extends ChangeNotifier to enable real-time settings updates
/// without requiring app restart. All settings changes notify listeners
/// immediately.
class SettingsService extends ChangeNotifier {
  final PreferencesService _preferencesService;

  bool _enableHeroAnimation = true;
  TitleLanguage _titleLanguagePreference = TitleLanguage.english;

  SettingsService(this._preferencesService) {
    _loadSettings();
  }

  /// Whether hero animations are enabled on page transitions
  bool get enableHeroAnimation => _enableHeroAnimation;

  /// Preferred title language
  TitleLanguage get titleLanguagePreference => _titleLanguagePreference;

  /// Load settings from preferences
  Future<void> _loadSettings() async {
    // Load hero animation preference (default: true)
    final heroAnimEnabled = await _preferencesService.get<bool>(PrefKey.enableHeroAnimation);
    _enableHeroAnimation = heroAnimEnabled ?? true;

    // Load title language preference (default: english)
    final titleLangPref = await _preferencesService.get<String>(PrefKey.titleLanguagePreference);
    if (titleLangPref != null) {
      _titleLanguagePreference = titleLangPref.toTitleLanguage();
    }

    notifyListeners();
  }

  /// Set hero animation preference
  Future<void> setEnableHeroAnimation(bool enabled) async {
    if (_enableHeroAnimation == enabled) return;
    _enableHeroAnimation = enabled;
    notifyListeners();
    await _preferencesService.set(PrefKey.enableHeroAnimation, enabled);
  }

  /// Set title language preference
  Future<void> setTitleLanguagePreference(TitleLanguage language) async {
    if (_titleLanguagePreference == language) return;
    _titleLanguagePreference = language;
    notifyListeners();
    await _preferencesService.set(PrefKey.titleLanguagePreference, language.name);
  }

  /// Reload settings from preferences
  ///
  /// Useful after importing data to refresh the UI
  Future<void> reloadSettings() async {
    await _loadSettings();
  }
}
