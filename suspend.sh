#! /bin/bash

modprobe -r iwlmvm
file=/sys/bus/pci/devices/0000\:2d\:00.0/remove
if [ -f $file ]; then
    echo 1 > $file
else
    echo $file not exist
fi

