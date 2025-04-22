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



parser = argparse.ArgumentParser(description='A tool helping pull patches')
parser.add_argument('-U','--url', help='url to pull', required=False)
parser.add_argument('-N','--num', help='number of records to pull', required=False)
parser.add_argument('-O','--dir', help='directory to store pathes', required=False)
parser.add_argument('-K','--key', help='sender key to search', required=False)
parser.add_argument('-C','--cpt', help='kernel component for url (like cxl, mm)', required=False)
parser.add_argument('-d','--date', help='date period', required=False)

args = vars(parser.parse_args())

cpt="cxl"

if args['url']:
    url = args['url']
else:
    if args["cpt"]:
        url = 'https://lore.kernel.org/linux-%s/'%args['cpt']
        cpt = args['cpt']
    else:
        url = 'https://lore.kernel.org/linux-cxl/'

limit=""
if args['date']:
    date = args['date']
    limit = "rt:%s.days.ago.."%date
else:
    date = 7
    limit = "rt:%s.days.ago.."%date

cmd = "lei q -I %s %s -r -t -f mboxrd > /tmp/%s.mbox"%(url, limit, cpt)

sh_cmd(cmd, echo=True)

print("\nNow check the mbox with: ")
print(" mutt-f /tmp/%s.mbox"%(cpt))
