#! /bin/bash

hist=/tmp/cd-hist
pwd=`pwd`
target="$1"

add_to_hist() 
{
    if [ ! -f $hist ]; then
        touch $hist
    fi

    path=$1
    #echo "Try to add $path to history"
    if [ -d "$path" ];then
        found=`cat $hist | grep -w -c "$path"`
        if [ $found -eq 0 ];then
            last_idx=`tail -1 $hist | awk -F: '{print $1}'`
            idx=$((last_idx+1))
            echo "$idx:$path" >> $hist
        fi
    fi
}

if [ "$target" != "" ];then
    add_to_hist `realpath $target`
    cd $target
else
    if [ ! -f $hist ]; then
        touch $hist
        echo "1:$pwd" >> $hist
    else
        cat $hist
        echo -n "Choose dir to go to: "
        read choice
        key="^$choice:"
        line=`cat $hist | grep "$key"`
        if [ "$line" != "" ]; then
            dir=`echo "$line" | awk -F: '{print $2}'`
            echo dir: $dir
            if [ -z "$dir" ];then
                echo "Wrong input, exit"
            else
                add_to_hist $pwd
                echo cd $dir
                cd $dir
            fi
        fi
    fi
fi
