# Security Checks

Run before TestFlight:

```sh
cd /root/puter-image-studio-ios
rg -n "PUTER_AUTH_TOKEN|api\.puter\.com|puter-token" Sources project.yml README.md APP_STORE_REVIEW_NOTES.md
```

Expected result: no hits in `Sources/`. Mentions in docs are acceptable only when documenting that secrets stay server-side.

Release builds must use HTTPS for `IMAGE_API_BASE_URL`; do not submit a build pointed at localhost.

## Unsigned IPA Checks

After CI builds an IPA, inspect it before publishing:

```sh
unzip -l build/ImageStudio-unsigned.ipa | rg 'Payload/.*\.app/'
unzip -l build/ImageStudio-unsigned.ipa | rg '_CodeSignature|embedded.mobileprovision' && exit 1 || true
python3 -m json.tool build/altstore-source.json >/dev/null
```

The IPA is intentionally unsigned so AltStore or SideStore can sign it with the user's Apple ID during install.
