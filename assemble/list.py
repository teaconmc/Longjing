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

artifacts=[]

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
                    continue
                cs_req=urllib.request.Request(latest_run['check_suite_url'], headers = headers)
                with urllib.request.urlopen(cs_req) as cs:
                    check_suite=json.load(cs)
                    crs_req=urllib.request.Request(check_suite['check_runs_url'], headers = headers)
                    with urllib.request.urlopen(crs_req) as crs:
                        check_run=json.load(crs)['check_runs'][0]
                        if check_run['conclusion'] == 'success':
                            anno_req=urllib.request.Request(check_run['output']['annotations_url'], headers = headers)
                            with urllib.request.urlopen(anno_req) as annos:
                                for anno in json.load(annos):
                                    if anno['title'] == 'Download':
                                        print(f"Using {workflow['path']} build #{latest_run_num}, maven coordinate {anno['raw_details']}")
                                        artifacts.append(anno['raw_details'])

mod_list=[]

for artifact in artifacts:
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
        mod_list.append({
          'name': entry['name'],
          'file': f"https://archive.teacon.cn/2021/ci/extra/{entry['name']}",
          'sig': f"https://archive.teacon.cn/2021/ci/extra/{entry['name']}.asc"
        })

s3=boto3.client(
    service_name='s3',
    config=Config(s3={'addressing_style': 'virtual'}),
    endpoint_url=os.getenv('S3_ENDPOINT'),
    aws_access_key_id=os.getenv('S3_ACCESS_KEY'),
    aws_secret_access_key=os.getenv('S3_SECRET_KEY')
)

with io.BytesIO() as buf:
    wrapper=io.TextIOWrapper(buf, encoding='UTF-8')
    json.dump(mod_list, wrapper)
    wrapper.flush()
    buf.seek(0)
    try:
        s3.upload_fileobj(buf, os.getenv('S3_BUCKET_NAME'), '2021/ci/mod-list.json', {
            'CacheControl': 'no-cache',
            'ContentType': 'application/json'
        })
    except ClientError as e:
        print('Error occured while updating latest mod list.')
        print(e)
        exit(-1)
