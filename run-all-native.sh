count=20000000
threads=16

run_log=/home/fan/cxl/ycsb/ycsb-with-native-redis-test.log
moment=`date`

echo "Test performed @ $moment " | tee -a $run_log
for w in 'workloada' 'workloadb' 'workloadc'; do
    rm -f /tmp/dump.rdb
    pkill -9 redis-server
    sleep 5
    bash run-ycsb-native.sh $w $count $count $threads uniform 2>&1 | tee -a $run_log
    sleep 5
    rm -f /tmp/dump.rdb
    pkill -9 redis-server
done
echo "Test performed @ $moment completed" | tee -a $run_log
echo -e "\n\n\n" | tee -a $run_log

