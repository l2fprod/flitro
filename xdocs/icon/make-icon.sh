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

(
cd ../../Flitro/Assets.xcassets/MenuBarIcon.imageset
sips -z 22 22 -s format png  ../../../xdocs/icon/Flitro@22.svg --out icon_22x22.png
sips -z 44 44 -s format png  ../../../xdocs/icon/Flitro.svg --out icon_44x44.png
sips -z 66 66 -s format png  ../../../xdocs/icon/Flitro.svg --out icon_66x66.png
)
