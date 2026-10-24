#!/usr/bin/env bash
#
# Build a signed Android App Bundle (.aab) for upload to Google Play.
#
# Prerequisites (one-time):
#   1. Create an upload keystore:
#        keytool -genkeypair -v -keystore android/upload-keystore.jks \
#          -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
#   2. Copy android/key.properties.example to android/key.properties and fill in
#      storePassword / keyPassword / keyAlias / storeFile.
#
# The resulting bundle is written to:
#   build/app/outputs/bundle/release/app-release.aab
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f android/key.properties ]]; then
  echo "error: android/key.properties not found." >&2
  echo "       Copy android/key.properties.example and fill in your keystore details." >&2
  exit 1
fi

flutter clean
flutter pub get
flutter build appbundle --release

echo
echo "Play Store bundle: build/app/outputs/bundle/release/app-release.aab"
