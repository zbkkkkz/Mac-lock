#!/bin/zsh
set -eu
cd "${0:A:h}"
release_root=$(mktemp -d /tmp/lightlock-independent.XXXXXX)
app="$release_root/Mac lock.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
swiftc -swift-version 5 -parse-as-library -target arm64-apple-macosx13.0 Application.swift ControlPanel.swift InputGate.swift -o "$app/Contents/MacOS/MacLock"
cp Info.plist "$app/Contents/Info.plist"
cp LightLock.icns "$app/Contents/Resources/MacLock.icns"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
print "生成应用：$app"
