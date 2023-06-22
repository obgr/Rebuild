#!/bin/bash

set -e

VERSION=$1

case $VERSION in
    barebone|mainsail|fluidd|octoprint|reflash)
        echo "Building $VERSION"
        ;;
    *)
        echo "Wrong argument '$1'"
        echo "Usage: $0 <barebone|mainsail|fluidd|octoprint|reflash>"
        exit 1
    ;; 
esac

BUILD_DIR="../build-${VERSION}"
if ! test -d "$BUILD_DIR" ; then
    echo "$BUILD_DIR missing"
    git clone https://github.com/armbian/build $BUILD_DIR
fi

ROOT_DIR=$(pwd)
TAG=$(git describe --always --tags)
NAME="rebuild-${VERSION}-${TAG}"

cd $BUILD_DIR
git reset --hard
git checkout v.23.05.2
git pull
rm -rf "userpatches"

cd "$ROOT_DIR"
cp -r "userpatches" "${BUILD_DIR}"
cp armbian/customize-image-"${VERSION}".sh "${BUILD_DIR}"/userpatches/customize-image.sh
cp armbian/recore.csc "${BUILD_DIR}"/config/boards
rm -f "${BUILD_DIR}/patch/u-boot/u-boot-sunxi/allwinner-boot-splash.patch"

if [ "$VERSION" == "reflash" ]; then
    cp armbian/watermark-reflash.png "${BUILD_DIR}"/packages/plymouth-theme-armbian/watermark.png
else
    cp armbian/watermark.png "${BUILD_DIR}"/packages/plymouth-theme-armbian/watermark.png
fi

echo "${NAME}" > "${BUILD_DIR}"/userpatches/overlay/rebuild/rebuild-version

cd "$BUILD_DIR"
DOCKER_EXTRA_ARGS="--cpus=12" ./compile.sh rebuild
IMG=$(ls -1 output/images/ | grep "img.xz$")

mv "$BUILD_DIR"/output/images/"$IMG" "../images/${NAME}.img.xz"
echo "🍰 Finished building ${NAME}"
