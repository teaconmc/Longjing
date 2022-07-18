#!/bin/bash

# Temporary workaround to address the issue between Longjing and Gradle multi-project build

./gradlew --max-workers=1 -PbuildVersion=1.18.2 forge:build
# The assumption here is that there is only one file in the destination folder which has suffix '.jar'
TARGET_FILE=`ls ./build/release`
FILE_WITH_BUILD_NUMBER="`basename $TARGET_FILE .jar`-$GITHUB_RUN_NUMBER.jar"

cp ./build/release/$TARGET_FILE ./build/release/$FILE_WITH_BUILD_NUMBER

echo "::set-output name=filename::$FILE_WITH_BUILD_NUMBER"
echo "::set-output name=artifact::`realpath ./build/release/$FILE_WITH_BUILD_NUMBER`"