#!/bin/bash

# Temporary workaround to address the issue between Longjing and Gradle multi-project build

chmod +x ./gradlew
./gradlew --max-workers=1 forge:build
# The assumption here is that there is only one file in the destination folder which has suffix '.jar'
TARGET_FILE=`ls ./build/`
FILE_WITH_BUILD_NUMBER="`basename $TARGET_FILE .jar`-$GITHUB_RUN_NUMBER.jar"

cp ./build/$TARGET_FILE ./build/$FILE_WITH_BUILD_NUMBER

echo "::set-output name=filename::$FILE_WITH_BUILD_NUMBER"
echo "::set-output name=artifact::`realpath ./build/$FILE_WITH_BUILD_NUMBER`"