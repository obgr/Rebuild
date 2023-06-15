#!/bin/bash

set -e

VERSION=$1
LOCAL=$2

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

if [ "x$LOCAL" == "xlocal" ]; then
    BUILD_PREFIX="."
else
    BUILD_PREFIX=".."
fi

BUILD_DIR="${BUILD_PREFIX}/build-${VERSION}"
if ! test -d $BUILD_DIR ; then
    echo "$BUILD_DIR missing"
    git clone https://github.com/armbian/build $BUILD_DIR
fi

ROOT_DIR=`pwd`
TAG=`git describe --always --tags`
NAME="rebuild-${VERSION}-${TAG}"

cd $BUILD_DIR
git checkout v23.05.2
git pull
rm -rf "userpatches"

cd $ROOT_DIR
cp -r "userpatches" "${BUILD_DIR}"
cp armbian/customize-image-${VERSION}.sh ${BUILD_DIR}/userpatches/customize-image.sh
cp armbian/recore.csc ${BUILD_DIR}/config/boards
rm -f "${BUILD_DIR}/patch/u-boot/u-boot-sunxi/allwinner-boot-splash.patch"

if [ "x$VERSION" == "xreflash" ]; then
    cp armbian/watermark-reflash.png ${BUILD_DIR}/packages/plymouth-theme-armbian/watermark.png
else
    cp armbian/watermark.png ${BUILD_DIR}/packages/plymouth-theme-armbian/watermark.png
fi

echo "${NAME}" > ${BUILD_DIR}/userpatches/overlay/rebuild/rebuild-version

cd $BUILD_DIR
DOCKER_EXTRA_ARGS="--cpus=12" ./compile.sh rebuild
IMG=`ls -1 output/images/ | grep "img.xz$"`

cd $ROOT_DIR
mv $BUILD_DIR/output/images/$IMG "${BUILD_PREFIX}/images/${NAME}.img.xz"
echo "🍰 Finished building ${NAME}"
