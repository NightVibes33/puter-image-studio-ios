#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY' > /tmp/xcode26-path.txt
from pathlib import Path
import re

def version_key(path):
    match = re.search(r'Xcode_([0-9]+(?:\.[0-9]+)*)', path.name)
    if not match:
        return ()
    return tuple(int(part) for part in match.group(1).split('.'))

candidates = [path for path in Path('/Applications').glob('Xcode_26*.app') if path.is_dir()]
if not candidates and Path('/Applications/Xcode.app').is_dir():
    candidates = [Path('/Applications/Xcode.app')]
if not candidates:
    raise SystemExit('No Xcode 26 app found under /Applications')
print(max(candidates, key=version_key))
PY

XCODE_APP="$(cat /tmp/xcode26-path.txt)"
sudo xcode-select -s "$XCODE_APP/Contents/Developer"
xcodebuild -version
xcodebuild -showsdks
xcodebuild -showsdks | grep -E 'iphoneos26(\.|$)' >/dev/null
