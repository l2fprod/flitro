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
cp -R $APP_PATH build/Release

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
codesign --force --options runtime --keychain build.keychain --sign "$APPLE_CERTIFICATE_IDENTITY" --entitlements Flitro/Flitro.entitlements build/Release/Flitro.app

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
