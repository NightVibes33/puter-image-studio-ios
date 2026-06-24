#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCHEME="ImageStudio"
CONFIGURATION="Release"
PROJECT="ImageStudio.xcodeproj"
BUILD_ROOT="$ROOT_DIR/build"
IPA_NAME="ImageStudio-unsigned.ipa"

if [[ ! -d "$PROJECT" ]]; then
  echo "Missing $PROJECT. Run xcodegen generate first." >&2
  exit 2
fi

rm -rf "$BUILD_ROOT/DerivedData" "$BUILD_ROOT/ipa" "$BUILD_ROOT/$IPA_NAME"
mkdir -p "$BUILD_ROOT/ipa/Payload"

# Build with explicit skip of signing and dSYM generation to speed up and reduce error surface
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$BUILD_ROOT/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  AD_HOC_CODE_SIGNING_ALLOWED=YES \
  DEBUG_INFORMATION_FORMAT=dwarf \
  COMPILER_INDEX_STORE_ENABLE=NO \
  build

PRODUCT_DIR="$BUILD_ROOT/DerivedData/Build/Products/${CONFIGURATION}-iphoneos"
APP_PATH="$(find "$PRODUCT_DIR" -maxdepth 1 -name '*.app' -type d | head -n 1)"

if [[ -z "$APP_PATH" ]]; then
  echo "No .app product found in $PRODUCT_DIR" >&2
  ls -R "$BUILD_ROOT/DerivedData/Build/Products" >&2
  exit 3
fi

cp -R "$APP_PATH" "$BUILD_ROOT/ipa/Payload/"

# Cleanup
find "$BUILD_ROOT/ipa/Payload" -name '_CodeSignature' -type d -prune -exec rm -rf {} +
find "$BUILD_ROOT/ipa/Payload" -name 'embedded.mobileprovision' -type f -delete

(
  cd "$BUILD_ROOT/ipa"
  /usr/bin/zip -qry "$BUILD_ROOT/$IPA_NAME" Payload
)

IPA_SIZE="$(stat -f%z "$BUILD_ROOT/$IPA_NAME" 2>/dev/null || stat -c%s "$BUILD_ROOT/$IPA_NAME")"
echo "IPA_PATH=$BUILD_ROOT/$IPA_NAME" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "IPA_SIZE=$IPA_SIZE" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "Built unsigned IPA: $BUILD_ROOT/$IPA_NAME ($IPA_SIZE bytes)"
