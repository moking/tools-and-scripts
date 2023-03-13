#! /bin/bash
echo "cmd: $@" | tee -a /home/fan/qemu-bash.log
$@ 2>&1 | tee -a /home/fan/qemu-bash.log
echo | tee -a /home/fan/qemu-bash.log
