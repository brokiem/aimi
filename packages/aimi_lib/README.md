# aimi_lib

A provider-agnostic abstraction layer for anime metadata and streaming services.

## Overview

`aimi_lib` provides a clean abstraction architecture that decouples your application from specific anime metadata providers (like AniList, MyAnimeList) and streaming providers (like AnimePahe, Anizone). This allows you to:

- **Switch providers easily** when one service shuts down
- **Use multiple providers** simultaneously with fallback support
- **Add new providers** without changing your application code
- **Maintain consistent interfaces** across different data sources

## Architecture

The library separates concerns into two main provider types:

### 1. Metadata Providers (`IMetadataProvider`)
Provide anime information and metadata:
- Anime details (title, description, images, etc.)
- Trending/popular anime lists
- Search functionality
- Anime relationships and tags

**Examples:** AniList, MyAnimeList, Kitsu

### 2. Stream Providers (`IStreamProvider`)
Provide actual video streaming sources:
- Search for anime on streaming platforms
- Get episode lists
- Extract stream URLs with different qualities

**Examples:** AnimePahe, Anizone, AllAnime

## Key Components

### Models (Domain Layer)
- `Anime` - Provider-agnostic anime metadata
- `Episode` - Episode information
- `StreamSource` - Video stream URL with quality info
- `StreamableAnime` - Anime representation from streaming sites

### Providers (Abstraction Layer)
- `IMetadataProvider` - Abstract interface for metadata sources
- `IStreamProvider` - Abstract interface for streaming sources
- `ProviderRegistry` - Central registry for managing providers

### Core
- `ProviderException` - Exception handling
- `ProviderConfig` - Configuration options

## Usage Example

```dart
import 'package:aimi_lib/aimi_lib.dart';

// Register providers (implementation would be in separate packages/files)
providerRegistry.registerMetadataProvider(AniListProvider());
providerRegistry.registerStreamProvider(AnimePaheProvider());

// Fetch trending anime from the metadata provider
final trendingAnime = await providerRegistry.metadataProvider.fetchTrending();

// Search for streams on the streaming provider
final streamResults = await providerRegistry.streamProvider.search(trendingAnime.first);

// Get episodes
final episodes = await providerRegistry.streamProvider.getEpisodes(streamResults.first);

// Get stream sources
final sources = await providerRegistry.streamProvider.getSources(
  episodes.first,
  options: {'mode': 'sub'},
);

// Switch to a different provider if needed
providerRegistry.setActiveStreamProvider('Gogoanime');
```

## Provider Switching

When a provider shuts down, simply implement a new provider and switch:

```dart
// Old provider stopped working
// providerRegistry.registerStreamProvider(OldProvider());

// Register new provider
providerRegistry.registerStreamProvider(NewProvider());
providerRegistry.setActiveStreamProvider('NewProvider');

// Your application code stays the same!
```

## Implementing Custom Providers

### Metadata Provider Example

```dart
class MyCustomMetadataProvider implements IMetadataProvider {
  @override
  String get name => 'MyCustomProvider';

  @override
  Future<List<Anime>> fetchTrending({int page = 1}) async {
    // Implement your logic here
    // Fetch from your API, parse, and return List<Anime>
  }

  @override
  Future<Anime> fetchAnimeById(int id) async {
    // Implement your logic here
  }

  @override
  Future<List<Anime>> searchAnime(String query, {int page = 1}) async {
    // Implement your logic here
  }
}
```

### Stream Provider Example

```dart
class MyCustomStreamProvider implements IStreamProvider {
  @override
  String get name => 'MyCustomStreamer';

  @override
  Future<List<StreamableAnime>> search(dynamic query) async {
    // Implement your logic here
  }

  @override
  Future<List<Episode>> getEpisodes(StreamableAnime anime) async {
    // Implement your logic here
  }

  @override
  Future<List<StreamSource>> getSources(
    Episode episode, {
    Map<String, dynamic>? options,
  }) async {
    // Implement your logic here
  }
}
```

## Project Structure

```
lib/
├── aimi_lib.dart                      # Main export file
└── src/
    ├── core/
    │   ├── config.dart                # Configuration
    │   └── exceptions.dart            # Custom exceptions
    ├── models/
    │   ├── anime.dart                 # Anime domain model
    │   ├── episode.dart               # Episode domain model
    │   ├── stream_source.dart         # Stream source model
    │   └── streamable_anime.dart      # Streamable anime model
    └── providers/
        ├── metadata_provider.dart     # Metadata provider interface
        ├── stream_provider.dart       # Stream provider interface
        └── provider_registry.dart     # Provider registry/manager
```

## Next Steps

1. **Implement concrete providers** based on existing services (AniListProvider, AnimePaheProvider)
2. **Add caching layer** for improved performance
3. **Implement fallback strategies** when a provider fails
4. **Add rate limiting** to respect provider APIs
5. **Create provider health checks** to automatically switch failing providers

## Benefits

✅ **Maintainability** - Change providers without touching application code  
✅ **Testability** - Easy to mock providers for testing  
✅ **Flexibility** - Use multiple providers with fallback support  
✅ **Scalability** - Add new providers as they become available  
✅ **Type Safety** - Strong typing with Dart's type system  
✅ **Clean Architecture** - Clear separation of concerns

## Installation

Add `aimi_lib` to your `pubspec.yaml`:

```yaml
dependencies:
  aimi_lib:
    path: ../aimi_lib # If using local path in monorepo
    # or git url if hosted remotely
```

## Implemented Providers

The library currently includes the following implementations:

- **Metadata**:
  - `AniListProvider`: Fetches data from AniList API.
- **Streaming**:
  - `AnimePaheProvider`: Scrapes streaming links from AnimePahe.
  - `AnizoneProvider`: Scrapes streaming links from Anizone.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

