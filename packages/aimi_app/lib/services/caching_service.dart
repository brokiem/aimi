import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

/// Strongly-typed keys for cache data.
/// These are temporary data that may expire.
enum CacheKey {
  /// List of trending anime
  trendingAnime,

  /// Search history
  searchHistory,

  /// Watch history entries list
  watchHistory,
}

/// Service for caching data with optional expiration.
///
/// For user preferences/settings, use [PreferencesService] instead.
class CachingService {
  static const String _boxName = 'aimi_cache';
  LazyBox<String>? _box;

  /// Gets or opens the Hive lazy box for caching.
  Future<LazyBox<String>> _getBox() async {
    if (_box != null && _box!.isOpen) {
      return _box!;
    }
    _box = await Hive.openLazyBox<String>(_boxName);
    return _box!;
  }

  /// Save data with optional expiration.
  ///
  /// Use [cacheKey] for predefined keys, or [dynamicKey] for runtime-generated keys
  /// (e.g., anime details with ID).
  Future<void> saveData({
    CacheKey? cacheKey,
    String? dynamicKey,
    required dynamic data,
    Duration? expiresIn,
    String? providerName,
  }) async {
    assert(cacheKey != null || dynamicKey != null, 'Either cacheKey or dynamicKey must be provided');

    final box = await _getBox();
    final cacheData = {
      'data': data,
      'timestamp': expiresIn != null ? DateTime.now().add(expiresIn).toIso8601String() : null,
    };
    final key = cacheKey?.name ?? dynamicKey!;
    final fullKey = _generateKey(key, providerName);
    await box.put(fullKey, jsonEncode(cacheData));
  }

  /// Get cached data.
  ///
  /// Returns null if data doesn't exist or has expired.
  Future<dynamic> getData({CacheKey? cacheKey, String? dynamicKey, String? providerName}) async {
    assert(cacheKey != null || dynamicKey != null, 'Either cacheKey or dynamicKey must be provided');

    final box = await _getBox();
    final key = cacheKey?.name ?? dynamicKey!;
    final fullKey = _generateKey(key, providerName);
    final cachedData = await box.get(fullKey);

    if (cachedData != null) {
      final decodedData = jsonDecode(cachedData);
      if (decodedData['timestamp'] == null) {
        return decodedData['data'];
      }
      final expiration = DateTime.parse(decodedData['timestamp']);
      if (expiration.isAfter(DateTime.now())) {
        return decodedData['data'];
      }
    }
    return null;
  }

  /// Remove cached data.
  Future<void> removeData({CacheKey? cacheKey, String? dynamicKey, String? providerName}) async {
    assert(cacheKey != null || dynamicKey != null, 'Either cacheKey or dynamicKey must be provided');

    final box = await _getBox();
    final key = cacheKey?.name ?? dynamicKey!;
    final fullKey = _generateKey(key, providerName);
    await box.delete(fullKey);
  }

  String _generateKey(String key, String? providerName) {
    if (providerName != null) {
      final encodedProvider = base64Encode(utf8.encode(providerName));
      return 'aimi/$encodedProvider/$key';
    }
    return 'aimi/$key';
  }
}
