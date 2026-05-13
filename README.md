# ARR DMRV — Flutter Mobile App

Field data collection app for Afforestation, Reforestation & Revegetation carbon projects.
Supports Verra VM0047 v1.1, Gold Standard ARR v2.1, and ACR ARR v1.3.

Built by CapriTech Global Services Pvt. Ltd., Mumbai.

---

## Prerequisites

| Tool | Version |
|------|---------|
| Flutter | 3.22+ |
| Dart | 3.3+ |
| Android Studio | Hedgehog+ (for Android builds) |
| Xcode | 15+ (for iOS builds, macOS only) |
| Java | 17 (for Gradle) |

---

## Setup

```bash
# 1. Install dependencies + run code generation
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 2. Verify setup
flutter doctor
```

---

## Run Locally

```bash
# Connect to local Docker API (default)
flutter run --dart-define=ENV=local --dart-define=API_BASE_URL=http://localhost:3001/api/v1

# Connect to staging API
flutter run --dart-define=ENV=staging --dart-define=API_BASE_URL=https://staging.arr-dmrv.in/api/v1
```

### Connect Android device to local Docker API

The Docker API runs on port 3001 on your Mac. Use adb reverse to forward it to the device:

```bash
adb reverse tcp:3001 tcp:3001
```

Then run the app with `API_BASE_URL=http://localhost:3001/api/v1`.

---

## Test Login Credentials

| Role | Email | Password |
|------|-------|----------|
| Field Executive | fe1@arr.local | Admin@1234 |
| Field Executive | fe2@arr.local | Admin@1234 |
| L1 Supervisor | l1@arr.local | Admin@1234 |
| Programme Manager | pm@arr.local | Admin@1234 |

Seed data is auto-loaded by `docker compose up`. To re-seed:
```bash
docker exec arr-api node src/data/admin-seed.js
```

---

## Build Release APK (Android)

```bash
# Set signing env vars (or create android/key.properties — see below)
export KEYSTORE_FILE=/path/to/arr-dmrv.jks
export KEYSTORE_PASSWORD=your_store_password
export KEY_ALIAS=arr_dmrv
export KEY_PASSWORD=your_key_password

./build_apk.sh
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### android/key.properties (alternative to env vars)

```properties
storeFile=/path/to/arr-dmrv.jks
storePassword=your_store_password
keyAlias=arr_dmrv
keyPassword=your_key_password
```

This file is in `.gitignore` — never commit it.

---

## Build App Bundle (Google Play)

```bash
./build_aab.sh
# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## Generate App Icons & Splash Screen

1. Place your icon PNG (1024×1024, no alpha) at `assets/icon/app_icon.png`
2. Place your splash logo PNG at `assets/icon/splash_logo.png`
3. Run:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

---

## Project Structure

```
lib/
  core/         # API client, DB (Drift), auth, constants
  features/     # One folder per feature domain (trees, plots, biomass…)
  main.dart     # App entry + Riverpod ProviderScope + GoRouter
assets/
  images/       # Static UI assets
  icon/         # App icon + splash logo (not committed — add your own)
android/        # Android native project
ios/            # iOS native project
```

---

## Key Tech

| Layer | Package |
|-------|---------|
| State | flutter_riverpod ^2.5.1 |
| Local DB | drift ^2.18.0 |
| HTTP | dio ^5.4.3 |
| Maps | flutter_map ^7.0.2 |
| GPS | geolocator ^12.0.0 |
| Camera | camera ^0.11.0 |
| Navigation | go_router ^14.2.0 |

---

*ARR DMRV Platform — CapriTech Global Services Pvt. Ltd.*
