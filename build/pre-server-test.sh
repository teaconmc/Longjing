#!/bin/bash

# Fetch the list of dependency from Biluochun, then assemble the mod list to be read by 
# the dedicated-launch-test action.
# Fetching is done by curl.
# List assembling is done by jq. Filter is read as following:
#   - .[] iterates over all elements in JSON array
#   - select(.review_status == 1) selects all approved dependency
#   - select(.type != 1) selects non-client-only dependency (i.e. common and server-only)
#   - { name: ..., file: ... } transforms input JSON object into the needed format
#   - The enclosing [] collects everything into an JSON array 
#
# TODO[3TUSK]: You see, there is this hard-coded contest ID inside URL... you shouldn't hardcode it.
# TeaCon 甲辰 has ID of 3.
curl -s 'https://biluochun.teacon.cn/api/v1/contest/3/deps' \
  | jq -M '[ .[] | select(.review_status == 1) | select(.type != 1) | { name: .filename, file: .download_url } ]' > main-deps.json

# If requested (see build.sh, line 38), fetch the list of all submitted works from Biluochun, 
# pick all submitted works with successful builds, then assemble the mod list to be read by 
# the dedicated-launch-test action.
# If not requested, we use an empty JSON array as a placeholder.
if [ "$LONGJING_REQUIRE_OTHER_WORKS" = "true" ]; then
  curl -s https://biluochun.teacon.cn/api/v1/contest/2/teams \
    | jq -M '[ .[] | select( .test_version != null ) | select( .ready ) | { mod_id: ( .work_id | gsub("_"; "-") ), build: .test_version.longjing_number, filename: .test_version.longjing_artifact_name }]' \
    | jq -M '[ .[] | { name: .filename, file: "https://archive.teacon.cn/jiachen/ci/build/team-\(.mod_id)/\(.mod_id)-\(.build).jar" } ]' > extra-deps.json
elif [ "$HOTFIX" = "true" ]; then # 传统艺能：硬编码修问题
  curl -s https://biluochun.teacon.cn/api/v1/contest/2/teams \
    | jq -M '[ .[] | select( .test_version != null ) | select( .work_id == "sinofoundation" ) | { mod_id: ( .work_id | gsub("_"; "-") ), build: .test_version.longjing_number, filename: .test_version.longjing_artifact_name }]' \
    | jq -M '[ .[] | { name: .filename, file: "https://archive.teacon.cn/jiachen/ci/build/team-\(.mod_id)/\(.mod_id)-\(.build).jar" } ]' > extra-deps.json
else
  echo '[]' > extra-deps.json
fi

# Merge two JSON array into one.
# Ref: https://stackoverflow.com/questions/42011086/merge-arrays-of-json
jq '.[]' main-deps.json extra-deps.json | jq -s > all-deps.json
