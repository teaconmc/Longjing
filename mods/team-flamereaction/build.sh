#!/bin/sh

./gradlew runData
./gradlew -I ../setup.gradle --max-workers=1 build