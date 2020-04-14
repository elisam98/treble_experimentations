#!/bin/bash
set -e

if [ -z "$USER" ];then
    export USER="$(id -un)"
fi
export LC_ALL=C
export GAPPS_SOURCES_PATH=vendor/opengapps/sources/

## set defaults

rom_fp="$(date +%y%m%d)"

myname="$(basename "$0")"
jobs=32

read -p "Do you want to sync? (y/N) " build_dakkar_choice

function clone_or_checkout() {
    local dir="$1"
    local repo="$2"

    if [[ -d "$dir" ]];then
        (
            cd "$dir"
            git fetch
            git reset --hard
            git checkout origin/android-8.1
        )
    else
        git clone https://github.com/elisam98/"$repo" "$dir" -b android-8.1
    fi
}

function patch_things() {
    rm -f device/*/sepolicy/common/private/genfs_contexts
    cd device/phh/treble
    if [[ $build_dakkar_choice == *"y"* ]];then
        git clean -fdx
    fi
    bash generate.sh lineage
    cd /home/cornbeefonrye/kosheros
    bash /home/cornbeefonrye/treble_experimentations/apply-patches.sh /home/cornbeefonrye/kosheros
    repo manifest -r > release/"$rom_fp"/manifest.xml
    echo "listing patches"
    bash /home/cornbeefonrye/treble_experimentations/list-patches.sh
    cp /home/cornbeefonrye/kosheros/patches.zip /home/cornbeefonrye/kosheros/release/"$rom_fp"/patches.zip
}

mkdir -p /home/cornbeefonrye/kosheros/release/"$rom_fp"

if [[ $build_dakkar_choice == *"y"* ]];then
    repo init -u https://github.com/LineageOS/android.git -b lineage-15.1
    clone_or_checkout .repo/local_manifests treble_manifest
    wget "https://github.com/phhusson/treble_experimentations/releases/download/v32/patches.zip" -O /home/cornbeefonrye/kosheros/patches.zip
    rm -Rf /home/cornbeefonrye/kosheros/patches
    unzip patches.zip

    # We don't want to replace from AOSP since we'll be applying
    # patches by hand
    rm -f .repo/local_manifests/replace.xml

    # Remove exfat entry from local_manifest if it exists in ROM manifest 
    if grep -rqF exfat .repo/manifests || grep -qF exfat .repo/manifest.xml;then
        sed -i -E '/external\/exfat/d' .repo/local_manifests/manifest.xml
    fi
    repo sync -c -j 32 -f --force-sync --no-tag --no-clone-bundle --optimized-fetch --prune
fi

patch_things

make installclean
rm -rf "$OUT"
. build/envsetup.sh

lunch treble_arm_avN-userdebug
make WITHOUT_CHECK_API=true BUILD_NUMBER="$rom_fp" installclean
make WITHOUT_CHECK_API=true BUILD_NUMBER="$rom_fp" -j 32 systemimage
make WITHOUT_CHECK_API=true BUILD_NUMBER="$rom_fp" vndk-test-sepolicy
cp "$OUT"/system.img release/"$rom_fp"/system-kosheros.img
