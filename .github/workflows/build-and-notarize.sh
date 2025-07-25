#!/bin/bash
set -e

if [ -z "$APPLE_ID" ]; then
    echo "APPLE_ID is not set"
    exit 1
fi

#APPLE_ID="${{ secrets.APPLE_ID }}"
#APPLE_PASSWORD="${{ secrets.APPLE_PASSWORD }}"
#APPLE_TEAM_ID="${{ secrets.APPLE_TEAM_ID }}"

#KEYCHAIN_PASSWORD="${{ secrets.KEYCHAIN_PASSWORD }}"
#APPLE_CERTIFICATE="${{ secrets.APPLE_CERTIFICATE }}"
#APPLE_CERTIFICATE_PASSWORD="${{ secrets.APPLE_CERTIFICATE_PASSWORD }}"
#APPLE_CERTIFICATE_IDENTITY="${{ secrets.APPLE_CERTIFICATE_IDENTITY }}"

# Run tests first
xcodebuild test -project Flitro.xcodeproj -scheme Flitro -configuration Release ENABLE_TESTABILITY=YES

# Build the app
xcodebuild -project Flitro.xcodeproj -scheme Flitro -configuration Release build

# Find the built app in DerivedData
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Flitro.app" -type d -path "*/Build/Products/Release*" | head -n 1)
echo "Found app at: $APP_PATH"

# Create a directory for the release
mkdir -p build/Release

# Copy the app
cp -R $APP_PATH build/Release

# Set CFBundleVersion to build number (timestamp)
BUILD_NUMBER=$(date -u "+%Y%m%d%H%M")
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" build/Release/Flitro.app/Contents/Info.plist

# Create a temporary keychain
echo "Creating keychain..."
security create-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
security default-keychain -s build.keychain
security unlock-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
security set-keychain-settings -t 3600 -u build.keychain

# Import certificates
echo "$APPLE_CERTIFICATE" | base64 --decode > build/certificate.p12
security import build/certificate.p12 -k build.keychain -P "$APPLE_CERTIFICATE_PASSWORD" -T /usr/bin/codesign

# Allow codesign to access the keychain
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" build.keychain

# Sign the app
codesign --force --options runtime --deep --keychain build.keychain --sign "$APPLE_CERTIFICATE_IDENTITY" --entitlements Flitro/Flitro.entitlements build/Release/Flitro.app

# Create a zip file for notarization
(cd build/Release && ditto -c -k --keepParent Flitro.app Flitro-to-notarize.zip)
          
# Submit for notarization
xcrun notarytool submit build/Release/Flitro-to-notarize.zip \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_PASSWORD" \
  --team-id "$APPLE_TEAM_ID" \
  --wait
          
# Staple the notarization ticket
xcrun stapler staple build/Release/Flitro.app
          
# Create the final zip file with the notarized app
(cd build/Release && ditto -c -k --keepParent Flitro.app Flitro.zip)

# Get base version from built Info.plist
BASE_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" build/Release/Flitro.app/Contents/Info.plist)

# Generate Sparkle appcast XML for auto-update
ZIP_PATH="build/Release/Flitro.zip"
ZIP_SIZE=$(stat -f%z "$ZIP_PATH")
ZIP_SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
APPCAST_PATH="build/Release/appcast.xml"

cat > "$APPCAST_PATH" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
     xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Flitro Updates</title>
    <link>https://github.com/l2fprod/flitro/releases/latest</link>
    <description>Latest updates for Flitro</description>
    <language>en</language>
    <item>
      <title>Version $BASE_VERSION (build $BUILD_NUMBER)</title>
      <description>Latest release of Flitro.</description>
      <sparkle:version>$BUILD_NUMBER</sparkle:version>
      <sparkle:shortVersionString>$BASE_VERSION</sparkle:shortVersionString>
      <pubDate>$(date -u "+%a, %d %b %Y %H:%M:%S GMT")</pubDate>
      <enclosure
        url="https://github.com/l2fprod/flitro/releases/download/latest/Flitro.zip"
        length="$ZIP_SIZE"
        type="application/zip"
        sparkle:sha256="$ZIP_SHA256"/>
    </item>
  </channel>
</rss>
EOF
