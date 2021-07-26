#!/bin/bash

# Auth as our GitHub App. Use `source` so we stay in the same shell.
source auth.sh

COMMON_OPTS="--silent -H 'accept: application/vnd.github.v3+json'"

# Both $DOWNLOAD_LINK and $MAVEN_COORD are set via env var.
cat > payload.json <<EOM
{
  "output": {
    "title": "Build success",
    "summary": "Longjing has successfully produced a build.",
    "annotations":[
      {
        "path": ".github",
        "start_line": 1,
        "end_line": 1,
        "annotation_level": "notice",
        "message": "You may download the build result at: $DOWNLOAD_LINK",
        "title": "Download",
        "raw_details": "$MAVEN_COORD"
      }
    ]
  }
}
EOM

curl $COMMON_OPTS https://api.github.com/repos/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID \
  | jq -r .check_suite_url \
  | xargs curl $COMMON_OPTS \
  | jq -r .check_runs_url \
  | xargs curl $COMMON_OPTS \
  | jq -r '.check_runs[0].url' \
  | xargs curl $COMMON_OPTS -X PATCH -d \@payload.json -H "authorization: Bearer $TOKEN"

curl $COMMON_OPTS -X POST -d '{"ref": "teacon2021"}' \
  --header "authorization: Bearer $TOKEN" \
  https://api.github.com/repos/$GITHUB_REPOSITORY/actions/workflows/pack.yaml/dispatches
