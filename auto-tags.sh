#!/bin/bash
dir=`pwd`

if [ "$1" != "" ];then
    dir=$1
fi
ctags -R --sort=1 --c++-kinds=+p --fields=+iaS --extra=+q --language-force=C++ $dir

ls $dir/tags -lth


