# Releases & Downloads

Download ready-to-run binaries from the **[Releases](https://github.com/brokiem/aimi/releases)** page.

## Available Builds

| File | Platform | Description |
|:-----|:---------|:------------|
| `app-arm64-v8a-release.apk` | Android | 64-bit (arm64) — Modern phones/tablets |
| `app-armeabi-v7a-release.apk` | Android | 32-bit (armv7) — Older devices |
| `app-x86_64-release.apk` | Android | x86-64 — Emulators |
| `aimi-windows.zip` | Windows | Unzip and run `aimi_app.exe` |
| `aimi-linux.zip` | Linux | Unzip and run `./aimi_app` |

## Installation Tips

### Android
- Enable **"Install unknown apps"** on your device, or install via:
  ```bash
  adb install path/to/app.apk
  ```
- For emulators, use `app-x86_64-release.apk` for better performance.

### Windows
- If Windows SmartScreen shows a warning, click "More info" → "Run anyway"
- Alternatively: Right-click the file → Properties → Check "Unblock"

### Linux
- After unzipping, make the binary executable:
  ```bash
  chmod +x aimi_app
  ./aimi_app
  ```
