#! /bin/bash
rhost='nifan@192.168.64.153'
rhost='nifan@bgt140507bm02.dtc.local'

if [ "$#" -lt 2 ];then
	echo not enough parameters, exit
	echo Usage: $0 [-f/-t] dir1 dir2
	echo -e "\t -f: copy from rhost to local"
	echo -e "\t -t: copy from local to rhost (by default)"
	exit
fi
if [ "$1" == "-f" ];then
	if [ "$#" -lt 3 ];then
		echo not enough parameters, exit
		exit
	fi
	echo scp -r -J nifan@142.215.161.46:9002 $rhost:$2 $3
	scp -r -J nifan@142.215.161.46:9002 $rhost:$2 $3
elif [ "$1" == "-t" ];then
	if [ "$#" -lt 3 ];then
		echo not enough parameters, exit
		exit
	fi
	echo scp -r -J nifan@142.215.161.46:9002 $2 $rhost:$3
	scp -r -J nifan@142.215.161.46:9002 $2 $rhost:$3
else
	echo scp -r -J nifan@142.215.161.46:9002 $1 $rhost:$2
	scp -r -J nifan@142.215.161.46:9002 $1 $rhost:$2
fi
