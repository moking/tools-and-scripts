#! /bin/bash

num_args=$#
if [ $num_args -eq 0 ];then
	echo "No key word, ignore"
	return
fi


max_depth=1
tmp_r=/tmp/idx
echo > $tmp_r
key=$1
if [ $num_args -eq 1 ];then
	parent_dir=`pwd`
else
	parent_dir=$2
	if [ $num_args -eq 3 ];then
		max_depth=$3
	fi
fi

echo "Info: guess in $parent_dir"
dirs=`find $parent_dir -maxdepth $max_depth -name "*$key*"`
idx=0
for d in $dirs;do
	echo $idx: $d | tee -a $tmp_r
	idx=$(($idx+1))
done
echo -n "Which item to continue: "
read id
t=`cat $tmp_r | grep -w "$id:"`
if [ "$t" == "" ];then
	echo "Warning: invalid index"
	return
fi
d=`echo $t | awk -F: '{print $2}'`
if [ -d $d ];then
	echo cd $d
	cd $d
elif [ -f $d ]; then
	echo -n "Ask: do you want to open $d with vim (y/Y/n/N):"
	read an
	if [ "$an" == "Y" -o "$an" == 'y' ];then
		vim $d
	fi
fi

