#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCHEME="ImageStudio"
CONFIGURATION="Release"
PROJECT="ImageStudio.xcodeproj"
BUILD_ROOT="$ROOT_DIR/build"
IPA_NAME="ImageStudio-unsigned.ipa"

# Detect the installed iphoneos SDK (e.g. iphoneos26.0)
SDK=$(xcodebuild -showsdks 2>/dev/null | grep -oE 'iphoneos[0-9]+\.[0-9]+' | sort -V | tail -1)
if [[ -z "$SDK" ]]; then
  SDK="iphoneos"
fi
echo "Using SDK: $SDK"

rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT/ipa/Payload"

echo "Starting xcodebuild..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk "$SDK" \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$BUILD_ROOT/DerivedData" \
  -clonedSourcePackagesDirPath .spm-cache \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  AD_HOC_CODE_SIGNING_ALLOWED=YES \
  COMPILER_INDEX_STORE_ENABLE=NO \
  DEBUG_INFORMATION_FORMAT=dwarf \
  build

PRODUCT_DIR="$BUILD_ROOT/DerivedData/Build/Products/${CONFIGURATION}-iphoneos"
echo "Searching for .app in $PRODUCT_DIR..."
APP_PATH="$(find "$PRODUCT_DIR" -maxdepth 1 -name '*.app' -type d | head -n 1)"

if [[ -z "$APP_PATH" ]]; then
  echo "ERROR: No .app product found in $PRODUCT_DIR" >&2
  find "$BUILD_ROOT/DerivedData" -name "*.app" -type d
  exit 1
fi

echo "Found app at: $APP_PATH"
cp -R "$APP_PATH" "$BUILD_ROOT/ipa/Payload/"

cd "$BUILD_ROOT/ipa"
zip -qry "../$IPA_NAME" Payload
cd "$ROOT_DIR"

IPA_SIZE="$(stat -f%z "$BUILD_ROOT/$IPA_NAME" 2>/dev/null || stat -c%s "$BUILD_ROOT/$IPA_NAME")"
echo "Built unsigned IPA: $BUILD_ROOT/$IPA_NAME ($IPA_SIZE bytes)"
