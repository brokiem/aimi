# Installation Guide

Follow these steps to set up the project locally for development.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Latest Stable)
- An IDE (VS Code or Android Studio) with Flutter plugins installed.

## Setup

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

## Troubleshooting

If you encounter any issues during setup, please:
1. Ensure you have the latest stable Flutter SDK installed
2. Run `flutter doctor` to verify your environment
3. Check the [Issues](https://github.com/brokiem/aimi/issues) page for solutions
