/// Exception thrown when a provider operation fails
class ProviderException implements Exception {
  final String message;
  final String providerName;
  final dynamic originalError;
  final StackTrace? stackTrace;

  ProviderException({
    required this.message,
    required this.providerName,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    var result = 'ProviderException [$providerName]: $message';
    if (originalError != null) {
      result += '\nCaused by: $originalError';
    }
    return result;
  }
}

/// Exception thrown when no providers are available
class NoProviderException implements Exception {
  final String message;

  NoProviderException(this.message);

  @override
  String toString() => 'NoProviderException: $message';
}

/// Exception thrown when a provider is not found
class ProviderNotFoundException implements Exception {
  final String providerName;
  final String type; // 'metadata' or 'stream'

  ProviderNotFoundException(this.providerName, this.type);

  @override
  String toString() =>
      'ProviderNotFoundException: $type provider "$providerName" not found';
}

/// Exception thrown when stream extraction fails
class StreamExtractionException implements Exception {
  final String message;
  final String? providerName;
  final dynamic originalError;

  StreamExtractionException({
    required this.message,
    this.providerName,
    this.originalError,
  });

  @override
  String toString() {
    var result = 'StreamExtractionException';
    if (providerName != null) result += ' [$providerName]';
    result += ': $message';
    if (originalError != null) {
      result += '\nCaused by: $originalError';
    }
    return result;
  }
}
