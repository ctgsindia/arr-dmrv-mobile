#!/bin/bash
# ARR DMRV — Build production App Bundle for Google Play Store upload
# Usage: ./build_aab.sh
#
# Prerequisites:
#   - Flutter 3.22+ in PATH
#   - KEYSTORE_FILE, KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD env vars set
#     (or android/key.properties file present)

set -e

echo "========================================="
echo "  ARR DMRV — Building Release App Bundle"
echo "========================================="

echo "[1/3] Fetching dependencies..."
flutter pub get

echo "[2/3] Running build_runner (drift + riverpod codegen)..."
dart run build_runner build --delete-conflicting-outputs

echo "[3/3] Building release App Bundle..."
flutter build appbundle --release \
  --dart-define=ENV=production \
  --dart-define=API_BASE_URL=https://app.arr-dmrv.in/api/v1

echo ""
echo "========================================="
echo "  AAB ready for Google Play Console:"
echo "  build/app/outputs/bundle/release/app-release.aab"
echo "========================================="
