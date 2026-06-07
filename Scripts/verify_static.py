from pathlib import Path
import json
import plistlib

root = Path(__file__).resolve().parents[1]
with (root / 'Sources/PuterImageStudio/App/Info.plist').open('rb') as handle:
    plistlib.load(handle)

for path in (root / 'Sources/PuterImageStudio/Assets.xcassets').rglob('Contents.json'):
    json.loads(path.read_text())

for path in root.rglob('*.swift'):
    text = path.read_text()
    for opening, closing in [('(', ')'), ('[', ']'), ('{', '}')]:
        if text.count(opening) != text.count(closing):
            raise SystemExit(f'unbalanced {opening}{closing}: {path.relative_to(root)}')

print('static verification passed')
