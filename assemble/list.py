#!/usr/bin/env python3

# Requires boto3.
# Get it via pip:
#   pip3 install boto3

import boto3
from botocore.client import Config
from botocore.exceptions import ClientError
import io
import json
import os
import urllib.request

headers={
  'Accept': 'application/vnd.github.v3+json',
  'Authorization': f"token {os.getenv('AUTH_TOKEN')}"
}

maven_artifacts=[]
mod_list=[]
blacklist={}

with open('blacklist.json') as f:
    blacklist=json.load(f)

wfs_req=urllib.request.Request('https://api.github.com/repos/teaconmc/Longjing/actions/workflows?per_page=100', headers = headers)
with urllib.request.urlopen(wfs_req) as ws:
    workflows=json.load(ws)
    for workflow in workflows['workflows']:
        if workflow['path'].startswith('.github/workflows/team') and workflow['state'] == 'active':
            runs_req=urllib.request.Request(workflow['url'] + '/runs', headers = headers)
            with urllib.request.urlopen(runs_req) as rs:
                runs=json.load(rs)
                latest_run={}
                latest_run_num=0
                faulty_builds=blacklist.get(workflow['path'], [])
                for run in runs['workflow_runs']:
                    if run['status'] == 'completed' and run['conclusion'] == 'success' and run['run_number'] > latest_run_num:
                        if run['run_number'] in faulty_builds:
                            print(f"Skipping faulty builds {workflow['path']}#{run['run_number']}")
                        else:
                            latest_run=run
                            latest_run_num=run['run_number']
                if not latest_run:
                    print(f"No build selected for {workflow['path']} ({workflow['name']})")
                    continue
                cs_req=urllib.request.Request(latest_run['check_suite_url'], headers = headers)
                with urllib.request.urlopen(cs_req) as cs:
                    check_suite=json.load(cs)
                    found=False
                    crs_req=urllib.request.Request(check_suite['check_runs_url'], headers = headers)
                    with urllib.request.urlopen(crs_req) as crs:
                        check_run=json.load(crs)['check_runs'][0]
                        if check_run['conclusion'] == 'success':
                            anno_req=urllib.request.Request(check_run['output']['annotations_url'], headers = headers)
                            with urllib.request.urlopen(anno_req) as annos:
                                for anno in json.load(annos):
                                    if anno['title'] == 'Download':
                                        print(f"Using {workflow['path']} build #{latest_run_num}, maven coordinate {anno['raw_details']}")
                                        maven_artifacts.append(anno['raw_details'])
                                        found=True
                                    elif anno['title'] == 'Manual Download':
                                        print(f"Using {workflow['path']} build #{latest_run_num} with direct link")
                                        build_info=anno['raw_details'].split(' ', maxsplit=1)
                                        mod_list.append({
                                            'name': build_info[0],
                                            'file': build_info[1],
                                            'sig': build_info[1] + '.asc'
                                        })
                    if not found:
                        print(f"Did not find download link info under {workflow['path']} ({workflow['name']})#{run['run_number']}")

# TODO Merge into the loop above
for artifact in maven_artifacts:
    info=artifact.split(':')
    file_name=f"{info[1]}-{info[2]}.jar"
    url=f"https://archive.teacon.cn/2021/ci/maven/{info[0].replace('.', '/')}/{info[1]}/{info[2]}/{file_name}"
    sig_url=f"{url}.asc"
    mod_list.append({
      'name': file_name,
      'file': url,
      'sig': sig_url
    })

with open('extra.json') as f:
    for entry in json.load(f):
        mirror_link=f"https://archive.teacon.cn/2021/ci/extra/{entry['name']}"
        mod_list.append({
          'name': entry['name'],
          'file': mirror_link if entry['mirror'] else entry['file'],
          'sig': f"{mirror_link}.asc"
        })

with open('mod_list.json', 'w', encoding='utf-8') as f:
    json.dump(mod_list, ensure_ascii=False, indent=2)
