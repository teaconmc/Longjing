#!/bin/sh

chmod +x ./gradlew
./gradlew runData
./gradlew -I ../setup.gradle --max-workers=1 build