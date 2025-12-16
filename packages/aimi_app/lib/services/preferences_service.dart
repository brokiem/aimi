import 'package:shared_preferences/shared_preferences.dart';

/// Strongly-typed keys for user preferences.
/// These are settings that persist without expiration.
enum PrefKey {
  /// Preferred subtitle track title
  subtitlePreference,

  /// Preferred audio track title
  audioPreference,

  /// Video player volume (0-100)
  videoVolume,

  /// Theme mode (system, light, dark)
  themeMode,

  /// Seed color for dynamic theme (int value of color)
  seedColor,

  /// Enable hero animations on page transitions
  enableHeroAnimation,

  /// Title language preference (english, romaji, native)
  titleLanguagePreference,
}

/// Service for managing user preferences.
///
/// Unlike [CachingService], preferences never expire and are meant
/// for user settings and configurations.
class PreferencesService {
  static const _prefix = 'aimi_pref';

  String _keyString(PrefKey key) => '$_prefix/${key.name}';

  /// Get a preference value.
  Future<T?> get<T>(PrefKey key) async {
    final prefs = await SharedPreferences.getInstance();
    final keyStr = _keyString(key);

    if (T == String) {
      return prefs.getString(keyStr) as T?;
    } else if (T == int) {
      return prefs.getInt(keyStr) as T?;
    } else if (T == double) {
      return prefs.getDouble(keyStr) as T?;
    } else if (T == bool) {
      return prefs.getBool(keyStr) as T?;
    } else if (T == List<String>) {
      return prefs.getStringList(keyStr) as T?;
    }

    // Fallback for dynamic
    final value = prefs.get(keyStr);
    return value as T?;
  }

  /// Set a preference value.
  Future<void> set<T>(PrefKey key, T value) async {
    final prefs = await SharedPreferences.getInstance();
    final keyStr = _keyString(key);

    if (value is String) {
      await prefs.setString(keyStr, value);
    } else if (value is int) {
      await prefs.setInt(keyStr, value);
    } else if (value is double) {
      await prefs.setDouble(keyStr, value);
    } else if (value is bool) {
      await prefs.setBool(keyStr, value);
    } else if (value is List<String>) {
      await prefs.setStringList(keyStr, value);
    } else {
      throw ArgumentError('Unsupported type: ${value.runtimeType}');
    }
  }

  /// Remove a preference.
  Future<void> remove(PrefKey key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyString(key));
  }

  /// Get all preferences as a Map for export.
  Future<Map<String, dynamic>> getAllPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> allPrefs = {};

    for (final key in PrefKey.values) {
      final keyStr = _keyString(key);
      final value = prefs.get(keyStr);
      if (value != null) {
        allPrefs[key.name] = value;
      }
    }

    return allPrefs;
  }

  /// Clear all preferences.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in PrefKey.values) {
      await prefs.remove(_keyString(key));
    }
  }
}
