#!/usr/bin/env python3
import requests
import os
from bs4 import BeautifulSoup
import subprocess
import re

import argparse

parser = argparse.ArgumentParser(description='A tool helping pull patches')
parser.add_argument('-u','--url', help='url to pull', required=False)
parser.add_argument('-n','--num', help='number of records to pull', required=False)
parser.add_argument('-d','--dir', help='directory to store pathes', required=False)

args = vars(parser.parse_args())

if args['url']:
    url = args['url']
else:
    url = 'https://lore.kernel.org/linux-cxl/'

if args['num']:
    num_record = int(args['num'])
else:
    num_record=5

path="/tmp/patches"
if args['dir']:
    path = args['dir']

response = requests.get(url)
soup = BeautifulSoup(response.text, 'html.parser')

# Extracting all the <a> tags into a list.
tags = soup.find_all('a')
# Extracting URLs from the attribute href in the <a> tags.
urls = [tag['href'] for tag in tags if "@" in tag['href'] ]
titles = [tag.string for tag in tags if "@" in tag['href'] ]

if os.path.isdir(path):
    print("Directory %s exists, skip creating"%path)
else:
    print("Creating directory: %s"%path)
    cmd = "mkdir -p %s"%path
    os.system(cmd)

cnt=0
i=0
while cnt < num_record:
    url=urls[i]
    title=titles[i]
    result = re.search('\[(.*?)\]', title)
    if result is None:
        print(title)
        cnt=cnt+1
        i=i+1
        continue
    patch = result.group(1)
    try:
        idx = int(patch.split()[-1].split("/")[0])
    except ValueError:
        idx=0
    if '/' in patch and idx > 0:
        #print("skip: %s"%titles[i]);
        i+=1;
        continue;

    url=url.split("/")
    print("Pulling messages:\n"+
          "\tid: %s\n\t%s"%(url[0], titles[i]))
    cmd = "b4 mbox %s -o %s"%(url[0],path)
    print(cmd)
    os.system(cmd)
    print("***")

    cnt=cnt+1
    i=i+1

print("Info: check patches in %s"%path)
