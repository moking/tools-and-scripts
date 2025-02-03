#! /bin/bash
jumper='nifan@149.97.161.244:9004'
rhost='fan@deb-101020-bm01.dtc.local'
rhost='fan@smc-140338-bm01.dtc.local'


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
	echo scp -r -J $jumper $rhost:$2 $3
	scp -r -J $jumper $rhost:$2 $3
elif [ "$1" == "-t" ];then
	if [ "$#" -lt 3 ];then
		echo not enough parameters, exit
		exit
	fi
	echo scp -r -J $jumper $2 $rhost:$3
	scp -r -J $jumper $2 $rhost:$3
else
	echo scp -r -J $jumper $1 $rhost:$2
	scp -r -J $jumper $1 $rhost:$2
fi
