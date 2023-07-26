#!/bin/bash

die() {
    echo "$*"
    exit -1
}

LONGJING_CONFIG_URL="$BILUOCHUN_URL/api/v1/team/$TEAM_ID/longjing"

# -H specifies header
# -S suppress non-error log
# -f will raise any status code > 400 to non-zero exit status
# -o specifies output destination
CURL_OPTIONS=( --no-progress-meter -S -f -o ./longjing-config.json )

curl ${CURL_OPTIONS[@]} $LONGJING_CONFIG_URL || die Fail to fetch Longjing cnofig

which jq >/dev/null || die Cannot find program jq, build process cannot continue

# Retrieve special build command, fallback to 'build' if not specified
BUILD_COMMAND=$(jq -rM .build_command ./longjing-config.json)
if [ -z "$BUILD_COMMAND" ] || [ "$BUILD_COMMAND" = 'null' ]; then
    BUILD_COMMAND=build
fi
# https://unix.stackexchange.com/questions/459367/using-shell-variables-for-command-options
# tl;dr: DO NOT TRY STUFFING CLI OPTIONS INTO SHELL VARIABLE
BUILD_COMMAND=( $BUILD_COMMAND )

# Retrieve name of the task responsible for producing the jar, fallback to empty string 
# if it is string 'null'.
OUTPUT_JAR_TASK=$(jq -rM .output_task ./longjing-config.json)
if [ -z "$OUTPUT_JAR_TASK" ] || [ "$OUTPUT_JAR_TASK" = 'null' ]; then
    unset OUTPUT_JAR_TASK
fi
echo Target output jar task will be: $OUTPUT_JAR_TASK

# Let later steps know if they need all other submitted works in order to run dedicated server test
echo "LONGJING_REQUIRE_OTHER_WORKS=$(jq -rM .require_other_works ./longjing-config.json)" >> $GITHUB_ENV

cd repo

if [ "$GRADLE_WRAPPER_CHECK" = 'true' ] && [ -f './gradlew' ]; then
    chmod +x ./gradlew
    GRADLE_EXEC=./gradlew 
else
    echo '::warning::Gradle wrapper is not found, which is not recommended. Using system-level gradle instead.'
    GRADLE_EXEC=gradle
fi

# Here used to be --max-workers=1 to workaround an recurring issue regarding reobf failure.
# However, according to https://github.com/MinecraftForge/ForgeGradle/pull/755, the issue should have been fixed. 
# If we observe anything similar to theMinecraftForge/ForgeGradle#697 again, add it back.
# We add empty socks.proxyHost, http.proxyHost and https.proxyHost system properties, so that any pre-existing 
# proxy configurations are void in CI environment. We do not need any proxy on GitHub Action.
TEACON_ARTIFACT_TASK=$OUTPUT_JAR_TASK $GRADLE_EXEC -Dsocks.proxyHost= -Dhttp.proxyHost= -Dhttps.proxyHost= --stacktrace -I ../setup.gradle "${BUILD_COMMAND[@]}" teaconLongjingProcessing