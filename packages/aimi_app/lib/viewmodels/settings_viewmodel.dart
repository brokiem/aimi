import 'package:flutter/foundation.dart';

import '../services/data_export_service.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';
import '../services/watch_history_service.dart';

/// ViewModel for the Settings screen following MVVM architecture.
///
/// Handles all business logic for settings operations including:
/// - Data export/import
/// - Cache clearing
/// - Storage reset
/// - UI state management (loading, errors, success messages)
class SettingsViewModel extends ChangeNotifier {
  final DataExportService _dataExportService;
  final SettingsService _settingsService;
  final ThemeService _themeService;
  final WatchHistoryService _watchHistoryService;

  SettingsViewModel(this._dataExportService, this._settingsService, this._themeService, this._watchHistoryService);

  // Loading state
  bool _isExporting = false;

  bool get isExporting => _isExporting;

  bool _isImporting = false;

  bool get isImporting => _isImporting;

  // Messages for user feedback
  String? _successMessage;

  String? get successMessage => _successMessage;

  String? _errorMessage;

  String? get errorMessage => _errorMessage;

  // Clear messages after they're shown
  void clearMessages() {
    _successMessage = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Export all user data to a file.
  ///
  /// Returns the file path if successful, null otherwise.
  /// Sets appropriate success/error messages.
  Future<String?> exportData() async {
    try {
      _isExporting = true;
      _errorMessage = null;
      _successMessage = null;
      notifyListeners();

      final result = await _dataExportService.exportAllData();

      if (result != null) {
        _successMessage = 'Data exported successfully';
      } else {
        _errorMessage = 'Export cancelled or failed';
      }

      return result;
    } catch (e) {
      _errorMessage = 'Failed to export data: $e';
      return null;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  /// Import user data from a file.
  ///
  /// Returns true if successful, false otherwise.
  /// Automatically reloads all services after successful import.
  Future<bool> importData() async {
    try {
      _isImporting = true;
      _errorMessage = null;
      _successMessage = null;
      notifyListeners();

      final result = await _dataExportService.importData();

      if (result) {
        // Reload settings to apply imported preferences
        await _settingsService.reloadSettings();
        await _themeService.loadSettings();
        // Notify watch history listeners to refresh UI
        _watchHistoryService.notifyDataChanged();

        _successMessage = 'Data imported successfully';
      } else {
        _errorMessage = 'Import failed. Please check the file.';
      }

      return result;
    } catch (e) {
      _errorMessage = 'Failed to import data: $e';
      return false;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  /// Clear all cached data.
  ///
  /// This removes temporary data only (e.g., trending anime).
  /// Watch history and preferences are not affected.
  Future<void> clearCache() async {
    try {
      _errorMessage = null;
      _successMessage = null;

      await _dataExportService.clearCache();

      _successMessage = 'Cache cleared successfully';
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to clear cache: $e';
      notifyListeners();
    }
  }

  /// Reset all storage data.
  ///
  /// **Warning**: This is destructive and cannot be undone.
  /// Deletes watch history, search history, and watch progress.
  /// Preferences are preserved.
  Future<void> resetStorage() async {
    try {
      _errorMessage = null;
      _successMessage = null;

      await _dataExportService.resetStorage();
      // Notify watch history listeners to refresh UI
      _watchHistoryService.notifyDataChanged();

      _successMessage = 'Storage reset successfully';
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to reset storage: $e';
      notifyListeners();
    }
  }
}
