import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

/// Strongly-typed keys for persistent storage.
///
/// These are for permanent user data that should never expire.
/// For temporary cached data, use [CacheKey] in [CachingService] instead.
enum StorageKey {
  /// Watch history entries list
  watchHistory,

  /// Search history queries
  searchHistory,

  /// Individual watch progress for episodes (use with dynamic suffix: animeId/episodeId)
  watchProgress,

  /// Individual anime details (use with dynamic suffix: animeId)
  animeDetails,
}

/// Service for persistent app data storage.
///
/// This service handles permanent user data like watch history and search history.
/// For temporary cached data with expiration, use [CachingService] instead.
///
/// Uses Hive for fast key-value storage.
class StorageService {
  static const String _boxName = 'aimi_storage';
  LazyBox<String>? _box;

  /// Gets or opens the Hive lazy box for storage.
  Future<LazyBox<String>> _getBox() async {
    if (_box != null && _box!.isOpen) {
      return _box!;
    }
    _box = await Hive.openLazyBox<String>(_boxName);
    return _box!;
  }

  /// Save data with a typed [StorageKey].
  ///
  /// Use this for data that doesn't require a dynamic identifier,
  /// like the watch history list or search history list.
  Future<void> save({required StorageKey key, required dynamic data, String? providerName}) async {
    final box = await _getBox();
    final fullKey = _generateKey(key.name, null, providerName);
    await box.put(fullKey, jsonEncode(data));
  }

  /// Get data by typed [StorageKey].
  ///
  /// Returns null if data doesn't exist.
  Future<dynamic> get({required StorageKey key, String? providerName}) async {
    final box = await _getBox();
    final fullKey = _generateKey(key.name, null, providerName);
    final jsonData = await box.get(fullKey);
    if (jsonData != null) {
      return jsonDecode(jsonData);
    }
    return null;
  }

  /// Remove data by typed [StorageKey].
  Future<void> remove({required StorageKey key, String? providerName}) async {
    final box = await _getBox();
    final fullKey = _generateKey(key.name, null, providerName);
    await box.delete(fullKey);
  }

  /// Save data with a typed [StorageKey] and a dynamic identifier.
  ///
  /// Use this for data that requires a dynamic identifier,
  /// like individual episode watch progress.
  ///
  /// Example:
  /// ```dart
  /// await storageService.saveDynamic(
  ///   key: StorageKey.watchProgress,
  ///   dynamicKey: 'anime-123/ep-1',
  ///   data: progressData,
  ///   providerName: 'AnimePahe',
  /// );
  /// ```
  Future<void> saveDynamic({
    required StorageKey key,
    required String dynamicKey,
    required dynamic data,
    String? providerName,
  }) async {
    final box = await _getBox();
    final fullKey = _generateKey(key.name, dynamicKey, providerName);
    await box.put(fullKey, jsonEncode(data));
  }

  /// Get data by typed [StorageKey] and dynamic identifier.
  ///
  /// Returns null if data doesn't exist.
  Future<dynamic> getDynamic({required StorageKey key, required String dynamicKey, String? providerName}) async {
    final box = await _getBox();
    final fullKey = _generateKey(key.name, dynamicKey, providerName);
    final jsonData = await box.get(fullKey);
    if (jsonData != null) {
      return jsonDecode(jsonData);
    }
    return null;
  }

  /// Remove data by typed [StorageKey] and dynamic identifier.
  Future<void> removeDynamic({required StorageKey key, required String dynamicKey, String? providerName}) async {
    final box = await _getBox();
    final fullKey = _generateKey(key.name, dynamicKey, providerName);
    await box.delete(fullKey);
  }

  /// Generate a namespaced key.
  ///
  /// Format: storage/[provider]/[keyName]/[dynamicKey]
  String _generateKey(String keyName, String? dynamicKey, String? providerName) {
    final parts = <String>['storage'];

    if (providerName != null) {
      parts.add(base64Encode(utf8.encode(providerName)));
    }

    parts.add(keyName);

    if (dynamicKey != null) {
      parts.add(dynamicKey);
    }

    return parts.join('/');
  }
}
