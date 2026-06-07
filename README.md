# Image Studio iOS

Native SwiftUI image-generation app that talks to the custom Puter-backed image API through `POST /v1/images/generations`.

## Local Backend

Run the proof API from this machine:

```sh
node --no-jitless /root/puter-api-proof/server.js
curl http://127.0.0.1:8787/health
```

Debug builds use `http://127.0.0.1:8787` through the `IMAGE_API_BASE_URL` build setting. Release builds are configured for `https://api.your-domain.example`; replace that with the deployed HTTPS API before TestFlight or App Store review.

The app never calls `api.puter.com` and does not contain `PUTER_AUTH_TOKEN`. The token stays in the server process.

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
- Prompt composer with max length guard
- Style presets that append prompt modifiers
- Aspect, model, and quality selectors
- Async API client with friendly HTTP/error mapping
- Image download into Application Support
- JSON-backed local gallery/history
- Detail screen with save, share, copy prompt, regenerate, and delete
- Settings for defaults, history clearing, privacy/terms/support, and service disclosure
- Mock client for previews and UI smoke work

## Production Checklist

- Deploy the API behind HTTPS and update `IMAGE_API_BASE_URL` for Release.
- Add backend rate limiting by anonymous device ID and IP.
- Keep model allowlists and final provider names backend-owned.
- Add real privacy policy and terms URLs in `AppSettingsStore`.
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
