# Aimi

**Aimi** is a modern, cross-platform anime streaming application built with Flutter. It features a modular architecture that separates the UI from the underlying data sources, allowing for a resilient
and customizable streaming experience.

|  ![Screenshot 1](images/img.png)  | ![Screenshot 3](images/img_2.png) |
|:---------------------------------:|:---------------------------------:|
| ![Screenshot 4](images/img_3.png) | ![Screenshot 5](images/img_4.png) |

## ✨ Key Features

- **Multi-Source Streaming**: Aggregates streams from various providers (e.g., AnimePahe, Anizone) into a unified interface.
- **Metadata Integration**: Rich anime details, trending lists, and search powered by metadata providers like AniList.
- **Cross-Platform**: Designed to run smoothly on **Android**, **Windows**, and potentially other Flutter-supported platforms.
- **High-Performance Player**: Built on top of `media_kit` for hardware-accelerated video playback.
- **Watch History**: Automatically tracks your progress and resumes where you left off.
- **Modular Design**: Easily extensible to support new streaming or metadata providers without changing the core app logic.

## 🏗️ Architecture

The project is structured as a **monorepo** to maintain separation of concerns between the application layer and the core logic.

### Packages

- **`packages/aimi_app`**: The Flutter application. It handles the UI, state management (Provider), and platform-specific integrations.
- **`packages/aimi_lib`**: A pure Dart library that defines the core abstractions and business logic. It contains:
    - **`IMetadataProvider`**: Interface for fetching anime details (Implemented by `AniList`).
    - **`IStreamProvider`**: Interface for fetching video streams (Implemented by `AnimePahe`, `Anizone`).
    - **Models**: Shared data structures used across the app.

## 🚀 Getting Started

Follow these steps to set up the project locally.

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Latest Stable)
- An IDE (VS Code or Android Studio) with Flutter plugins installed.

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/brokiem/aimi.git
   cd aimi
   ```

2. **Install dependencies**:
   You need to install dependencies for both the library and the app.
   ```bash
   # Install lib dependencies
   cd packages/aimi_lib
   flutter pub get

   # Install app dependencies
   cd ../aimi_app
   flutter pub get
   ```

3. **Run the Application**:
   Navigate to the app directory and run it on your preferred device.
   ```bash
   cd packages/aimi_app
   flutter run
   ```

## 📦 Prebuilt binaries / Releases

You can download ready-to-run binaries and installer files from the Releases page: https://github.com/brokiem/aimi/releases

Below are the typical files attached to each release and what they mean:

- app-arm64-v8a-release.apk — 64-bit Android build (arm64). Use on modern Android phones and tablets.
- app-armeabi-v7a-release.apk — 32-bit Android build (armv7). Use on older devices that require 32-bit binaries.
- app-x86_64-release.apk — x86-64 Android build. Usually intended for Android emulators running on x86_64 hosts.
- aimi-windows.zip — Windows binaries. Unzip and run `aimi_app.exe` to start the app.
- aimi-linux.zip — Linux binaries. Unzip, make the binary executable if needed, and run `./aimi_app`.

Quick tips:

- Installing APKs: enable "Install unknown apps" on the device or install via `adb install path/to/app.apk`.
- Emulators: prefer the `app-x86_64-release.apk` for emulators (better compatibility/performance).
- Windows: if Windows SmartScreen warns, you may need to allow the app or unblock the file via Properties -> Unblock.
- Linux: after unzipping, run `chmod +x aimi_app` if the binary isn't executable, then run `./aimi_app`.

## 🔌 Supported Providers

Currently, the following providers are implemented in `aimi_lib`:

| Type          | Provider  | Status   |
|:--------------|:----------|:---------|
| **Metadata**  | AniList   | ✅ Active |
| **Streaming** | AnimePahe | ✅ Active |
| **Streaming** | Anizone   | ✅ Active |

## 🤝 Conributions are welcome! If you'd like to add a new provider or improve the UI:

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/amazing-feature`).
3. Commit your changes.
4. Push to the branch.
5. Open a Pull Request.

## 📄 License

This project is licensed under the GNU v2.0 License - see the [LICENSE](LICENSE) file for details.
