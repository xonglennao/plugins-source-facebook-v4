#!/bin/bash

#Build Facebook from source
sh ../sdk/ios/src/scripts/build_framework.sh

path=`dirname $0`

#
# Checks exit value for error
#
checkError() {
    if [ $? -ne 0 ]
    then
        echo "Exiting due to errors (above)"
        exit -1
    fi
}

#
# Canonicalize relative paths to absolute paths
#
pushd $path > /dev/null
dir=`pwd`
path=$dir
popd > /dev/null

#sh ../sdk/ios/src/updateFacebook.sh

#
# Build plugin
#
CONFIG=Release
TARGET=facebook
BINARY=lib$TARGET.a
OUTPUT_DIR=$path/../../build/$TARGET/ios

# Clean
xcodebuild -project "$path/Plugin.xcodeproj" -target $TARGET -configuration $CONFIG clean
checkError

rm -rf "$OUTPUT_DIR"
checkError

mkdir -p "$OUTPUT_DIR"
checkError

# iOS
xcodebuild -project "$path/Plugin.xcodeproj" -target $TARGET -configuration $CONFIG -sdk iphoneos
checkError

# Xcode Simulator
xcodebuild -project "$path/Plugin.xcodeproj" -target $TARGET -configuration $CONFIG -sdk iphonesimulator
checkError

# create universal binary
lipo -create "$path"/build/$CONFIG-iphoneos/$BINARY "$path"/build/$CONFIG-iphonesimulator/$BINARY -output "$OUTPUT_DIR"/$BINARY
checkError
