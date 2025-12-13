import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

/// Service for managing cached episode thumbnails.
///
/// Thumbnails are captured from video player on exit and cached
/// for display in episode lists.
class ThumbnailService {
  static const _thumbnailDir = 'thumbnails';
  final _updateController = StreamController<String>.broadcast();

  /// Stream of episode IDs that have updated thumbnails.
  Stream<String> get onThumbnailUpdated => _updateController.stream;

  /// Get the cache directory for thumbnails.
  Future<Directory> _getCacheDir() async {
    final cacheDir = await getApplicationCacheDirectory();
    final thumbDir = Directory('${cacheDir.path}/$_thumbnailDir');
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }
    return thumbDir;
  }

  /// Generate file path for a specific episode thumbnail.
  String _getFilePath(Directory cacheDir, String providerName, int animeId, String episodeId) {
    // Sanitize episodeId to be file-system safe
    final safeEpisodeId = episodeId.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    return '${cacheDir.path}/$providerName/$animeId/$safeEpisodeId.jpg';
  }

  /// Get cached thumbnail path for an episode.
  ///
  /// Returns the file path if thumbnail exists, null otherwise.
  Future<String?> getThumbnail(String providerName, int animeId, String episodeId) async {
    try {
      final cacheDir = await _getCacheDir();
      final filePath = _getFilePath(cacheDir, providerName, animeId, episodeId);
      final file = File(filePath);

      if (await file.exists()) {
        return filePath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Save screenshot bytes as thumbnail for an episode.
  Future<void> saveThumbnail(String providerName, int animeId, String episodeId, Uint8List bytes) async {
    try {
      final cacheDir = await _getCacheDir();
      final filePath = _getFilePath(cacheDir, providerName, animeId, episodeId);
      final file = File(filePath);

      // Create parent directories if needed
      final parentDir = file.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      await file.writeAsBytes(bytes);

      // Evict from image cache to ensure UI updates immediately
      await FileImage(file).evict();

      // Notify listeners
      _updateController.add(episodeId);
    } catch (e) {
      // Silently fail - thumbnails are non-critical
    }
  }

  /// Delete cached thumbnail for an episode.
  Future<void> deleteThumbnail(String providerName, int animeId, String episodeId) async {
    try {
      final cacheDir = await _getCacheDir();
      final filePath = _getFilePath(cacheDir, providerName, animeId, episodeId);
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Clear all cached thumbnails.
  Future<void> clearAllThumbnails() async {
    try {
      final cacheDir = await _getCacheDir();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      // Silently fail
    }
  }
}
