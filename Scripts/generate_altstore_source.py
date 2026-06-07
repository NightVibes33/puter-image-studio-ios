#!/usr/bin/env python3
import json
import os
from datetime import datetime, timezone
from pathlib import Path

root = Path(__file__).resolve().parents[1]
repo = os.environ.get("GITHUB_REPOSITORY", "OWNER/REPO")
tag = os.environ.get("RELEASE_TAG") or os.environ.get("GITHUB_REF_NAME", "v1.0.0")
version = os.environ.get("MARKETING_VERSION", "1.0")
build = os.environ.get("CURRENT_PROJECT_VERSION", os.environ.get("GITHUB_RUN_NUMBER", "1"))
ipa_name = os.environ.get("IPA_NAME", "ImageStudio-unsigned.ipa")
source_name = os.environ.get("SOURCE_NAME", "Image Studio Builds")
source_id = os.environ.get("SOURCE_IDENTIFIER", "com.nightvibes.imagestudio.source")
bundle_id = os.environ.get("PRODUCT_BUNDLE_IDENTIFIER", "com.nightvibes.imagestudio")
ipa_path = Path(os.environ.get("IPA_PATH", root / "build" / ipa_name))
icon_asset_name = os.environ.get("ICON_ASSET_NAME", "AppIcon.png")
base_release_url = f"https://github.com/{repo}/releases/download/{tag}"

size = int(os.environ.get("IPA_SIZE", ipa_path.stat().st_size if ipa_path.exists() else 0))
now = datetime.now(timezone.utc).replace(microsecond=0).isoformat()

source = {
    "name": source_name,
    "identifier": source_id,
    "sourceURL": os.environ.get("SOURCE_URL", f"{base_release_url}/altstore-source.json"),
    "apps": [
        {
            "name": "Image Studio",
            "bundleIdentifier": bundle_id,
            "developerName": os.environ.get("DEVELOPER_NAME", "Image Studio"),
            "subtitle": "Native AI image generation",
            "localizedDescription": (
                "A native SwiftUI image studio for prompt-to-image generation, "
                "style presets, model choices, local gallery, save, and share."
            ),
            "iconURL": os.environ.get("ICON_URL", f"{base_release_url}/{icon_asset_name}"),
            "tintColor": "1E78E8",
            "versions": [
                {
                    "version": version,
                    "buildVersion": str(build),
                    "marketingVersion": f"{version} ({build})",
                    "date": os.environ.get("VERSION_DATE", now),
                    "localizedDescription": os.environ.get(
                        "VERSION_NOTES",
                        "Native generator, model selector, style presets, gallery, save, and share."
                    ),
                    "downloadURL": os.environ.get("IPA_DOWNLOAD_URL", f"{base_release_url}/{ipa_name}"),
                    "size": size,
                    "minOSVersion": os.environ.get("MIN_OS_VERSION", "26.0"),
                }
            ],
            "appPermissions": {
                "entitlements": [],
                "privacy": {
                    "NSPhotoLibraryAddUsageDescription": (
                        "Image Studio saves generated artwork only when you tap Save."
                    )
                },
            },
        }
    ],
}

out = Path(os.environ.get("ALTSTORE_SOURCE_PATH", root / "build" / "altstore-source.json"))
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(source, indent=2) + "\n")
print(out)
