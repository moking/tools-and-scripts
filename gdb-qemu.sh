pid=`ps -ef | grep qemu-system | awk '{print $2}'`
echo pid: $pid
gdb -p $pid
