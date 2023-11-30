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

logger=logging.getLogger()
logger.setLevel(logging.DEBUG)

parser = argparse.ArgumentParser(description='A tool helping pull patches')
parser.add_argument('-d','--dir', help='code directory', required=False)
parser.add_argument('-k','--key', help='keyword to search', required=True)

parser.set_defaults(git=True)
parser.set_defaults(ignore_case=False)
parser.set_defaults(save_path=False)

args = vars(parser.parse_args())

dire=sh_cmd("pwd")

git=args["git"]
ignore_case=args["ignore_case"]
key=args["key"]
save_path=args["save_path"]


if args['dir']:
    dire=args['dir']
else:
    if not args['base']:
        base = "q"
    else:
        base = args['base'];

    if  base not in ['k', 'q']:
        print("invalid base type", base)
        print("valid base:  k (kernel) or q (qemu)");
        exit(1);

    if base == "k":
        if not KERNEL_ROOT:
            if LAST_ROOT:
                dire=LAST_ROOT
            KERNEL_ROOT=sh_cmd("pwd")
        dire = KERNEL_ROOT

    if base == "q":
        if not QEMU_ROOT:
            if LAST_ROOT:
                dire=LAST_ROOT
            QEMU_ROOT=sh_cmd("pwd")
        dire = QEMU_ROOT

print(dire)

if ignore_case:
    cmd="grep -rw \"%s\" %s"%(key, dire) 
else:
    cmd="grep -rwi \"%s\" %s"%(key, dire) 

if git:
    cmd="git "+cmd
    cur=sh_cmd("pwd")
    print(cmd)
    rs=sh_cmd("cd %s; %s"%(dire,cmd))
    print(rs)
    sh_cmd("cd %s"%cur)
else:
    print(cmd)
    rs=sh_cmd(cmd)
    print(rs)

if save_path: 
    os.environ["LAST_ROOT"]=dire
    print("set last root to: ", dire)
else:
    os.environ["LAST_ROOT"]=""



