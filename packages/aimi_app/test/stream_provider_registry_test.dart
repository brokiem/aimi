import 'package:aimi_app/services/stream_provider_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('StreamProviderRegistry', () {
    late FakeStreamProvider providerA;
    late FakeStreamProvider providerB;
    late FakeStreamProvider providerC;

    setUp(() {
      providerA = FakeStreamProvider('ProviderA');
      providerB = FakeStreamProvider('ProviderB');
      providerC = FakeStreamProvider('ProviderC');
    });

    // =========================================================================
    // Construction Tests
    // =========================================================================
    group('Construction', () {
      test('throws when no providers are provided', () {
        expect(() => StreamProviderRegistry([]), throwsA(isA<ArgumentError>()));
      });

      test('initializes with first provider as current', () {
        final registry = StreamProviderRegistry([providerA, providerB]);

        expect(registry.currentName, 'ProviderA');
        expect(registry.currentIndex, 0);
      });

      test('providers getter returns unmodifiable list', () {
        final registry = StreamProviderRegistry([providerA, providerB]);
        final providers = registry.providers;

        expect(providers, hasLength(2));
        expect(() => (providers as List).add(providerC), throwsUnsupportedError);
      });
    });

    // =========================================================================
    // Provider Access Tests
    // =========================================================================
    group('Provider Access', () {
      late StreamProviderRegistry registry;

      setUp(() {
        registry = StreamProviderRegistry([providerA, providerB, providerC]);
      });

      test('current returns the active provider', () {
        expect(registry.current.name, 'ProviderA');
      });

      test('currentName returns the active provider name', () {
        expect(registry.currentName, 'ProviderA');
      });

      test('currentIndex returns the active provider index', () {
        expect(registry.currentIndex, 0);
      });

      test('providerNames returns all provider names', () {
        final names = registry.providerNames;

        expect(names, ['ProviderA', 'ProviderB', 'ProviderC']);
      });

      test('getByName returns correct provider', () {
        final provider = registry.getByName('ProviderB');

        expect(provider, isNotNull);
        expect(provider?.name, 'ProviderB');
      });

      test('getByName returns null for unknown provider', () {
        final provider = registry.getByName('UnknownProvider');

        expect(provider, isNull);
      });

      test('getByIndex returns correct provider', () {
        final provider = registry.getByIndex(1);

        expect(provider.name, 'ProviderB');
      });

      test('getByIndex throws for invalid index', () {
        expect(() => registry.getByIndex(-1), throwsRangeError);
        expect(() => registry.getByIndex(10), throwsRangeError);
      });
    });

    // =========================================================================
    // Provider Switching Tests
    // =========================================================================
    group('Provider Switching', () {
      late StreamProviderRegistry registry;

      setUp(() {
        registry = StreamProviderRegistry([providerA, providerB, providerC]);
      });

      test('switchToIndex changes current provider', () {
        registry.switchToIndex(1);

        expect(registry.currentName, 'ProviderB');
        expect(registry.currentIndex, 1);
        expect(registry.current.name, 'ProviderB');
      });

      test('switchToIndex throws for invalid index', () {
        expect(() => registry.switchToIndex(-1), throwsRangeError);
        expect(() => registry.switchToIndex(5), throwsRangeError);
      });

      test('switchToName changes current provider', () {
        final result = registry.switchToName('ProviderC');

        expect(result, isTrue);
        expect(registry.currentName, 'ProviderC');
        expect(registry.currentIndex, 2);
      });

      test('switchToName returns false for unknown provider', () {
        final result = registry.switchToName('UnknownProvider');

        expect(result, isFalse);
        expect(registry.currentName, 'ProviderA'); // Unchanged
      });

      test('switching preserves provider order', () {
        registry.switchToIndex(2);
        registry.switchToIndex(0);

        expect(registry.providerNames, ['ProviderA', 'ProviderB', 'ProviderC']);
      });
    });

    // =========================================================================
    // Disposal Tests
    // =========================================================================
    group('Disposal', () {
      test('dispose calls dispose on all providers', () {
        // Using real providers that track disposal would be better,
        // but FakeStreamProvider.dispose() is a no-op, so we just verify no errors
        final registry = StreamProviderRegistry([providerA, providerB]);

        expect(() => registry.dispose(), returnsNormally);
      });
    });

    // =========================================================================
    // Edge Cases
    // =========================================================================
    group('Edge Cases', () {
      test('works with single provider', () {
        final registry = StreamProviderRegistry([providerA]);

        expect(registry.providerNames, ['ProviderA']);
        expect(registry.current.name, 'ProviderA');
        expect(registry.getByIndex(0).name, 'ProviderA');
      });

      test('switching to same index is no-op', () {
        final registry = StreamProviderRegistry([providerA, providerB]);

        registry.switchToIndex(0);

        expect(registry.currentIndex, 0);
      });

      test('switching to same name is valid', () {
        final registry = StreamProviderRegistry([providerA, providerB]);

        final result = registry.switchToName('ProviderA');

        expect(result, isTrue);
        expect(registry.currentName, 'ProviderA');
      });
    });
  });
}
