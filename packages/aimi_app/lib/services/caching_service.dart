import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

/// Strongly-typed keys for cache data.
///
/// These are temporary data that may expire.
/// For permanent user data, use [StorageKey] in [StorageService] instead.
enum CacheKey {
  /// List of trending anime
  trendingAnime,
}

/// Service for caching data with optional expiration.
///
/// This service handles temporary cached data that may expire.
/// For permanent user data, use [StorageService] instead.
/// For user preferences/settings, use [PreferencesService] instead.
///
/// Uses Hive for fast key-value storage.
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

  /// Save data with a typed [CacheKey].
  ///
  /// Use this for data that doesn't require a dynamic identifier,
  /// like the trending anime list.
  /// [expiresIn] sets the cache duration; null means no expiration.
  Future<void> save({required CacheKey key, required dynamic data, Duration? expiresIn, String? providerName}) async {
    final box = await _getBox();
    final cacheData = _wrapWithExpiration(data, expiresIn);
    final fullKey = _generateKey(key.name, null, providerName);
    await box.put(fullKey, jsonEncode(cacheData));
  }

  /// Get data by typed [CacheKey].
  ///
  /// Returns null if data doesn't exist or has expired.
  Future<dynamic> get({required CacheKey key, String? providerName}) async {
    final box = await _getBox();
    final fullKey = _generateKey(key.name, null, providerName);
    return _unwrapWithExpiration(await box.get(fullKey));
  }

  /// Remove data by typed [CacheKey].
  Future<void> remove({required CacheKey key, String? providerName}) async {
    final box = await _getBox();
    final fullKey = _generateKey(key.name, null, providerName);
    await box.delete(fullKey);
  }

  /// Save data with a typed [CacheKey] and a dynamic identifier.
  ///
  /// Use this for data that requires a dynamic identifier,
  /// like individual anime details.
  ///
  /// Example:
  /// ```dart
  /// await cachingService.saveDynamic(
  ///   key: CacheKey.animeDetails,
  ///   dynamicKey: '12345',
  ///   data: animeData,
  ///   providerName: 'AniList',
  /// );
  /// ```
  Future<void> saveDynamic({
    required CacheKey key,
    required String dynamicKey,
    required dynamic data,
    Duration? expiresIn,
    String? providerName,
  }) async {
    final box = await _getBox();
    final cacheData = _wrapWithExpiration(data, expiresIn);
    final fullKey = _generateKey(key.name, dynamicKey, providerName);
    await box.put(fullKey, jsonEncode(cacheData));
  }

  /// Get data by typed [CacheKey] and dynamic identifier.
  ///
  /// Returns null if data doesn't exist or has expired.
  Future<dynamic> getDynamic({required CacheKey key, required String dynamicKey, String? providerName}) async {
    final box = await _getBox();
    final fullKey = _generateKey(key.name, dynamicKey, providerName);
    return _unwrapWithExpiration(await box.get(fullKey));
  }

  /// Remove data by typed [CacheKey] and dynamic identifier.
  Future<void> removeDynamic({required CacheKey key, required String dynamicKey, String? providerName}) async {
    final box = await _getBox();
    final fullKey = _generateKey(key.name, dynamicKey, providerName);
    await box.delete(fullKey);
  }

  /// Wrap data with optional expiration timestamp.
  Map<String, dynamic> _wrapWithExpiration(dynamic data, Duration? expiresIn) {
    return {'data': data, 'timestamp': expiresIn != null ? DateTime.now().add(expiresIn).toIso8601String() : null};
  }

  /// Unwrap cached data and check expiration.
  ///
  /// Returns null if expired or doesn't exist.
  dynamic _unwrapWithExpiration(String? cachedData) {
    if (cachedData == null) return null;

    final decodedData = jsonDecode(cachedData);
    final timestamp = decodedData['timestamp'];

    if (timestamp == null) {
      return decodedData['data'];
    }

    final expiration = DateTime.parse(timestamp);
    if (expiration.isAfter(DateTime.now())) {
      return decodedData['data'];
    }

    // Data has expired
    return null;
  }

  /// Generate a namespaced key.
  ///
  /// Format: cache/[provider]/[keyName]/[dynamicKey]
  String _generateKey(String keyName, String? dynamicKey, String? providerName) {
    final parts = <String>['cache'];

    if (providerName != null) {
      parts.add(base64Encode(utf8.encode(providerName)));
    }

    parts.add(keyName);

    if (dynamicKey != null) {
      parts.add(dynamicKey);
    }

    return parts.join('/');
  }

  /// Clear all cached data.
  ///
  /// This removes all temporary cached data.
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }
}
