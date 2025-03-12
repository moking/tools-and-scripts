#!/usr/bin/env python3

import os
import sys
import subprocess
import argparse

jumper="nifan@149.97.161.244:9004"
hosts=["fan@deb-101020-bm01.dtc.local", "fan@smc-140338-bm01.dtc.local"]

def sh_cmd(cmd, echo = False):
    print(cmd)
    subprocess.run(cmd, shell = True)


def main():
    parser = argparse.ArgumentParser(description='A tool help open remote sever from a list')
    parser.add_argument('-J','--jumper', help='jumper host', required=False, default="%s"%jumper)
    parser.add_argument('-T','--target', help='target host', required=False, default="")
    #parser.add_argument('-S','--screen', help='Login with screen', action='store_true')

    for i, host in enumerate(hosts):
        print(i, host)
    choice = input("Choose a host to connect (0):")
    if not choice or not choice.isdigit() or int(choice) >= len(hosts):
        print("Warning: invliad host id, use 0 by default")
        choice = 0
    host = hosts[int(choice)]
    args = vars(parser.parse_args())
    if args["target"]:
        host = args["target"];
    jumper_host = args["jumper"]

    cmd = "clear"
    sh_cmd(cmd, echo = True)
    cmd = "ssh -J %s %s screen -ls"%(jumper_host, host)
    sh_cmd(cmd, echo = True)

    cmd = "ssh -J %s %s"%(jumper_host, host)
    sh_cmd(cmd, echo = True)

if __name__ == "__main__":
    main()

