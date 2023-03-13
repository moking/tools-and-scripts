#! /bin/bash
rhost='nifan@192.168.64.153'
if [ "$#" -lt 2 ];then
	echo not enough parameters, exit
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
