#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCHEME="${SCHEME:-ImageStudio}"
CONFIGURATION="${CONFIGURATION:-Release}"
PROJECT="${PROJECT:-ImageStudio.xcodeproj}"
BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/build}"
IPA_NAME="${IPA_NAME:-ImageStudio-unsigned.ipa}"
APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-Image Studio}"
IOS_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-26.0}"
MARKETING_VERSION="${MARKETING_VERSION:-1.0}"
CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-1}"
IMAGE_API_BASE_URL="${IMAGE_API_BASE_URL:-}"
ALLOW_LOCALHOST_API="${ALLOW_LOCALHOST_API:-0}"

is_localhost_api() {
  [[ "$IMAGE_API_BASE_URL" == http://127.0.0.1:* || "$IMAGE_API_BASE_URL" == http://localhost:* ]]
}

is_https_api() {
  [[ "$IMAGE_API_BASE_URL" == https://* && "$IMAGE_API_BASE_URL" != *.example* && "$IMAGE_API_BASE_URL" != *.invalid* ]]
}

if [[ ! -d "$PROJECT" ]]; then
  echo "Missing $PROJECT. Run xcodegen generate first." >&2
  exit 2
fi

rm -rf "$BUILD_ROOT/DerivedData" "$BUILD_ROOT/ipa" "$BUILD_ROOT/$IPA_NAME"
mkdir -p "$BUILD_ROOT/ipa/Payload"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$BUILD_ROOT/DerivedData" \
  IPHONEOS_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET" \
  MARKETING_VERSION="$MARKETING_VERSION" \
  CURRENT_PROJECT_VERSION="$CURRENT_PROJECT_VERSION" \
  IMAGE_API_BASE_URL="$IMAGE_API_BASE_URL" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  build

PRODUCT_DIR="$BUILD_ROOT/DerivedData/Build/Products/${CONFIGURATION}-iphoneos"
APP_PATH="$(find "$PRODUCT_DIR" -maxdepth 1 -name '*.app' -type d | head -n 1)"

if [[ -z "$APP_PATH" ]]; then
  echo "No .app product found in $PRODUCT_DIR" >&2
  exit 3
fi

BUILT_INFO_PLIST="$APP_PATH/Info.plist"
cp -R "$APP_PATH" "$BUILD_ROOT/ipa/Payload/"

# Keep the IPA unsigned for AltStore/SideStore to sign during install.
find "$BUILD_ROOT/ipa/Payload" -name '_CodeSignature' -type d -prune -exec rm -rf {} +
find "$BUILD_ROOT/ipa/Payload" -name 'embedded.mobileprovision' -type f -delete

(
  cd "$BUILD_ROOT/ipa"
  /usr/bin/zip -qry "$BUILD_ROOT/$IPA_NAME" Payload
)

IPA_SIZE="$(stat -f%z "$BUILD_ROOT/$IPA_NAME" 2>/dev/null || stat -c%s "$BUILD_ROOT/$IPA_NAME")"
APP_BUNDLE="$(basename "$APP_PATH")"

echo "IPA_PATH=$BUILD_ROOT/$IPA_NAME" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "IPA_SIZE=$IPA_SIZE" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "APP_BUNDLE=$APP_BUNDLE" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "Built unsigned IPA: $BUILD_ROOT/$IPA_NAME ($IPA_SIZE bytes)"
