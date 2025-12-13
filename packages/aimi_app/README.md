# Aimi App

Aimi is a Flutter-based anime streaming application that allows users to search for, watch, and track their favorite anime.

## Features

-   **Anime Streaming**: Watch anime episodes directly within the app.
-   **Search**: Find anime by title.
-   **Watch History**: Keep track of episodes you've watched.
-   **Multi-Platform**: Runs on Android, Windows, and potentially other platforms supported by Flutter.
-   **Modern UI**: Built with Material Design and smooth animations.

## Getting Started

### Prerequisites

-   Flutter SDK
-   Dart SDK

### Installation

1.  Clone the repository.
2.  Navigate to the `packages/aimi_app` directory.
3.  Install dependencies:
    ```bash
    flutter pub get
    ```

### Running the App

To run the app on your connected device or emulator:

```bash
flutter run
```

## Permissions (Android)

The app requires the following permissions on Android:
-   Internet access (for streaming and fetching data)
-   Storage/Video/Audio permissions (for caching or local playback, depending on Android version)

## Built With

-   [Flutter](https://flutter.dev/) - UI Toolkit
-   [Provider](https://pub.dev/packages/provider) - State Management
-   [Dio](https://pub.dev/packages/dio) - HTTP Client
-   [Media Kit](https://pub.dev/packages/media_kit) - Video Playback
-   [aimi_lib](../aimi_lib) - Core Logic Library

