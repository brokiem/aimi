import 'dart:convert';
import 'dart:io';

import 'package:aimi_app/services/caching_service.dart';
import 'package:aimi_app/services/preferences_service.dart';
import 'package:aimi_app/services/storage_service.dart';
import 'package:aimi_app/utils/data_version_mapper.dart';
import 'package:file_picker/file_picker.dart';

/// Service for exporting and importing user data with versioning support.
///
/// This service handles backup and restore of all user preferences
/// and storage data as JSON files. Uses [DataVersionMapper] to handle
/// migrations between different export format versions, preventing
/// technical debt when the data structure evolves.
///
/// **Export Format** (v1.0):
/// ```json
/// {
///   "version": "1.0",
///   "exportDate": "2025-12-16T08:41:31.000Z",
///   "metadata": {
///     "appVersion": "1.0.0",
///     "platform": "android",
///     "exportedBy": "Aimi App"
///   },
///   "preferences": { ... },
///   "storage": { ... }
/// }
/// ```
class DataExportService {
  final PreferencesService _preferencesService;
  final StorageService _storageService;
  final CachingService _cachingService;

  DataExportService(this._preferencesService, this._storageService, this._cachingService);

  /// Export all user data to a JSON file with comprehensive metadata.
  ///
  /// Returns the file path where data was saved, or null if cancelled/failed.
  /// Uses file picker to let user choose where to save the file.
  ///
  /// **Includes**:
  /// - Preferences (theme, settings, volume, etc.)
  /// - Storage (watch history, search history, progress, anime details)
  /// - Metadata (app version, platform, export timestamp)
  ///
  /// **Excludes**:
  /// - Cached data (temporary)
  Future<String?> exportAllData() async {
    try {
      // Gather all data
      final preferences = await _preferencesService.getAllPreferences();
      final storage = await _storageService.getAllData();

      // Build comprehensive export data
      final exportData = {
        'version': DataVersionMapper.currentVersion,
        'exportDate': DateTime.now().toIso8601String(),
        'metadata': DataVersionMapper.getMetadata().toJson(),
        'preferences': preferences,
        'storage': storage,
      };

      // Validate export data structure
      if (!DataVersionMapper.validate(exportData)) {
        return null; // Invalid data structure
      }

      // Convert to JSON with pretty printing
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // Let user choose where to save
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup File',
        fileName: 'aimi_backup_$timestamp.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) {
        return null; // User cancelled
      }

      // Write file with error handling
      final file = File(result);
      await file.writeAsString(jsonString);

      return result;
    } catch (e) {
      // Log error in production: logger.error('Export failed', e);
      return null;
    }
  }

  /// Import user data from a JSON file.
  ///
  /// Returns true if import was successful, false otherwise.
  /// Validates the JSON structure before importing.
  Future<bool> importData() async {
    try {
      // Pick a file
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);

      if (result == null || result.files.single.path == null) {
        return false;
      }

      final filePath = result.files.single.path!;
      final file = File(filePath);

      // Read and parse JSON
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate structure
      if (!_validateImportData(data)) {
        return false;
      }

      // Import preferences
      if (data['preferences'] != null) {
        final prefs = data['preferences'] as Map<String, dynamic>;
        for (final entry in prefs.entries) {
          try {
            final key = PrefKey.values.firstWhere((k) => k.name == entry.key);
            await _preferencesService.set(key, entry.value);
          } catch (_) {
            // Skip unknown preferences
          }
        }
      }

      // Import storage
      if (data['storage'] != null) {
        await _storageService.importData(data['storage'] as Map<String, dynamic>);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate the structure of imported data.
  bool _validateImportData(Map<String, dynamic> data) {
    // Check for required fields
    if (!data.containsKey('version')) return false;
    if (!data.containsKey('exportDate')) return false;

    // Check that preferences and storage are maps if they exist
    if (data.containsKey('preferences') && data['preferences'] is! Map) {
      return false;
    }
    if (data.containsKey('storage') && data['storage'] is! Map) {
      return false;
    }

    return true;
  }

  /// Clear all cached data.
  ///
  /// Removes temporary cached data like trending anime lists.
  /// Does NOT affect preferences or permanent storage.
  Future<void> clearCache() async {
    await _cachingService.clearAll();
  }

  /// Reset all storage data (watch history, search history, etc.).
  ///
  /// **Warning**: This is a destructive operation that cannot be undone.
  ///
  /// **Deletes**:
  /// - Watch history
  /// - Search history
  /// - Watch progress
  /// - Saved anime details
  ///
  /// **Preserves**:
  /// - Preferences (theme, volume, subtitle/audio settings, title language)
  /// - Settings (hero animations, etc.)
  Future<void> resetStorage() async {
    await _storageService.clearAll();
  }
}
