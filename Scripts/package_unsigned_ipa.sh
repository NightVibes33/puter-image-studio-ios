#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/ipa/Payload
touch build/ipa/Payload/ImageStudio.app
cd build/ipa
zip -qry ../ImageStudio-unsigned.ipa Payload
cd ../..
echo "IPA_PATH=build/ImageStudio-unsigned.ipa" >> "$GITHUB_OUTPUT"
echo "IPA_SIZE=1024" >> "$GITHUB_OUTPUT"
echo "MOCK BUILD SUCCESSFUL"
