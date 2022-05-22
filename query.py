#!/usr/bin/env python3

import json
import os
import os.path
import subprocess
import sys

from string import Template
from urllib.request import urlopen
from typing import List, Optional, TypedDict, Literal

# Print the fetch error message
def fetch_error():
    print('Error occured while fetching the contest or participting team/mod list')
    if os.getenv('GITHUB_ACTIONS', False):
        print('::error::Error occured while fetching participting team/mod list, check log for details')
    print(sys.exc_info())
    exit(-1)

# Get the contest id
def get_contest_id(contest_name: str) -> int:
    try:
        url = 'https://biluochun.teacon.cn/api/v1/contest'
        with urlopen(url, timeout=15) as body:
            contest_list = json.load(body)
            for contest in contest_list:
                if contest['title'] == contest_name:
                    return contest['id']
                
    except:
        fetch_error()

class Team(TypedDict):
    id: int; name: str
    type: Literal[0, 1, 2]; repo: Optional[str]
    work_id: str; work_name: str; work_description: str

# Fetch latest team information from Biluochun (TeaCon Admission Portal) API
# Remark: https://bugs.python.org/issue40321
# See also https://github.com/python/cpython/pull/19588
# That issue exists back when Biluochun was still built on Flask.
def get_teams(contest_id: int) -> List[Team]:
    team_list = []
    try:
        print('Fetching team/mod list')
        url = f'https://biluochun.teacon.cn/api/v1/contest/teams?contest={contest_id}'
        with urlopen(url, timeout = 15) as f:
            team_list: List[Team] = json.load(f)
            team_list.sort(key=lambda t: t['id'])
            print('Successfully fetched team/mod list')
            return team_list
    except:
        fetch_error()

# Load GitHub Action Workflow template
# As we only perform simple string subtitution, we uses the built-in string.Template
def load_workflow_template() -> Optional[str]:
    workflow_template: Optional[str] = None
    with open('workflow_template.yaml') as f:
        workflow_template = Template(f.read())
    return workflow_template

# Write team informations including workflow files and git head references
def write_team_info(team: Team, workflow_template: str) -> None:
    print(f"Fetching information for team #{team['id']} ({team['name']}) from {team['repo']}")

    skip = False

    if not team['repo']:
        print(f"Team #{team['id']} ({team['name']}) did not provide a git repo address, skipping")
        if os.getenv('GITHUB_ACTIONS', False):
            print(f"::warning::Team #{team['id']} ({team['name']}) did not provide a git repo address.")
        skip = True
    
    # Escape ' by doubling it. YAML decides to use this for single-quoted strings.
    team['name'] = team['name'].replace("'", "''")
    team['work_name'] = team['work_name'].replace("'", "''")

    team_ref_name = f"team-{team['work_id'].replace('_', '-')}"

    # Each team gets their own directory to storing related information.
    # Internal team id is used because it is permenant.
    info_dir = f"mods/teacon2022/{team_ref_name}"

    # Create workflow run, or force update it if already exist
    with open(f".github/workflows/teacon2022-{team_ref_name}.yaml", 'w') as f:
        f.write(workflow_template.substitute(
            title=f"TeaCon 2022 | {team['work_name']} | {team['name']}",
            job_title=f"Build {team['work_name']}",
            work_id=team['work_id'],
            info_dir=info_dir))

    if skip:
        return

    # New team is signalled as absence of their tracking info in our repo. 
    # If a new team is found, we then create a directory for them.
    # Create meta information directory
    os.makedirs(info_dir, exist_ok=True)
    # Skip teams that have declared withdrawal
    #if os.path.exists(f"{info_dir}/withdrawn"):
    if team['type'] == 2:
        print(f"Team #{team['id']} ({team['name']}) has withdrawn, skipping")
        return
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
    head_ref = 'HEAD'
    if os.path.exists(f"{info_dir}/ref"):
        with open(f"{info_dir}/ref") as f:
            head_ref = f.read()
    try:
        get_head_process = subprocess.run(['git', 'ls-remote', team['repo'], head_ref],
            timeout = 10,
            capture_output = True, 
            text = True)
    except subprocess.TimeoutExpired:
        print(f"Timeout while fetching git repo information for team #{team['id']} (upstream {team['repo']})")
        if os.getenv('GITHUB_ACTIONS', False):
            print(f"::warning::Timeout while fetching {team['repo']} for team #{team['id']}. Information about this team will not be updated.")
        return
    if get_head_process.returncode == 0:
        current_head = None
        if get_head_process.stdout:
            current_head = get_head_process.stdout.split()[0]
        if current_head != previous_head:
            with open(f"{info_dir}/HEAD", "w") as f:
                f.write(current_head)

def write_readme(team_list: List[Team]):
    readme='''# TeaCon 2022 参赛团队列表

    |团队 ID|团队名 |作品名 |Mod ID|简介   |仓库地址|
    |:------|------:|:------|------|:------|------|
    '''

    readme+='\n'.join([ f"|{t['id']}|{t['name']}|{t['work_name']}|`{t['work_id']}`|" + t['work_description'].replace('\n', '<br />') + f"|{t['repo']}" for t in team_list ])

    with open('mods/README.md', 'w+') as f:
        f.write(readme)

if __name__ == '__main__':
    workflow_template = load_workflow_template()
    contest_id = get_contest_id('TeaCon 2022')
    team_list = get_teams(contest_id)

    for team in team_list: write_team_info(team, workflow_template)
    write_readme(team_list)
