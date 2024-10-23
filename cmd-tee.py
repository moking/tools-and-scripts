#!/usr/bin/env python3
import requests
import os
from bs4 import BeautifulSoup
import subprocess
import re
import logging
import argparse
import subprocess

def sh_cmd(cmd, echo=False):
    if echo:
        print(cmd)
    output = subprocess.getoutput(cmd)
    if echo:
        print(output)
    return output

def exec_shell_direct(cmd, echo=False):
    if echo:
        print(cmd)
    subprocess.run(cmd, shell=True)

def write_to_file(file, s):
    file = os.path.expanduser(file)
    mode = 'a+'
    if not os.path.exists(file):
        mode='w'
    with open(file, mode) as f:
        f.write(s)

parser = argparse.ArgumentParser(description='A tool execute command and redirect output to a file')
parser.add_argument('-O','--output', help='output file', required=False, default="~/bash.output")
parser.add_argument('-C','--cmd', help='command to execute', required=False, default="")

args = vars(parser.parse_args())

file = args["output"]
cmd = args['cmd'] 
if cmd:
    write_to_file(file, cmd)
    rs = sh_cmd(cmd, echo = True)
    write_to_file(file, rs)
