#!/bin/bash
set -euo pipefail
SOURCE="$(cd "$(dirname "$0")/.." && pwd -P)"
if [ -f "$SOURCE/../.velin-workspace" ]; then CACHE="$SOURCE/../work"; else CACHE="$SOURCE/work"; fi
mkdir -p "$CACHE/swift-cache"
xcrun swiftc -swift-version 5 -module-cache-path "$CACHE/swift-cache" -parse-as-library "$SOURCE/Sources/Models.swift" "$SOURCE/Sources/AIClient.swift" "$SOURCE/Tests/CoreTests.swift" -o "$CACHE/velin-tests"
python3 "$SOURCE/Tests/run_transport.py" "$CACHE/velin-tests"
python3 -m unittest discover -s "$SOURCE/Tests" -p 'test_release.py' -v

xcrun swiftc -swift-version 5 -module-cache-path "$CACHE/swift-cache" -parse-as-library "$SOURCE/Sources/Models.swift" "$SOURCE/Sources/Keychain.swift" "$SOURCE/Sources/AIClient.swift" "$SOURCE/Sources/AudioCapture.swift" "$SOURCE/Sources/AppModel.swift" "$SOURCE/Tests/ProfileRegression.swift" -framework AppKit -framework SwiftUI -framework AVFoundation -framework Speech -framework ScreenCaptureKit -framework Security -framework PDFKit -o "$CACHE/profile-regression"
python3 "$SOURCE/Tests/run_transport.py" "$CACHE/profile-regression"
