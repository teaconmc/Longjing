#!/bin/bash

# Common options used by `aws s3` command
COMMON_OPTS="--endpoint-url $S3_ENDPOINT"

# Full path in the bucket
ARTIFACT_PATH="2022/ci/build/team-$TEAM_ID/build-$GITHUB_RUN_NUMBER/$ARTIFACT_NAME"

# Test the archive first. If fails, then we terminates the process early
zip -T $ARTIFACT_NAME || { echo "Integrity check failed for $ARTIFACT_NAME, not a valid zip file"; exit 1; }

# Do the actual upload
RETRY='0'
SUCCESS=''
while [ $RETRY -lt 5 ]; do
  aws s3 cp $COMMON_OPTS $ARTIFACT_NAME s3://$ARTIFACT_PATH && { SUCCESS='yes'; break; }
  RETRY=$[$RETRY+1]
  echo "Retry $RETRY time(s)..."
done
if [ -z "$SUCCESS" ]; then
  aws s3 cp $COMMON_OPTS $ARTIFACT_NAME s3://$ARTIFACT_PATH
fi
RETRY='0'
SUCCESS=''
while [ $RETRY -lt 5 ]; do
  aws s3 cp $COMMON_OPTS $ARTIFACT_NAME.asc s3://$ARTIFACT_PATH.asc && { SUCCESS='yes'; break; }
  RETRY=$[$RETRY+1]
  echo "Retry $RETRY time(s)..."
done
if [ -z "$SUCCESS" ]; then
  aws s3 cp $COMMON_OPTS $ARTIFACT_NAME.asc s3://$ARTIFACT_PATH.asc
fi

# Pass out the escaped URL for other steps in the workflow to use
ARTIFACT_PATH_ESCAPED=`python3 -c "import urllib.parse; print(urllib.parse.quote('''$ARTIFACT_PATH'''))"`

echo "::set-output name=download::https://archive.teacon.cn/$ARTIFACT_PATH_ESCAPED"
