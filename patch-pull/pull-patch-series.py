import requests
import os
from bs4 import BeautifulSoup
import subprocess

import argparse

parser = argparse.ArgumentParser(description='Description of your program')
parser.add_argument('-u','--url', help='url to pull', required=False)
parser.add_argument('-n','--num', help='number of records to pull', required=False)

args = vars(parser.parse_args())

if args['url']:
    url = args['url']
else:
    url = 'https://lore.kernel.org/linux-cxl/'

if args['num']:
    num_record = int(args['num'])
else:
    num_record=5

response = requests.get(url)
soup = BeautifulSoup(response.text, 'html.parser')

# Extracting all the <a> tags into a list.
tags = soup.find_all('a')

# Extracting URLs from the attribute href in the <a> tags.
urls = [tag['href'] for tag in tags]

path="/tmp/patches"
cmd = "mkdir %s"%path
os.system(cmd)

cnt=0
for url in urls:
    if "@" in url:
        url=url.split("/")
        print("Pulling messages with id: %s"%url[0])
        cmd = "b4 mbox %s -o %s"%(url[0],path)
        print(cmd)
        os.system(cmd)
        print("***")

        cnt=cnt+1
        if cnt >= num_record:
            break
