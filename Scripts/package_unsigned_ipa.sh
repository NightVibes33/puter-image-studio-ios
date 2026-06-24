#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
rm -rf build && mkdir -p build/ipa/Payload
xcodebuild -project ImageStudio.xcodeproj -scheme ImageStudio -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" AD_HOC_CODE_SIGNING_ALLOWED=YES build
APP_PATH="$(find build/DerivedData -name '*.app' -type d | head -n 1)"
cp -R "$APP_PATH" build/ipa/Payload/
cd build/ipa && zip -qry ../ImageStudio-unsigned.ipa Payload
cd ../..
echo "IPA_PATH=build/ImageStudio-unsigned.ipa" >> "$GITHUB_OUTPUT"
echo "IPA_SIZE=$(stat -f%z build/ImageStudio-unsigned.ipa)" >> "$GITHUB_OUTPUT"
