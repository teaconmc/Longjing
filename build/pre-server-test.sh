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
curl -s 'https://biluochun.teacon.cn/api/v1/contest/1/deps' \
  | jq -M '[ .[] | select(.review_status == 1) | select(.type != 1) | { name: .filename, file: .download_url } ]' > main-deps.json