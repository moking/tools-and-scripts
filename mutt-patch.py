#!/usr/bin/env python3
import requests
import os
from bs4 import BeautifulSoup
import subprocess
import re
import logging
import argparse
import subprocess

def sh_cmd(cmd):
    output = subprocess.getoutput(cmd)
    return output

def open_file(editor, file):
    subprocess.call([editor,'-f',  file])
    text=open(file, 'w+').read()

logger=logging.getLogger()
logger.setLevel(logging.DEBUG)

QEMU_ROOT=os.environ["QEMU_ROOT"]
KERNEL_ROOT=os.environ["KERNEL_ROOT"]
LAST_ROOT=os.environ.get("LAST_ROOT", "")

parser = argparse.ArgumentParser(description='A tool help open patch mbox file with mutt quickly')
parser.add_argument('-d','--dir', help='patch directory', required=False, default="/tmp/patches")
parser.add_argument('-k','--key', help='keyword to search', required=False, default="")
parser.add_argument('-L','--log', help='log file to extract mbox info', required=False, default="/tmp/patch-pull.log")


args = vars(parser.parse_args())

key = args['key']
log=args["log"]
log_entries=[]
if os.path.exists(log):
    cmd_str="cat %s | grep \"==>\""%log
    rs=sh_cmd(cmd_str)
    print("Patch info:")
    print(rs)
    log_entries =rs.split("\n")
else:
    print("Warning: no log file found")
print("")
if not args["key"]:
    index=input("Choose one file to open:")
    if not index.isdigit() or int(index) >= len(log_entries):
        print("Input a number smaller than %d to choose"%len(log_entries))
        exit(1)
    key = log_entries[int(index)].split("==>")[1].strip()

dire=args['dir']
pfile = dire+"/"+key+"*"

cmd_str="find %s -name %s*"%(dire, key)
files=sh_cmd(cmd_str)

files = files.split()
if len(files) == 0:
    print("no file found")
    exit(1)

file=files[0]
if len(files) > 1:
    i=0
    for file in files:
        print(i, file)
        i = i+1
    index=input("Choose one file to open:")
    if not index.isdigit() or int(index) >= i:
        print("Input a number smaller than %d to choose"%i)
        exit(1)
    file=files[int(index)]

print("Open file %s with mutt"%file)
open_file("mutt", file)


