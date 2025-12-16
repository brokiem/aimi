import 'package:aimi_app/utils/data_version_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataVersionMapper', () {
    // =========================================================================
    // ExportMetadata Tests
    // =========================================================================
    group('ExportMetadata', () {
      test('toJson produces valid structure', () {
        final metadata = ExportMetadata(
          appVersion: '1.0.0',
          appName: 'Test',
          platform: 'android',
          operatingSystemVersion: 'Android 14',
          dartVersion: '3.0.0',
          locale: 'en_US',
          numberOfProcessors: 8,
          exportTime: DateTime(2025, 1, 1, 12, 0, 0),
        );

        final json = metadata.toJson();

        expect(json['appVersion'], '1.0.0');
        expect(json['appName'], 'Test');
        expect(json['platform'], 'android');
        expect(json['operatingSystemVersion'], 'Android 14');
        expect(json['dartVersion'], '3.0.0');
        expect(json['locale'], 'en_US');
        expect(json['numberOfProcessors'], 8);
        expect(json['exportTime'], '2025-01-01T12:00:00.000');
      });

      test('fromJson handles complete data', () {
        final json = {
          'appVersion': '2.0.0',
          'appName': 'Aimi',
          'platform': 'ios',
          'operatingSystemVersion': 'iOS 17',
          'dartVersion': '3.2.0',
          'locale': 'ja_JP',
          'numberOfProcessors': 6,
          'exportTime': '2025-06-15T10:30:00.000',
        };

        final metadata = ExportMetadata.fromJson(json);

        expect(metadata.appVersion, '2.0.0');
        expect(metadata.appName, 'Aimi');
        expect(metadata.platform, 'ios');
        expect(metadata.operatingSystemVersion, 'iOS 17');
        expect(metadata.locale, 'ja_JP');
        expect(metadata.numberOfProcessors, 6);
      });

      test('fromJson handles missing fields with defaults', () {
        final json = <String, dynamic>{};

        final metadata = ExportMetadata.fromJson(json);

        expect(metadata.appVersion, 'unknown');
        expect(metadata.appName, 'unknown');
        expect(metadata.platform, 'unknown');
        expect(metadata.numberOfProcessors, 0);
      });

      test('fromJson handles null values', () {
        final json = {'appVersion': null, 'appName': null, 'platform': null};

        final metadata = ExportMetadata.fromJson(json);

        expect(metadata.appVersion, 'unknown');
        expect(metadata.appName, 'unknown');
        expect(metadata.platform, 'unknown');
      });
    });

    // =========================================================================
    // Version Validation Tests
    // =========================================================================
    group('isValidVersion', () {
      test('accepts X.Y format', () {
        expect(DataVersionMapper.isValidVersion('1.0'), true);
        expect(DataVersionMapper.isValidVersion('2.5'), true);
        expect(DataVersionMapper.isValidVersion('10.20'), true);
      });

      test('accepts X.Y.Z format', () {
        expect(DataVersionMapper.isValidVersion('1.0.0'), true);
        expect(DataVersionMapper.isValidVersion('2.5.10'), true);
        expect(DataVersionMapper.isValidVersion('10.20.30'), true);
      });

      test('rejects invalid formats', () {
        expect(DataVersionMapper.isValidVersion('1'), false);
        expect(DataVersionMapper.isValidVersion('1.0.0.0'), false);
        expect(DataVersionMapper.isValidVersion('a.b.c'), false);
        expect(DataVersionMapper.isValidVersion('1.x'), false);
        expect(DataVersionMapper.isValidVersion(''), false);
        expect(DataVersionMapper.isValidVersion('v1.0'), false);
      });
    });

    // =========================================================================
    // Version Comparison Tests
    // =========================================================================
    group('compareVersions', () {
      test('returns 0 for equal versions', () {
        expect(DataVersionMapper.compareVersions('1.0', '1.0'), 0);
        expect(DataVersionMapper.compareVersions('1.0.0', '1.0'), 0);
        expect(DataVersionMapper.compareVersions('2.5.3', '2.5.3'), 0);
      });

      test('returns negative when v1 < v2', () {
        expect(DataVersionMapper.compareVersions('1.0', '2.0'), lessThan(0));
        expect(DataVersionMapper.compareVersions('1.0', '1.1'), lessThan(0));
        expect(DataVersionMapper.compareVersions('1.0.0', '1.0.1'), lessThan(0));
      });

      test('returns positive when v1 > v2', () {
        expect(DataVersionMapper.compareVersions('2.0', '1.0'), greaterThan(0));
        expect(DataVersionMapper.compareVersions('1.1', '1.0'), greaterThan(0));
        expect(DataVersionMapper.compareVersions('1.0.1', '1.0.0'), greaterThan(0));
      });

      test('handles version padding', () {
        expect(DataVersionMapper.compareVersions('1.0', '1.0.0'), 0);
        expect(DataVersionMapper.compareVersions('2.0', '2.0.0'), 0);
      });
    });

    // =========================================================================
    // Data Validation Tests
    // =========================================================================
    group('validate', () {
      Map<String, dynamic> createValidData() {
        return {
          'version': '1.0',
          'exportDate': '2025-01-01T12:00:00.000Z',
          'metadata': {'appVersion': '1.0.0', 'platform': 'android', 'appName': 'Aimi'},
          'preferences': {},
          'storage': {},
        };
      }

      test('accepts valid data structure', () {
        expect(DataVersionMapper.validate(createValidData()), true);
      });

      test('rejects missing version', () {
        final data = createValidData();
        data.remove('version');
        expect(DataVersionMapper.validate(data), false);
      });

      test('rejects missing exportDate', () {
        final data = createValidData();
        data.remove('exportDate');
        expect(DataVersionMapper.validate(data), false);
      });

      test('rejects missing metadata', () {
        final data = createValidData();
        data.remove('metadata');
        expect(DataVersionMapper.validate(data), false);
      });

      test('rejects non-string version', () {
        final data = createValidData();
        data['version'] = 1.0;
        expect(DataVersionMapper.validate(data), false);
      });

      test('rejects invalid date format', () {
        final data = createValidData();
        data['exportDate'] = 'not-a-date';
        expect(DataVersionMapper.validate(data), false);
      });

      test('rejects non-map metadata', () {
        final data = createValidData();
        data['metadata'] = 'invalid';
        expect(DataVersionMapper.validate(data), false);
      });

      test('rejects non-map preferences', () {
        final data = createValidData();
        data['preferences'] = 'invalid';
        expect(DataVersionMapper.validate(data), false);
      });

      test('rejects non-map storage', () {
        final data = createValidData();
        data['storage'] = 'invalid';
        expect(DataVersionMapper.validate(data), false);
      });

      test('rejects missing required metadata fields', () {
        final data = createValidData();
        data['metadata'] = {'appVersion': '1.0.0'}; // Missing platform and appName
        expect(DataVersionMapper.validate(data), false);
      });
    });

    // =========================================================================
    // Migration Tests
    // =========================================================================
    group('migrate', () {
      test('returns data unchanged for current version', () {
        final data = {
          'version': DataVersionMapper.currentVersion,
          'exportDate': '2025-01-01T12:00:00.000Z',
          'metadata': {'appVersion': '1.0.0', 'platform': 'android', 'appName': 'Aimi'},
          'preferences': {'key': 'value'},
          'storage': {'data': 'test'},
        };

        final result = DataVersionMapper.migrate(data);

        expect(result, isNotNull);
        expect(result!['version'], DataVersionMapper.currentVersion);
        expect(result['preferences'], data['preferences']);
        expect(result['storage'], data['storage']);
      });

      test('handles legacy data with preferences', () {
        final legacyData = {
          'preferences': {'theme': 'dark'},
          'storage': {'history': []},
        };

        final result = DataVersionMapper.migrate(legacyData);

        expect(result, isNotNull);
        expect(result!['version'], '1.0');
        expect(result['preferences'], legacyData['preferences']);
        expect(result['storage'], legacyData['storage']);
      });

      test('returns null for empty legacy data', () {
        final emptyData = <String, dynamic>{};

        final result = DataVersionMapper.migrate(emptyData);

        expect(result, isNull);
      });

      test('handles unknown newer version if valid', () {
        final futureData = {
          'version': '99.0.0',
          'exportDate': '2025-01-01T12:00:00.000Z',
          'metadata': {'appVersion': '99.0.0', 'platform': 'future', 'appName': 'Aimi'},
          'preferences': {},
          'storage': {},
        };

        final result = DataVersionMapper.migrate(futureData);

        // Should accept valid future version data
        expect(result, isNotNull);
      });
    });

    // =========================================================================
    // Metadata Generation Tests
    // =========================================================================
    group('getMetadata', () {
      test('returns non-null values for all fields', () {
        final metadata = DataVersionMapper.getMetadata();

        expect(metadata.appVersion, isNotEmpty);
        expect(metadata.appName, isNotEmpty);
        expect(metadata.platform, isNotEmpty);
        expect(metadata.operatingSystemVersion, isNotEmpty);
        expect(metadata.dartVersion, isNotEmpty);
        expect(metadata.locale, isNotEmpty);
        expect(metadata.numberOfProcessors, greaterThan(0));
        expect(metadata.exportTime, isNotNull);
      });

      test('uses provided appVersion', () {
        final metadata = DataVersionMapper.getMetadata(appVersion: '3.5.0');

        expect(metadata.appVersion, '3.5.0');
      });

      test('appName is Aimi', () {
        final metadata = DataVersionMapper.getMetadata();

        expect(metadata.appName, 'Aimi');
      });
    });

    // =========================================================================
    // Version Support Tests
    // =========================================================================
    group('isVersionSupported', () {
      test('current version is supported', () {
        expect(DataVersionMapper.isVersionSupported(DataVersionMapper.currentVersion), true);
      });

      test('minimum supported version is supported', () {
        expect(DataVersionMapper.isVersionSupported(DataVersionMapper.minimumSupportedVersion), true);
      });

      test('invalid version string is not supported', () {
        expect(DataVersionMapper.isVersionSupported('invalid'), false);
        expect(DataVersionMapper.isVersionSupported('1'), false);
      });
    });

    // =========================================================================
    // Constants Tests
    // =========================================================================
    group('Constants', () {
      test('currentVersion is valid', () {
        expect(DataVersionMapper.isValidVersion(DataVersionMapper.currentVersion), true);
      });

      test('versionHistory is not empty', () {
        expect(DataVersionMapper.versionHistory, isNotEmpty);
      });

      test('versionHistory contains currentVersion', () {
        expect(DataVersionMapper.versionHistory, contains(DataVersionMapper.currentVersion));
      });
    });
  });
}
