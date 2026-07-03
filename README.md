# Image Studio iOS

Native SwiftUI image-generation app built for fully local, on-device SDXL inference.

## Product Direction

This app is local only:

- prompts stay on device
- generated images stay on device unless the user exports them
- generation uses Apple Core ML Stable Diffusion
- there is no cloud fallback, auth flow, or backend dependency in the app runtime

## Local SDXL Runtime

The app targets Apple Core ML Stable Diffusion with Apple Neural Engine acceleration when available and a CPU fallback when needed.

Expected model folder:

```text
coreml-stable-diffusion-xl-base-ios_split_einsum_compiled
```

Default install archive:

```text
https://huggingface.co/apple/coreml-stable-diffusion-xl-base-ios/resolve/main/coreml-stable-diffusion-xl-base-ios_split_einsum_compiled.zip
```

Operational expectations:

- roughly 3 GB compressed download
- roughly 10 GB free space required during install
- much slower generation on lower-tier devices
- offline generation after the model is installed successfully

## App Capabilities

- native SwiftUI generate screen
- fully local SDXL generation path
- local model installer with download, resume, verify, extract, validate, and activate phases
- prompt styling presets and aspect presets
- local history/gallery stored in Application Support
- image detail view with share and reuse actions
- settings focused on local runtime and model management

## Build

This repo uses XcodeGen:

```sh
cd /root/puter-image-studio-ios
xcodegen generate
```

Build and archive on macOS with Xcode 26 or newer.

## Unsigned IPA Workflow

The GitHub Actions workflow builds an unsigned real-device IPA on `macos-26` and uploads:

- `ImageStudio-unsigned.ipa`

Workflow file:

```text
.github/workflows/ios-unsigned-ipa.yml
```

Local packaging on macOS:

```sh
xcodegen generate
Scripts/package_unsigned_ipa.sh
```
