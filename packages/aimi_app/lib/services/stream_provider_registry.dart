import 'package:aimi_lib/aimi_lib.dart';

/// Registry to manage multiple stream providers
///
/// Allows switching between different streaming sources (AnimePahe, Anizone, etc.)
class StreamProviderRegistry {
  final List<IStreamProvider> _providers;
  int _currentIndex = 0;

  StreamProviderRegistry(this._providers) {
    if (_providers.isEmpty) {
      throw ArgumentError('At least one provider must be registered');
    }
  }

  /// Get all registered providers
  List<IStreamProvider> get providers => List.unmodifiable(_providers);

  /// Get provider names for UI display
  List<String> get providerNames => _providers.map((p) => p.name).toList();

  /// Get the current active provider
  IStreamProvider get current => _providers[_currentIndex];

  /// Get current provider name
  String get currentName => current.name;

  /// Get current provider index
  int get currentIndex => _currentIndex;

  /// Get provider by name
  IStreamProvider? getByName(String name) {
    try {
      return _providers.firstWhere((p) => p.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Get provider by index
  IStreamProvider getByIndex(int index) {
    if (index < 0 || index >= _providers.length) {
      throw RangeError.index(index, _providers, 'index');
    }
    return _providers[index];
  }

  /// Switch to a provider by index
  void switchToIndex(int index) {
    if (index < 0 || index >= _providers.length) {
      throw RangeError.index(index, _providers, 'index');
    }
    _currentIndex = index;
  }

  /// Switch to a provider by name
  bool switchToName(String name) {
    final index = _providers.indexWhere((p) => p.name == name);
    if (index == -1) return false;
    _currentIndex = index;
    return true;
  }

  /// Dispose all providers
  void dispose() {
    for (final provider in _providers) {
      provider.dispose();
    }
  }
}
