#!/usr/bin/env python3
import requests
import os
from bs4 import BeautifulSoup
import subprocess
import re
import logging

import argparse

logger=logging.getLogger()
logger.setLevel(logging.DEBUG)


parser = argparse.ArgumentParser(description='A tool helping pull patches')
parser.add_argument('-U','--url', help='url to pull', required=False)
parser.add_argument('-N','--num', help='number of records to pull', required=False)
parser.add_argument('-O','--dir', help='directory to store pathes', required=False)
parser.add_argument('-K','--key', help='sender key to search', required=False)
parser.add_argument('-C','--cpt', help='kernel component for url (like cxl, mm)', required=False)

args = vars(parser.parse_args())

if args['url']:
    url = args['url']
else:
    if args["cpt"]:
        url = 'https://lore.kernel.org/linux-%s/'%args['cpt']
    else:
        url = 'https://lore.kernel.org/linux-cxl/'

if args['num']:
    num_record = int(args['num'])
else:
    num_record=5

key = ""
if args['key']:
    key = args['key']

path="/tmp/patches"
if args['dir']:
    path = args['dir']

log_file='/tmp/patch-pull.log'
if os.path.exists(log_file):
    os.system('mv %s %s'%(log_file, log_file+".bak"))
fh=logging.FileHandler(log_file)
fh.setLevel(logging.DEBUG)
logger.addHandler(fh)

response = requests.get(url)
soup = BeautifulSoup(response.text, 'html.parser')

def process_pre(pre):
    patches = []
    last = None
    for e in pre:
        if e.name == "a":
            last = e
        elif isinstance(e, str) and e.strip():
            if "messages" in e.strip():
                patches += [last]
        elif e.name == "pre":
            patches += process_pre(e)
    return patches

last = None
patches = []
for element in soup.body.descendants:
    if element.name == "pre":
        continue
        patches += process_pre(element)
        print(len(patches))
    elif element.name == "a":
        last = element
    elif isinstance(element, str) and element.strip():
        if "messages" in element.strip():
            patches += [last]

for p in patches:
    print(p.text,":", p.get("href"))
print("Total %d patch series found"%len(patches))

if os.path.isdir(path):
    print("Directory %s exists, skip creating\n"%path)
else:
    print("Creating directory: %s\n"%path)
    cmd = "mkdir -p %s"%path
    os.system(cmd)

cnt=0
i=0
#print("len of urls: %s"%len(urls))

print("### Pulling patches ... ###\n")
while cnt < num_record:
    url=patches[i].get("href")
    title=patches[i].text
    if not title or not url:
        print("warning: titles[%s] is empty, skip..."%i)
        i += 1
        continue;
    url=url.split("/")
    info="%d: %s ==> %s"%(cnt, title, url[0])
    logger.info(info)
    cmd = "b4 mbox %s -o %s"%(url[0],path)
    print(cmd)
    os.system(cmd)

    cnt=cnt+1
    i=i+1
print("### Pulling patches completed ###\n")

print("check patches in %s\n"%path)
print("Check pull log at %s:\n"%log_file)
if key:
    cmd='cat %s | grep "==>" | grep -i %s'%(log_file, key)
else:
    cmd='cat %s | grep "==>"'%log_file
os.system(cmd)
print("")
print("check patches in %s/\n"%path)
