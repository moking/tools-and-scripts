#! /bin/bash
#
if [ "$1" == "" ];then
	echo "no input file given"
	exit
fi

bin="pandoc"
which $bin
rs=`echo $?`
if [ $rs -ne 0 ];then
	echo $bin not found
	exit
fi

src=$1
dir=`dirname $src`
target_name=`basename $src`
target_name=`echo $target_name | sed 's/.tex/.html/'`

echo $bin -f latex -t HTML -s -o $dir/$target_name $src
$bin -f latex -t HTML -s -o $dir/$target_name $src

