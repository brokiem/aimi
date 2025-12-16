import 'package:aimi_app/services/caching_service.dart';
import 'package:aimi_app/services/storage_service.dart';
import 'package:aimi_app/utils/data_version_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('DataExportService', () {
    late FakeStorageService fakeStorageService;
    late FakeCachingService fakeCachingService;

    setUp(() {
      fakeStorageService = FakeStorageService();
      fakeCachingService = FakeCachingService();
    });

    // =========================================================================
    // Data Validation Tests
    // =========================================================================
    group('Data Validation', () {
      test('valid export data passes validation', () {
        final data = {
          'version': '1.0',
          'exportDate': DateTime.now().toIso8601String(),
          'metadata': {'appVersion': '1.0.0', 'platform': 'android', 'appName': 'Aimi'},
          'preferences': {'theme': 'dark'},
          'storage': {'history': []},
        };

        expect(DataVersionMapper.validate(data), true);
      });

      test('missing version fails validation', () {
        final data = {
          'exportDate': DateTime.now().toIso8601String(),
          'metadata': {'appVersion': '1.0.0', 'platform': 'android', 'appName': 'Aimi'},
        };

        expect(DataVersionMapper.validate(data), false);
      });

      test('missing exportDate fails validation', () {
        final data = {
          'version': '1.0',
          'metadata': {'appVersion': '1.0.0', 'platform': 'android', 'appName': 'Aimi'},
        };

        expect(DataVersionMapper.validate(data), false);
      });

      test('invalid exportDate format fails validation', () {
        final data = {
          'version': '1.0',
          'exportDate': 'not-a-date',
          'metadata': {'appVersion': '1.0.0', 'platform': 'android', 'appName': 'Aimi'},
        };

        expect(DataVersionMapper.validate(data), false);
      });

      test('missing metadata fails validation', () {
        final data = {'version': '1.0', 'exportDate': DateTime.now().toIso8601String()};

        expect(DataVersionMapper.validate(data), false);
      });

      test('wrong type for preferences fails validation', () {
        final data = {
          'version': '1.0',
          'exportDate': DateTime.now().toIso8601String(),
          'metadata': {'appVersion': '1.0.0', 'platform': 'android', 'appName': 'Aimi'},
          'preferences': 'not-a-map',
        };

        expect(DataVersionMapper.validate(data), false);
      });

      test('wrong type for storage fails validation', () {
        final data = {
          'version': '1.0',
          'exportDate': DateTime.now().toIso8601String(),
          'metadata': {'appVersion': '1.0.0', 'platform': 'android', 'appName': 'Aimi'},
          'storage': ['not', 'a', 'map'],
        };

        expect(DataVersionMapper.validate(data), false);
      });
    });

    // =========================================================================
    // Cache Isolation Tests
    // =========================================================================
    group('Cache Isolation', () {
      test('clearAll clears all cache data', () async {
        await fakeCachingService.save(key: CacheKey.trendingAnime, data: ['anime1', 'anime2']);

        await fakeCachingService.clearAll();

        final cached = await fakeCachingService.get(key: CacheKey.trendingAnime);
        expect(cached, isNull);
      });

      test('storage data is independent from cache', () async {
        await fakeStorageService.save(key: StorageKey.watchHistory, data: {'episode1': 100});
        await fakeCachingService.save(key: CacheKey.trendingAnime, data: ['anime1']);

        await fakeCachingService.clearAll();

        final storageData = await fakeStorageService.get(key: StorageKey.watchHistory);
        expect(storageData, isNotNull);
        expect(storageData['episode1'], 100);
      });
    });

    // =========================================================================
    // Storage Isolation Tests
    // =========================================================================
    group('Storage Isolation', () {
      test('clearAll clears all storage data', () async {
        await fakeStorageService.save(key: StorageKey.watchHistory, data: {'episode1': 100});
        await fakeStorageService.save(key: StorageKey.searchHistory, data: ['query1', 'query2']);

        await fakeStorageService.clearAll();

        final watchHistory = await fakeStorageService.get(key: StorageKey.watchHistory);
        final searchHistory = await fakeStorageService.get(key: StorageKey.searchHistory);
        expect(watchHistory, isNull);
        expect(searchHistory, isNull);
      });

      test('cache data is independent from storage', () async {
        await fakeStorageService.save(key: StorageKey.watchHistory, data: {'episode1': 100});
        await fakeCachingService.save(key: CacheKey.trendingAnime, data: ['anime1']);

        await fakeStorageService.clearAll();

        final cacheData = await fakeCachingService.get(key: CacheKey.trendingAnime);
        expect(cacheData, isNotNull);
      });
    });

    // =========================================================================
    // Data Import/Export Tests
    // =========================================================================
    group('Data Import/Export', () {
      test('getAllData returns all stored data', () async {
        await fakeStorageService.save(key: StorageKey.watchHistory, data: {'key': 'value'});

        final allData = await fakeStorageService.getAllData();

        expect(allData, isNotEmpty);
      });

      test('importData adds data to storage', () async {
        final importData = {'key1': 'value1', 'key2': 'value2'};

        await fakeStorageService.importData(importData);

        final allData = await fakeStorageService.getAllData();
        expect(allData['key1'], 'value1');
        expect(allData['key2'], 'value2');
      });
    });

    // =========================================================================
    // Data Integrity Tests
    // =========================================================================
    group('Data Integrity', () {
      test('export metadata contains required fields', () {
        final metadata = DataVersionMapper.getMetadata();
        final json = metadata.toJson();

        expect(json.containsKey('appVersion'), true);
        expect(json.containsKey('platform'), true);
        expect(json.containsKey('appName'), true);
        expect(json.containsKey('exportTime'), true);
      });

      test('current version is valid', () {
        expect(DataVersionMapper.isValidVersion(DataVersionMapper.currentVersion), true);
      });

      test('migrated data retains original content', () {
        final originalData = {
          'version': DataVersionMapper.currentVersion,
          'exportDate': DateTime.now().toIso8601String(),
          'metadata': {'appVersion': '1.0.0', 'platform': 'test', 'appName': 'Aimi'},
          'preferences': {'theme': 'dark'},
          'storage': {
            'history': ['item1', 'item2'],
          },
        };

        final migrated = DataVersionMapper.migrate(originalData);

        expect(migrated, isNotNull);
        expect(migrated!['preferences'], originalData['preferences']);
        expect(migrated['storage'], originalData['storage']);
      });
    });
  });
}
