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
    subprocess.run(cmd, shell=True)

def open_file(editor, file):
    subprocess.call([editor,'-f',  file])
    text=open(file, 'r').read()

parser = argparse.ArgumentParser(description='A tool help setup python venv quickly')
parser.add_argument('-D','--dir', help='directory where to compile python', required=False, default="%s/venv"%os.getenv("HOME"))
parser.add_argument('-B','--bin', help='directory where to install python', required=False, default="%s/.localpython"%os.getenv("HOME"))
parser.add_argument('-V','--version', help='python version to setup', required=True)
parser.add_argument('-R','--remove', help='remove the old install', action='store_true')

args = vars(parser.parse_args())

dire = args["dir"]
bin_dir = args['bin']
version = args['version']

def download_install():
    path = "%s/Python-%s"%(dire, version)
    print(path)
    if not os.path.exists(path):
        url = "http://python.org/ftp/python/%s/Python-%s.tgz"%(version, version)
        cmd = "cd %s; wget %s"%(dire, url)
        sh_cmd(cmd)
        cmd = "cd %s; tar -xf Python-%s.tgz"%(dire,version)
        sh_cmd(cmd)
    cmd = "cd %s/Python-%s; export CC=clang; ./configure --prefix=%s"%(dire, version, bin_dir)
    sh_cmd(cmd)
    cmd = "cd %s/Python-%s; make && make install"%(dire, version)
    sh_cmd(cmd)

if args["remove"]:
    cmd = "rm -rf %s/*"%dire
    sh_cmd(cmd)
    cmd = "rm -rf %s/*"%bin_dir
    sh_cmd(cmd)
    exit(0)

download_install()
cmd = "virtualenv -p %s/bin/python3 %s/build/"%(bin_dir, dire)
sh_cmd(cmd)
print("Now use following command to setup:")
cmd = "source %s/bin/activate"%bin_dir
print(cmd)



