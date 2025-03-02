#! /bin/bash

hist=/tmp/cd-hist
pwd=`pwd`
target="$1"

create_hist()
{
    hist=$1
    touch $hist
    i=0
    for dir in ~/cxl ~/git; do
        items=`find $dir -maxdepth 1 -type d`
        for item in $items; do
            echo $i:$item >> $hist
            i=$(($i+1))
        done
    done
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
    fi
    cat $hist
    echo -n "Choose dir to go to: "
    read choice
    key="^$choice:"
    line=`cat $hist | grep "$key"`
    if [ "$line" != "" ]; then
        dir=`echo "$line" | awk -F: '{print $2}'`
        if [ -z "$dir" ];then
            echo "Wrong input, exit"
        else
            add_to_hist $pwd
            echo cd $dir
            cd $dir
        fi
    fi
fi
