#! /bin/bash

path=`pwd`

if [ "$1" != "" ];then
	path=$1
fi

for item in `find $path -name "*.mbx"`; do
	base=`basename $item`
	name=${base%.mbx*}
	dir=`dirname $item`

	#echo b4 mbox $name 2>&1 1>&/dev/null
	cur=`pwd`
	cd /tmp/
	rm -f $base
	b4 mbox $name 2>&1 1>&/dev/null
	if [ ! -f $base ];then
		cd $cur
		continue
	fi
	cd $cur
	if cmp --silent -- "$item" "/tmp/$base"; then
		#echo "thread $name is up-to-date"
		rm /tmp/$base
	else
		echo "updating $name"
		#echo mv -f /tmp/$base $item
		mv -f /tmp/$base $item
	fi
	echo
done

