#!/bin/bash

CHECK_SUIT=`curl --silent --header 'accept: application/vnd.github.v3+json' https://api.github.com/repos/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID | jq -r .check_suite_url`

CHECK_RUNS=`curl --silent --header 'accept: application/vnd.github.v3+json' $CHECK_SUIT | jq -r .check_runs_url`

CHECK_RUN=`curl --silent --header 'accept: application/vnd.github.v3+json' $CHECK_RUNS | jq -r '.check_runs[0].url'`

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

curl --silent -X PATCH -d \@payload.json \
  --header "authorization: Bearer $TOKEN" \
  --header 'accept: application/vnd.github.v3+json' \
  $CHECK_RUN

cat > payload.json <<EOM
{"ref": "teacon2021"}
EOM

curl --silent -X POST -d \@payload.json \
  --header "authorization: Bearer $TOKEN" \
  --header 'accept: application/vnd.github.v3+json' \
  https://api.github.com/repos/$GITHUB_REPOSITORY/actions/workflows/pack.yaml/dispatches
