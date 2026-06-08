# GitHub iOS 26 Unsigned IPA Builds

The `.github/workflows/ios-unsigned-ipa.yml` workflow builds on `macos-26`, selects Xcode 26, generates the Xcode project, and builds with `-sdk iphoneos` plus `CODE_SIGNING_ALLOWED=NO`.

## Manual Run

1. Push this project to GitHub.
2. Set the repository variable `IMAGE_API_BASE_URL` to the deployed HTTPS image API.
3. Open Actions -> iOS unsigned IPA.
4. Run workflow with `release_tag` set to a tag like `v1.0.0` or `nightly`.
5. Download the `ImageStudio-iOS26-unsigned` artifact, or use the GitHub Release assets if publishing is enabled.

## Release Assets

The workflow publishes:

- `ImageStudio-unsigned.ipa`: unsigned real-device IPA for AltStore/SideStore signing.
- `altstore-source.json`: AltSource-compatible source metadata.
- `AppIcon.png`: icon referenced by the source JSON.
- `source-url.txt`: source URLs for copying into AltStore/SideStore.

## Token

The workflow uses `${{ github.token }}` as `GH_TOKEN` to create or update release assets. The local `/root/gh_token.env` token is only needed if you want to push this repository or call GitHub from this shell.
