# ARR DMRV Mobile — Developer Setup

**Stack:** Flutter 3.22+ · Dart 3.3+ · Drift (SQLite offline) · Riverpod · Dio · flutter_map

**Package name:** `com.truecarbon.arrapp`

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter SDK | ≥ 3.22 | https://docs.flutter.dev/get-started/install |
| Android Studio | latest | For Android emulator + SDK |
| Xcode | ≥ 15 (macOS only) | App Store |
| arr-dmrv-api | Running | See API SETUP.md |

Verify Flutter setup:
```bash
flutter doctor
```
All items should be green (or at minimum Android toolchain ✅).

---

## 1 — Clone & Install

```bash
git clone https://github.com/ctgsindia/arr-dmrv-mobile.git
cd arr-dmrv-mobile
flutter pub get
```

---

## 2 — API URL Configuration

Edit `lib/core/config/api_config.dart`:

```dart
// For local development (emulator → host machine)
static const String baseUrl = 'http://10.0.2.2:3001/api/v1';

// For real device on same WiFi
static const String baseUrl = 'http://192.168.x.x:3001/api/v1';

// For production
static const String baseUrl = 'https://app.truecarbon.in/api/v1';
```

> **Android emulator:** `10.0.2.2` maps to your Mac/PC's localhost.
> **Physical device:** Use your machine's local IP address.

---

## 3 — Firebase Push Notifications Setup

Push notifications require a `google-services.json` file generated from Firebase Console.

1. Go to [Firebase Console](https://console.firebase.google.com) → your project
2. Project Settings → Add Android app
3. Package name: **`com.truecarbon.arrapp`**
4. Download `google-services.json`
5. Place at: `android/app/google-services.json`

> ⚠️ This file is gitignored — each developer must add it manually.
> Without it, the app compiles but FCM push notifications won't work.

---

## 4 — Run the App

```bash
# List connected devices / emulators
flutter devices

# Run on a specific device
flutter run -d <device-id>

# Run in debug mode (hot reload enabled)
flutter run

# Run on all connected devices
flutter run -d all
```

---

## 5 — Build APK (for testing / distribution)

```bash
# Debug APK (quick, no signing needed)
flutter build apk --debug

# Release APK (requires signing config)
flutter build apk --release

# App Bundle for Play Store
flutter build appbundle --release
```

### Release Signing

Create `android/key.properties`:
```properties
storePassword=<keystore password>
keyPassword=<key password>
keyAlias=<key alias>
storeFile=<path to .jks file>
```

> ⚠️ `key.properties` and `*.jks` files are gitignored — never commit these.

---

## 6 — Build for iOS (macOS only)

```bash
cd ios && pod install && cd ..
flutter build ios --release
```

Open `ios/Runner.xcworkspace` in Xcode to configure signing and upload to App Store Connect.

---

## Project Structure

```
lib/
├── main.dart                           # App entry point — Riverpod + router init
├── core/
│   ├── config/
│   │   ├── api_config.dart             # Base URL + timeout config
│   │   └── app_router.dart             # GoRouter route definitions
│   └── services/
│       ├── camera_service.dart         # Camera capture + GPS EXIF tagging
│       └── notification_service.dart   # FCM + local notifications
├── features/
│   ├── auth/
│   │   └── auth_provider.dart          # Login state, token storage, logout
│   ├── home/
│   │   └── home_screen.dart            # Dashboard tiles grid
│   ├── m01_planting/
│   │   └── tree_planting_screen.dart   # M01: GPS + photo + species picker
│   ├── m02_measurement/
│   │   └── dbh_measurement_screen.dart # M02: DBH + height measurement
│   ├── m03_census/ (planned)           # M03: Plot census (coming)
│   ├── m04_survival/ (planned)         # M04: Survival check (coming)
│   ├── nursery/
│   │   ├── nursery_screen.dart         # Nursery dashboard
│   │   └── nursery_dispatch_screen.dart
│   ├── biodiversity/
│   │   └── biodiversity_survey_screen.dart
│   └── participants/
│       └── participant_registration_screen.dart
assets/
├── icon/
│   ├── app_icon.png      # 1024×1024 — used by flutter_launcher_icons
│   └── splash_logo.png   # 512×512 — used for splash screen
```

---

## App Screens (Implemented)

| Screen | Module | Description |
|--------|--------|-------------|
| Login | Auth | JWT login, token refresh |
| Home | Core | Dashboard tiles — GPS status, pending sync, quick actions |
| Plant Tree | M01 | GPS coordinate capture, camera photo, species selection |
| DBH Measurement | M02 | Diameter at breast height + height entry, syncs to API |
| Register Participant | - | Farmer/landowner KYC with duplicate detection |
| Nursery Dashboard | - | Sapling batch tracking, dispatch recording |
| Biodiversity Survey | - | Flora/fauna count, Shannon index input |
| Profile | - | User info, logout |

---

## Offline-First Architecture

The app uses **Drift** (SQLite) as a local database with an upload queue:

1. All field data is written to local SQLite immediately
2. Background sync uploads to API when connectivity is available
3. Pending sync count shown on home screen
4. GPS data, photos, and measurements work 100% offline

---

## Common Flutter Commands

```bash
flutter pub get           # Install dependencies
flutter pub upgrade       # Upgrade dependencies
flutter clean             # Clear build cache
flutter run --release     # Run in release mode (no debug overlay)
flutter analyze           # Static analysis
dart format lib/          # Format all Dart files
```

---

## Environment Notes

- **No `.env` file for Flutter** — configuration is done via `lib/core/config/api_config.dart`
- **Sensitive files** (gitignored, add manually):
  - `android/app/google-services.json` — Firebase config
  - `android/key.properties` — signing config
  - `android/*.jks` / `*.keystore` — signing keystore
- **Build artifacts** (gitignored): `build/`, `.dart_tool/`, `android/.gradle/`
