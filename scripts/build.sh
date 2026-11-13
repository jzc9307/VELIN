#!/bin/bash
set -euo pipefail
SOURCE="$(cd "$(dirname "$0")/.." && pwd -P)"
if [ -f "$SOURCE/../.velin-workspace" ]; then PROJECT="$(cd "$SOURCE/.." && pwd -P)"; else PROJECT="$SOURCE/dist"; fi
CACHE="$PROJECT/work"
mkdir -p "$CACHE/swift-cache" "$PROJECT/outputs"
STAGE="$(mktemp -d /private/tmp/velin-build.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/VELIN.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
python3 "$SOURCE/scripts/release.py" check
xcrun swiftc -swift-version 5 -O -module-cache-path "$CACHE/swift-cache" -target arm64-apple-macos14 -parse-as-library "$SOURCE"/Sources/*.swift -framework SwiftUI -framework AppKit -framework Speech -framework AVFoundation -framework ScreenCaptureKit -framework Security -framework Carbon -framework PDFKit -o "$APP/Contents/MacOS/VELIN"
cp "$SOURCE/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$SOURCE/Resources/VELIN.icns" "$APP/Contents/Resources/"
ditto "$SOURCE/Resources/Providers" "$APP/Contents/Resources/Providers"
cp "$SOURCE/LICENSE" "$APP/Contents/Resources/LICENSE.txt"
cp "$SOURCE/THIRD-PARTY.md" "$APP/Contents/Resources/THIRD-PARTY.md"
ditto "$SOURCE/docs" "$APP/Contents/Resources/Guides"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
# Never replace the executable underneath a running app.
if pgrep -x VELIN >/dev/null; then echo 'Quit VELIN before replacing its app bundle.' >&2; exit 1; else status=$?; if [ "$status" -ne 1 ]; then echo 'Cannot verify running processes. Build with process-list access before replacing the app.' >&2; exit 1; fi; fi
# Preserve the outer .app directory so Finder/Spotlight keep one file identity.
if [ -d "$PROJECT/VELIN.app/Contents" ]; then
  mv "$PROJECT/VELIN.app/Contents" "$STAGE/previous-Contents"
  if ! ditto --noextattr --norsrc "$APP/Contents" "$PROJECT/VELIN.app/Contents"; then
    rm -rf "$PROJECT/VELIN.app/Contents"
    mv "$STAGE/previous-Contents" "$PROJECT/VELIN.app/Contents"
    exit 1
  fi
else
  ditto --noextattr --norsrc "$APP" "$PROJECT/VELIN.app"
fi
codesign --verify --deep --strict "$PROJECT/VELIN.app"
echo "Built $PROJECT/VELIN.app"
