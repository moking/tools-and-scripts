#!/usr/bin/env python3
import os
import re
import argparse
import subprocess;

def sh_cmd(cmd, echo=False):
    if echo:
        print(cmd)
    output = subprocess.getoutput(cmd)
    #print(cmd, " cmd out:", output)
    if echo:
        print(output)
    return output

def exec_shell_direct(cmd, echo=False):
    if echo:
        print(cmd)
    subprocess.run(cmd, shell=True)

parser = argparse.ArgumentParser(description='A tool helping pull patches')
parser.add_argument('--url', help='url to pull', required=False)
parser.add_argument('-N','--num', help='number of records to pull', required=False)
parser.add_argument('-O','--dir', help='directory to store pathes', required=False)
parser.add_argument('-K','--key', help='sender key to search', required=False)
parser.add_argument('-C','--cpt', help='kernel component for url (like cxl, mm)', required=False)
parser.add_argument('-d','--date', help='date period', required=False)
parser.add_argument('-U','--update', help='Update only', action='store_true')

args = vars(parser.parse_args())

cpt="cxl"

url=""
if args['url']:
    url = args['url']
else:
    if args["cpt"]:
        cpt = args['cpt']
    url = 'https://lore.kernel.org/linux-%s/'%cpt

limit=""
if args['date']:
    date = args['date']
    limit = "rt:%s.days.ago.."%date
else:
    date = 7
    limit = "rt:%s.days.ago.."%date

# cmd = "lei q --no-local --no-import-remote -I %s %s -r -t -f mboxrd > /tmp/%s.mbox"%(url, limit, cpt)
# https://josefbacik.github.io/kernel/2021/10/18/lei-and-b4.html

path="/tmp/mail/%s"%cpt

if args['update']:
    cmd = "lei up %s --no-local"%path
else:
    cmd = "lei q -o %s -I https://lore.kernel.org/linux-%s -t %s --no-local"%(path,cpt, limit)

sh_cmd(cmd, echo=True)

print("\nNow check the mbox with: ")
print(" mutt-f %s"%path)

choice = 'N'
try:
    choice = input("Want to check the mbox right now? (y/N):")
except EOFError:
    choice = 'N'

if choice.lower() == "y":
    exec_shell_direct("mutt -R -f %s"%(path))


