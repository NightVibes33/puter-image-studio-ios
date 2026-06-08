# Image Studio iOS

Native SwiftUI image-generation app with a local-first Core ML SDXL path and optional cloud fallback through `POST /v1/images/generations`.

## Local SDXL / Apple Neural Engine

The Local SDXL model is the same class of setup described by LocalGen-style Reddit posts: Apple Core ML Stable Diffusion running on device with `.cpuAndNeuralEngine`, `SPLIT_EINSUM` attention, and reduced-memory loading. The app does not commit model weights. Users can install the model from Settings, or you can ship the extracted Hugging Face folder below as a bundled resource under `Application Support/LocalModels/`:

```text
coreml-stable-diffusion-xl-base-ios_split_einsum_compiled
```

Model archive:

```text
https://huggingface.co/apple/coreml-stable-diffusion-xl-base-ios/resolve/main/coreml-stable-diffusion-xl-base-ios_split_einsum_compiled.zip
```

The archive is about 3 GB compressed and needs roughly 10 GB free during download, extraction, and first Core ML compilation. The current local path targets 768x768 output and uses 8 denoising steps for mobile latency. Full 20-step SDXL will be much slower than the Reddit marketing numbers on most devices.

## Local Backend

Run the proof API from this machine:

```sh
node --no-jitless /root/puter-api-proof/server.js
curl http://127.0.0.1:8787/health
```

Debug builds use `http://127.0.0.1:8787` through the `IMAGE_API_BASE_URL` build setting. Public Release packaging requires `IMAGE_API_BASE_URL` to be supplied as a real deployed HTTPS endpoint; CI fails before building if the repository variable is missing.

For a local SideStore/AltStore build that uses the API already in `/root/puter-api-proof`, run that server on the same iPhone and dispatch the GitHub workflow with `api_base_url=http://127.0.0.1:8787` and `allow_localhost_api=true`. That IPA only generates while the root API process is running.

The app requests `b64_json` from the API, so the backend does not need to host generated image files for the iOS app. The app never calls `api.puter.com` and does not contain `PUTER_AUTH_TOKEN`. The token stays in the server process.

## Generate The Xcode Project

This repo uses an XcodeGen project file:

```sh
cd /root/puter-image-studio-ios
xcodegen generate
open PuterImageStudio.xcodeproj
```

Build with Xcode 15+ or newer. This iSH runtime currently exposes Litter BuildKit compatibility shims, not a complete iPhoneOS SDK, so local simulator/device compilation is expected to happen on macOS or after restoring BuildKit assets.

## Implemented V1 Scope

- Native SwiftUI generator as the first screen
- Local SDXL model option routed to Apple Core ML Stable Diffusion
- Prompt composer without app-side content restrictions
- Style presets that append prompt modifiers
- Aspect, model, and quality selectors
- Async API client with friendly HTTP/error mapping
- Image download into Application Support
- JSON-backed local gallery/history
- Detail screen with save, share, copy prompt, regenerate, and delete
- Settings for defaults, history clearing, privacy/terms/support, and service disclosure
- Mock client for previews and UI smoke work

## Production Checklist

- Keep the in-app Local SDXL installer working, or ship the extracted model as app resources / Apple-hosted assets before claiming offline generation.
- Deploy the API behind HTTPS and set the GitHub repository variable `IMAGE_API_BASE_URL` only if cloud fallback remains enabled.
- For local-only sideload testing, run `/root/puter-api-proof/server.js` and build with `api_base_url=http://127.0.0.1:8787`.
- Add backend rate limiting by anonymous device ID and IP.
- Keep model allowlists and final provider names backend-owned.
- Replace placeholder app icon assets before TestFlight.
- Run on iPhone SE and a large iPhone with light mode, dark mode, Dynamic Type, and VoiceOver.

## GitHub Runner Unsigned IPA

This project is configured for GitHub-hosted `macos-26` runners with Xcode 26 and the iOS 26 SDK. The workflow builds a real-device `iphoneos` product, disables local code signing, strips `_CodeSignature` and `embedded.mobileprovision`, and packages the app as:

```text
build/ImageStudio-unsigned.ipa
```

Run manually from GitHub Actions with the `iOS unsigned IPA` workflow, or push a `v*` tag. The workflow uploads these artifacts:

- `ImageStudio-unsigned.ipa`
- `altstore-source.json`
- `AppIcon.png`
- `source-url.txt`

If release publishing is enabled, those files are attached to the selected GitHub Release. Use the `altstore-source.json` release URL as the AltStore source URL. SideStore can also use the one-tap URL written to `source-url.txt`.

The stable sideload bundle ID is:

```text
com.nightvibes.imagestudio
```

Keep this bundle ID stable or AltStore/SideStore will treat future builds as a different app.

Local packaging requires macOS + Xcode 26:

```sh
xcodegen generate
Scripts/package_unsigned_ipa.sh
```
