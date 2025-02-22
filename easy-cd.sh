#! /bin/bash

hist=/tmp/cd-hist
pwd=`pwd`
target="$1"

create_hist()
{
    hist=$1
    touch $hist
    echo "1:`realpath ~/cxl/linux-fixes`" >> $hist
    echo "2:`realpath ~/cxl/cxl-test-tool`" >> $hist
    echo "3:`realpath ~/cxl/qemu`" >> $hist
    echo "4:`realpath ~/cxl/jic/qemu`" >> $hist
}


add_to_hist() 
{
    if [ ! -f $hist ]; then
        create_hist $hist
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
        add_to_hist $pwd
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
