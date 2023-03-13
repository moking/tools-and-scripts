#! /bin/bash
sub=/tmp/patch_subject
dir=`pwd`
first_only=0
description_only=0

# Loop through all arguments
for arg in "$@"; do
  # Do something with each argument
	if [ "$arg" == "-f" ];then
		first_only=1
	elif [ "$arg" == "-de" ];then
		description_only=1
	elif [[ $arg =~ ^- ]];then
		echo "$0: unsupported option $arg"
		exit
	else
		dir=$arg
	fi
done

grep -r  "^Subject:" $dir | grep -v "Re:"|grep -v "RE:" | tee $sub
if [ $first_only -eq 1 ]; then
	echo 
	echo "Info: check the first patch in the a patch series"
	cat $sub | grep " 0/" |tee $sub.first
else
	cp $sub $sub.first
fi

if [ $description_only -eq 1 ]; then
	echo
	echo "Info: return only the description on the subject"
	cat $sub.first | awk -F "]" '{print $NF}'
fi
