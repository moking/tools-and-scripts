#! /bin/bash 

if [ "$YCSB_ROOT" == "" ];then
	YCSB_ROOT=/home/fan/cxl/ycsb/YCSB
fi
if [ "$REDIS_ROOT" == "" ];then
	REDIS_ROOT=/home/fan/cxl/redis/redis-stable
fi
YCSB_BIN=$YCSB_ROOT/bin/ycsb.sh

Error() {
echo -e "Error: $@"
}

create_redis_cluster() {
 echo start redis server with: redis-server $REDIS_ROOT/redis.conf, using memory on node $1
 numactl --membind=$1 redis-server $REDIS_ROOT/redis.conf &
}

help() {
	echo -e "Help info:"
	echo -e "  $0 workload threads num_record num_req node_id"
}

gen_workload() {
	w=$1

	echo "# workload:"
	cat $w | grep -v "^#" | grep -v "^$"
	echo recordcount=$2
	echo operationcount=$3
    echo requestdistribution=$4
    echo fieldcount=10
    echo fieldlength=100
	echo 
}

if [ `whoami` != "root" ];then
	Error "ERROR: \n Run $0 with root, exit"
	exit
fi

if [ ! -f $YCSB_BIN ] ;then
	Error "$YCSB_BIN not found"
fi

msizes='100 200 500 1000'
cpus=16
num_ins=3
recordcount=1000
operationcount=1000
threads=16

workload="workloada"
dist="zipfian"
node_id=0

if [ `echo $1 | grep -c workload` -gt 0 ];then
	workload=$1
	if [ "$2" != "" ]; then
		recordcount=$2
	fi
	if [ "$3" != "" ]; then
		operationcount=$3
	fi
	if [ "$4" != "" ]; then
		cpus=$4
		threads=$4
	fi
	if [ "$5" != "" ]; then
        dist=$5
    fi
	if [ "$6" != "" ]; then
        node_id=$6
    fi
else
    help
	exit
fi

workload_file=/tmp/$workload
output_file=/tmp/redis.txt
echo > $output_file

msizes=5000
ms=0

for node_id in 0 1 2; do
	gen_workload $YCSB_ROOT/workloads/$workload $recordcount $operationcount $dist >$workload_file
    cat $workload_file

	create_redis_cluster $node_id

    echo "*********Node $node_id: workload $workload test start*****************\n" | tee -a $output_file 
    cat $workload_file | tee -a $output_file 
    echo "\n********Before test************" | tee -a $output_file 
    numastat | tee -a $output_file
    numactl -H | tee -a $output_file

	echo "Load data"
	echo numactl --membind=$node_id $YCSB_BIN load redis -s -P $workload_file -p "redis.host=127.0.0.1" -p "redis.port=6379" -threads $threads 
	numactl --membind=$node_id $YCSB_BIN load redis -s -P $workload_file -p "redis.host=127.0.0.1" -p "redis.port=6379"  -threads $threads > /dev/null
	sleep 5


echo -e "\n*********************\n" | tee -a $output_file
	echo numactl --membind=$node_id $YCSB_BIN run redis -s -P $workload_file -p "redis.host=127.0.0.1" -p "redis.port=6379" -threads $threads
	numactl --membind=$node_id $YCSB_BIN run redis -s -P $workload_file -p "redis.host=127.0.0.1" -p "redis.port=6379" -threads $threads \
		| grep -A 50 "OVERALL" \
		| grep -v "TOTAL_GC" \
		| tee -a $output_file

    echo "\n********After test************" | tee -a $output_file 
    numastat | tee -a $output_file
    numactl -H | tee -a $output_file

    echo -e "\n*********Node $node_id test end*******************\n" | tee -a $output_file
    redis-cli -h 127.0.0.1 flushall
    redis-cli -h 127.0.0.1 cluster reset 
    pkill -9 redis-server
    rm -f /tmp/dump.rdb
    sleep 5
done

suffix=` date "+%m-%d-%H-%M"`
log_dir=/home/fan/cxl/ycsb/logs/
cat $output_file | grep numa_hit
mv $output_file $log_dir/native-redis-output-$suffix.log
