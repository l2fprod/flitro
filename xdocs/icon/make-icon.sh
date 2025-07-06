#!/bin/bash
(
cd ../../Flitro/Assets.xcassets/AppIcon.appiconset
sips -z 16 16   ../../../xdocs/icon/Flitro@1024.png --out icon_16x16.png
sips -z 32 32   ../../../xdocs/icon/Flitro@1024.png --out icon_32x32.png
sips -z 64 64   ../../../xdocs/icon/Flitro@1024.png --out icon_64x64.png
sips -z 128 128 ../../../xdocs/icon/Flitro@1024.png --out icon_128x128.png
sips -z 256 256 ../../../xdocs/icon/Flitro@1024.png --out icon_256x256.png
sips -z 512 512 ../../../xdocs/icon/Flitro@1024.png --out icon_512x512.png
cp ../../../xdocs/icon/Flitro@1024.png icon_1024x1024.png
)