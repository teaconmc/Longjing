#!/bin/bash

COMMON_OPTS="--endpoint-url '$S3_ENDPOINT'"

ARTIFACT_PATH="2021/ci/build/team-$TEAM_ID/build-$GITHUB_RUN_NUMBER/$ARTIFACT_NAME"

aws s3 cp $COMMON_OPTS $ARTIFACT_NAME s3://$ARTIFACT_PATH
aws s3 cp $COMMON_OPTS $ARTIFACT_NAME.sig s3://$ARTIFACT_PATH.sig

echo "::set-output name=download::https://archive.teacon.cn/$ARTIFACT_PATH"
