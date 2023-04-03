#! /bin/bash

if [ "$1" == "" ];then
	tmp=`pwd`
	cd $LAST_LOC
	LAST_LOC=$tmp
else
	LAST_LOC=`pwd`
	cd $1
fi
