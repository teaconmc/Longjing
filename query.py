#!/usr/bin/env python3

import json
import os
import os.path
import subprocess
import sys
from string import Template
import urllib.request

# Fetch latest team information from Biluochun (TeaCon Admission Portal) API
# TODO https://bugs.python.org/issue40321
# See also https://github.com/python/cpython/pull/19588
# Flask will redirect /api/team to /api/team/ using a HTTP 308 which in turn triggers the bug above.
team_list_url = 'https://biluochun.teacon.cn/api/team/'
team_list = []
try:
    print('Fetching team/mod list')
    with urllib.request.urlopen(team_list_url, timeout = 10) as f:
        team_list = json.load(f)
except:
    print('Error occured while fetching participting team/mod list')
    if os.getenv('GITHUB_ACTIONS', False):
        print('::error::Error occured while fetching participting team/mod list, check log for details')
    print(sys.exc_info())
    exit(-1)
else:
    print('Successfully fetched team/mod list')

# Load GitHub Action Workflow template
# As we only perform simple string subtitution, we uses the built-in string.Template
workflow_template = None
with open('workflow_template.yaml') as f:
    workflow_template = Template(f.read())

# Check each team.
for team in team_list:
    print(f"Fetching information for team #{team['id']} ({team['name']}) from {team['repo']}")

    if not team['repo']:
        print(f"Team #{team['id']} ({team['name']}) doesn't seem to provide a valid git repo, skipping")
        print(f"The repo URI is {team['repo']}")
        if os.getenv('GITHUB_ACTIONS', False):
            print(f"::warning::Team #{team['id']} ({team['name']}) seems to have an invalid repo: {team['repo']}")
        continue
    
    # Escape ' by doubling it. YAML decides to use this for single-quoted strings.
    team['name'] = team['name'].replace("'", "''")
    team['mod_name'] = team['mod_name'].replace("'", "''")

    # Each team gets their own directory to storing related information.
    # Internal team id is used because it is permenant.
    info_dir = f"./mods/team-{team['id']}"

    # New team is signalled as absence of their tracking info in our repo. 
    # If a new team is found, we then create a directory for them.
    if not os.path.exists(info_dir):
        # Create meta information directory
        os.makedirs(info_dir)

    # Create workflow run, or force update it if already exist
    with open(f".github/workflows/team-{team['id']}.yaml", 'w') as f:
        f.write(workflow_template.substitute(team))
    
    # Write repo address to $info_dir/remote
    # This is always done in case that a team updates their remote repo address.
    with open(f"{info_dir}/remote", 'w') as f:
        f.write(team['repo'])
    
    # We use `git ls-remote $repo_url HEAD` to get the latest commit and use it to 
    # determine if we should trigger a build.
    # The sole criterion is "current HEAD commit hash is different from our recorded one".
    # We store the HEAD commit hash in `mods/team-${team_id}/HEAD`.
    # A new build is triggered by updating that recorded commit hash.
    previous_head = None
    if os.path.exists(f"{info_dir}/HEAD"):
        with open(f"{info_dir}/HEAD") as f:
            previous_head = f.read()
    try:
        get_head_process = subprocess.run(['git', 'ls-remote', team['repo'], 'HEAD'], 
            timeout = 10,
            capture_output = True, 
            text = True)
    except subprocess.TimeoutExpired:
        print(f"Timeout while fetching git repo information for team #{team['id']} (upstream {team['repo']})")
        if os.getenv('GITHUB_ACTIONS', False):
            print(f"::warning::Timeout while fetching {team['repo']} for team #{team['id']}. Information about this team will not be updated.")
        continue
    if get_head_process.returncode == 0:
        current_head = None
        if get_head_process.stdout:
            current_head = get_head_process.stdout.split()[0]
        if current_head != previous_head:
            with open(f"{info_dir}/HEAD", "w") as f:
                f.write(current_head)
    
