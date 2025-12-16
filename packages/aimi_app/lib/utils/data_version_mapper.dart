import 'dart:io';

/// Metadata structure for export files.
///
/// Contains comprehensive information about the export environment
/// to help with debugging and compatibility checking during import.
class ExportMetadata {
  final String appVersion;
  final String appName;
  final String platform;
  final String operatingSystemVersion;
  final String dartVersion;
  final String locale;
  final int numberOfProcessors;
  final DateTime exportTime;

  const ExportMetadata({
    required this.appVersion,
    required this.appName,
    required this.platform,
    required this.operatingSystemVersion,
    required this.dartVersion,
    required this.locale,
    required this.numberOfProcessors,
    required this.exportTime,
  });

  Map<String, dynamic> toJson() => {
    'appVersion': appVersion,
    'appName': appName,
    'platform': platform,
    'operatingSystemVersion': operatingSystemVersion,
    'dartVersion': dartVersion,
    'locale': locale,
    'numberOfProcessors': numberOfProcessors,
    'exportTime': exportTime.toIso8601String(),
  };

  factory ExportMetadata.fromJson(Map<String, dynamic> json) => ExportMetadata(
    appVersion: json['appVersion'] as String? ?? 'unknown',
    appName: json['appName'] as String? ?? 'unknown',
    platform: json['platform'] as String? ?? 'unknown',
    operatingSystemVersion: json['operatingSystemVersion'] as String? ?? 'unknown',
    dartVersion: json['dartVersion'] as String? ?? 'unknown',
    locale: json['locale'] as String? ?? 'unknown',
    numberOfProcessors: json['numberOfProcessors'] as int? ?? 0,
    exportTime: DateTime.tryParse(json['exportTime'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Version mapper for data import/export.
///
/// Handles migration between different export data versions.
/// Also provides comprehensive metadata generation for export files.
///
/// **Supported Versions**:
/// - `1.0`: Initial version with preferences and storage data
///
/// **Migration Path**:
/// When new versions are added, migrations are applied sequentially:
/// `legacy -> 1.0 -> 2.0 -> ... -> currentVersion`
class DataVersionMapper {
  /// Current export format version.
  ///
  /// Increment this when the export format changes in a backwards-incompatible way.
  /// Remember to add a migration method for the old version.
  static const String currentVersion = '1.0';

  /// Application name used in exports.
  static const String appName = 'Aimi';

  /// Minimum supported version for imports.
  ///
  /// Versions older than this cannot be migrated and will be rejected.
  static const String minimumSupportedVersion = '1.0';

  /// List of all known versions in order from oldest to newest.
  static const List<String> versionHistory = ['1.0'];

  /// Migrate data from any version to the current version.
  ///
  /// Returns the migrated data if successful, or null if:
  /// - The version is unsupported
  /// - The version is older than [minimumSupportedVersion]
  /// - Migration fails for any reason
  ///
  /// Migration is applied sequentially through version history,
  /// so data at version 1.0 would go through each intermediate
  /// version until reaching [currentVersion].
  static Map<String, dynamic>? migrate(Map<String, dynamic> data) {
    final version = data['version'] as String?;

    if (version == null) {
      // Legacy data without version - attempt legacy migration
      return _migrateLegacy(data);
    }

    if (version == currentVersion) {
      // Already at current version, no migration needed
      return data;
    }

    // Check if version is in our known history
    final versionIndex = versionHistory.indexOf(version);
    if (versionIndex == -1) {
      // Unknown version - might be from a newer app version
      // Try to use it if it validates, otherwise reject
      if (validate(data)) {
        return data;
      }
      return null;
    }

    // Check minimum supported version
    final minIndex = versionHistory.indexOf(minimumSupportedVersion);
    if (versionIndex < minIndex) {
      // Version is too old to migrate
      return null;
    }

    // Apply migrations sequentially
    var migratedData = Map<String, dynamic>.from(data);
    for (var i = versionIndex; i < versionHistory.length - 1; i++) {
      final fromVersion = versionHistory[i];
      final toVersion = versionHistory[i + 1];

      final migrator = _getMigrator(fromVersion, toVersion);
      if (migrator == null) {
        // No migration path available
        return null;
      }

      final result = migrator(migratedData);
      if (result == null) {
        // Migration failed
        return null;
      }
      migratedData = result;
    }

    return migratedData;
  }

  /// Get the migration function for a specific version transition.
  static Map<String, dynamic>? Function(Map<String, dynamic>)? _getMigrator(String fromVersion, String toVersion) {
    // Add migrations here as versions are added
    // Example: '1.0' -> '2.0'
    // if (fromVersion == '1.0' && toVersion == '2.0') {
    //   return _migrateV1ToV2;
    // }
    return null;
  }

  /// Migrate legacy data (pre-versioning) to the oldest supported format.
  ///
  /// This handles imports from very old versions of the app that didn't
  /// include version information in exports.
  static Map<String, dynamic>? _migrateLegacy(Map<String, dynamic> data) {
    // Attempt to construct a valid v1.0 structure from legacy data
    try {
      // Check if it looks like old export data
      if (!data.containsKey('preferences') && !data.containsKey('storage')) {
        // Doesn't look like export data at all
        return null;
      }

      // Wrap in v1.0 structure
      return {
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'metadata': getMetadata().toJson(),
        'preferences': data['preferences'] ?? {},
        'storage': data['storage'] ?? {},
      };
    } catch (_) {
      return null;
    }
  }

  /// Validate that data has the correct structure for the current version.
  ///
  /// Checks for:
  /// - Required top-level fields (version, exportDate, metadata)
  /// - Correct types for all fields
  /// - Valid metadata structure
  static bool validate(Map<String, dynamic> data) {
    // Check for required top-level fields
    if (!data.containsKey('version')) return false;
    if (!data.containsKey('exportDate')) return false;
    if (!data.containsKey('metadata')) return false;

    // Validate version is a string
    if (data['version'] is! String) return false;

    // Validate exportDate is a valid ISO 8601 string
    final exportDate = data['exportDate'];
    if (exportDate is! String) return false;
    if (DateTime.tryParse(exportDate) == null) return false;

    // Check metadata structure
    final metadata = data['metadata'];
    if (metadata is! Map) return false;

    // Validate required metadata fields
    if (!_validateMetadata(metadata)) return false;

    // Validate that preferences and storage are maps if they exist
    if (data.containsKey('preferences') && data['preferences'] is! Map) {
      return false;
    }
    if (data.containsKey('storage') && data['storage'] is! Map) {
      return false;
    }

    return true;
  }

  /// Validate the metadata structure.
  static bool _validateMetadata(Map<dynamic, dynamic> metadata) {
    // Required metadata fields
    const requiredFields = ['appVersion', 'platform', 'appName'];

    for (final field in requiredFields) {
      if (!metadata.containsKey(field)) return false;
      if (metadata[field] is! String) return false;
    }

    return true;
  }

  /// Get comprehensive metadata for exports.
  ///
  /// The [appVersion] parameter should be provided by the caller,
  /// typically from package_info_plus or a build configuration.
  /// If not provided, defaults to 'unknown'.
  static ExportMetadata getMetadata({String? appVersion}) {
    return ExportMetadata(
      appVersion: appVersion ?? _getAppVersion(),
      appName: appName,
      platform: Platform.operatingSystem,
      operatingSystemVersion: Platform.operatingSystemVersion,
      dartVersion: Platform.version.split(' ').first,
      locale: Platform.localeName,
      numberOfProcessors: Platform.numberOfProcessors,
      exportTime: DateTime.now(),
    );
  }

  /// Get app version from available sources.
  ///
  /// This is a fallback when version is not provided by the caller.
  /// In production, prefer passing the version from package_info_plus.
  static String _getAppVersion() {
    // Could read from a generated file or environment variable
    // For now, return a placeholder that indicates manual setup needed
    return const String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
  }

  /// Check if a version string is valid.
  static bool isValidVersion(String version) {
    // Version should be in format X.Y or X.Y.Z
    final parts = version.split('.');
    if (parts.length < 2 || parts.length > 3) return false;

    for (final part in parts) {
      if (int.tryParse(part) == null) return false;
    }

    return true;
  }

  /// Compare two version strings.
  ///
  /// Returns:
  /// - Negative if v1 < v2
  /// - Zero if v1 == v2
  /// - Positive if v1 > v2
  static int compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = v2.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    // Pad shorter version with zeros
    while (parts1.length < 3) {
      parts1.add(0);
    }
    while (parts2.length < 3) {
      parts2.add(0);
    }

    for (var i = 0; i < 3; i++) {
      if (parts1[i] != parts2[i]) {
        return parts1[i] - parts2[i];
      }
    }

    return 0;
  }

  /// Check if a version is supported for import.
  static bool isVersionSupported(String version) {
    if (!isValidVersion(version)) return false;

    // Check if it's in our known history or newer
    final index = versionHistory.indexOf(version);
    if (index != -1) {
      final minIndex = versionHistory.indexOf(minimumSupportedVersion);
      return index >= minIndex;
    }

    // Unknown version - allow if it's newer than current
    // (forward compatibility for minor changes)
    return compareVersions(version, currentVersion) >= 0;
  }

  /// Get a summary of changes between two versions.
  ///
  /// Useful for showing users what changed when importing
  /// data from an older version.
  static List<String> getVersionChangelog(String fromVersion, String toVersion) {
    final changes = <String>[];

    // Add changelog entries here as versions are added
    // Example:
    // if (compareVersions(fromVersion, '2.0') < 0 &&
    //     compareVersions(toVersion, '2.0') >= 0) {
    //   changes.add('Added support for custom playlists');
    //   changes.add('Improved watch history tracking');
    // }

    if (changes.isEmpty && fromVersion != toVersion) {
      changes.add('Migrated from version $fromVersion to $toVersion');
    }

    return changes;
  }

  /// Future migration helper for v1.0 -> v2.0 (template for future use).
  ///
  /// When adding new migrations:
  /// 1. Create a copy of the data
  /// 2. Transform fields as needed
  /// 3. Update version number
  /// 4. Return migrated data
  // ignore: unused_element
  static Map<String, dynamic>? _migrateV1ToV2(Map<String, dynamic> data) {
    final migrated = Map<String, dynamic>.from(data);

    // Example transformations:
    // - Rename fields
    // if (migrated['oldFieldName'] != null) {
    //   migrated['newFieldName'] = migrated['oldFieldName'];
    //   migrated.remove('oldFieldName');
    // }
    //
    // - Add new required fields with defaults
    // if (!migrated.containsKey('newRequiredField')) {
    //   migrated['newRequiredField'] = 'defaultValue';
    // }
    //
    // - Transform data structures
    // if (migrated['preferences'] is Map) {
    //   final prefs = migrated['preferences'] as Map<String, dynamic>;
    //   // Transform preferences...
    // }

    migrated['version'] = '2.0';
    return migrated;
  }
}
