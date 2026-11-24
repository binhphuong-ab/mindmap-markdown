#!/bin/bash
# Builds "Mindmap Markdown.app" from the Swift package.
#   ./build.sh               build + install to /Applications
#   ./build.sh --no-install  build only (./Mindmap Markdown.app)
set -euo pipefail
cd "$(dirname "$0")"
APP_NAME="Mindmap Markdown"          # what users see
EXEC_NAME="MindmapMarkdown"          # SwiftPM product / executable (no spaces)
BUNDLE_ID="com.binhphuong-ab.mindmapmarkdown"
BUNDLE="$APP_NAME.app"
VERSION="1.0.3"

echo "==> swift build"
swift build -c release

echo "==> icon"
rm -rf build/AppIcon.iconset && mkdir -p build
swift tools/make-icon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns

echo "==> bundle"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp ".build/release/$EXEC_NAME" "$BUNDLE/Contents/MacOS/$EXEC_NAME"
cp build/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                 <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>          <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>           <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>              <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>   <string>$VERSION</string>
    <key>CFBundlePackageType</key>          <string>APPL</string>
    <key>CFBundleExecutable</key>           <string>$EXEC_NAME</string>
    <key>CFBundleIconFile</key>             <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>       <string>14.0</string>
    <key>NSHighResolutionCapable</key>      <true/>
    <key>LSApplicationCategoryType</key>    <string>public.app-category.productivity</string>
    <key>CFBundleDocumentTypes</key>
    <array><dict>
        <key>CFBundleTypeName</key>         <string>Markdown Mind Map</string>
        <key>CFBundleTypeRole</key>         <string>Editor</string>
        <key>LSHandlerRank</key>            <string>Alternate</string>
        <key>LSItemContentTypes</key>
        <array><string>net.daringfireball.markdown</string></array>
    </dict></array>
    <key>UTImportedTypeDeclarations</key>
    <array><dict>
        <key>UTTypeIdentifier</key>         <string>net.daringfireball.markdown</string>
        <key>UTTypeDescription</key>        <string>Markdown Document</string>
        <key>UTTypeConformsTo</key>         <array><string>public.plain-text</string></array>
        <key>UTTypeTagSpecification</key>
        <dict><key>public.filename-extension</key><array><string>md</string><string>markdown</string></array></dict>
    </dict></array>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$BUNDLE"
echo "==> built $BUNDLE"

if [[ "${1:-}" != "--no-install" ]]; then
    rm -rf "/Applications/$BUNDLE"
    cp -R "$BUNDLE" /Applications/
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/$BUNDLE"
    echo "==> installed /Applications/$BUNDLE"
fi
