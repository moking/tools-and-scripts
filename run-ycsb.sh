#! /bin/bash 

if [ "$YCSB_ROOT" == "" ];then
	YCSB_ROOT=/home/fan/cxl/ycsb/YCSB
fi
if [ "$REDIS_ROOT" == "" ];then
	REDIS_ROOT=/home/fan/cxl/ycsb
fi
YCSB_BIN=$YCSB_ROOT/bin/ycsb.sh
redis_sh=$REDIS_ROOT/create-redis-cluster.sh

Error() {
echo -e "Error: $@"
}

create_redis_cluster() {
 echo bash $redis_sh $@
 bash $redis_sh $@
}

help() {
	echo -e "Help info:"
	echo -e "  $0 memsize_M num_cpus num_docker_ins [rm]"
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

if [ ! -f $redis_sh ] ;then
	Error "$redis_sh not found"
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
	Error "\n   usage: $0 workload recordcount operationcount distribution"
	exit
fi

workload_file=/tmp/$workload
output_file=/tmp/redis.txt
echo > $output_file

msizes=5000
ms=0

for node_id in 0 1 2; do

	gen_workload $YCSB_ROOT/workloads/$workload $recordcount $operationcount $dist >$workload_file
    echo "workload: "
    cat $workload_file

	create_redis_cluster $ms $cpus $num_ins $node_id

	echo "load data"
	echo $YCSB_BIN load redis -s -P $workload_file -p "redis.host=172.28.0.11" -p "redis.port=6379" -p "redis.cluster=true" -threads $threads 
	numactl --membind=$node_id $YCSB_BIN load redis -s -P $workload_file -p "redis.host=172.28.0.11" -p "redis.port=6379" -p "redis.cluster=true" -threads $threads > /dev/null
	sleep 2

    echo "*********Node $node_id test start*****************" | tee -a $output_file 
    echo "workload: $workload" | tee -a $output_file
    cat $workload_file | tee -a $output_file 
    echo "********Before test************" | tee -a $output_file 
    i=1
    while [ $i -le $num_ins ];do 
        docker exec -it redis-$i redis-cli info | grep human | tee -a $output_file
        i=$(($i+1))
        echo | tee -a $output_file
    done
    numastat | tee -a $output_file

	echo "OUTPUT: memory $(($ms)) node $num_ins" | tee -a $output_file
echo "*********************" | tee -a $output_file
	echo $YCSB_BIN run redis -s -P $workload_file -p "redis.host=172.28.0.11" -p "redis.port=6379" -p "redis.cluster=true" -threads $threads
	numactl --membind=$node_id $YCSB_BIN run redis -s -P $workload_file -p "redis.host=172.28.0.11" -p "redis.port=6379" -p "redis.cluster=true" -threads $threads \
		| grep -A 50 "OVERALL" \
		| grep -v "TOTAL_GC" \
		| tee -a $output_file

    echo "********After test************" | tee -a $output_file 
    i=1
    while [ $i -le $num_ins ];do 
        docker exec -it redis-$i redis-cli info | grep human | tee -a $output_file
        i=$(($i+1))
        echo | tee -a $output_file
    done
    numastat | tee -a $output_file

    echo "\n*********Node $node_id test end*******************\n" | tee -a $output_file
done

suffix=` date "+%m-%d-%H-%M"`
log_dir=/home/fan/cxl/ycsb/logs/
cat output_file | grep numa_hit
mv $output_file $log_dir/redis-output-$suffix.log
