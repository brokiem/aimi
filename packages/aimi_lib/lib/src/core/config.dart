/// Configuration for provider behavior
class ProviderConfig {
  /// Timeout for network requests in seconds
  final int timeoutSeconds;

  /// Whether to enable debug logging
  final bool debugMode;

  /// Maximum number of retry attempts for failed requests
  final int maxRetries;

  /// User agent string for HTTP requests
  final String userAgent;

  /// Additional headers to include in all requests
  final Map<String, String>? defaultHeaders;

  const ProviderConfig({
    this.timeoutSeconds = 30,
    this.debugMode = false,
    this.maxRetries = 3,
    this.userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36',
    this.defaultHeaders,
  });

  ProviderConfig copyWith({
    int? timeoutSeconds,
    bool? debugMode,
    int? maxRetries,
    String? userAgent,
    Map<String, String>? defaultHeaders,
  }) {
    return ProviderConfig(
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      debugMode: debugMode ?? this.debugMode,
      maxRetries: maxRetries ?? this.maxRetries,
      userAgent: userAgent ?? this.userAgent,
      defaultHeaders: defaultHeaders ?? this.defaultHeaders,
    );
  }
}

