#! /bin/bash 

YCSB_ROOT=/home/fan/cxl/ycsb/YCSB
REDIS_ROOT=/home/fan/cxl/ycsb

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
	echo recordcount $2
	echo operationcount $3
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
cpus=2
num_ins=2
recordcount=1000
operationcount=1000
threads=16

workload="workloada"

if [ `echo $1 | grep -c workload` -gt 0 ];then
	workload=$1
	if [ "$2" != "" ]; then
		recordcount=$2
	fi
	if [ "$3" != "" ]; then
		operationcount=$3
	fi
else
	Error "\n   usage: $0 workload recordcount operationcount"
	exit
fi

workload_file=/tmp/$workload
output_file=/tmp/redis.txt
echo > $output_file

msizes=100

for ms in $msizes; do

	gen_workload $YCSB_ROOT/workloads/$workload $recordcount $operationcount >$workload_file

	create_redis_cluster $ms $cpus 2

	echo "load data"
	echo $YCSB_BIN load redis -s -P $workload_file -p "redis.host=172.28.0.11" -p "redis.port=6379" -p "redis.cluster=true" -threads $threads 
	$YCSB_BIN load redis -s -P $workload_file -p "redis.host=172.28.0.11" -p "redis.port=6379" -p "redis.cluster=true" -threads $threads > /dev/null
	sleep 2

	echo "OUTPUT: memory $(($ms)) node 2" | tee -a $output_file
echo "*********************" | tee -a $output_file
	echo $YCSB_BIN run redis -s -P $workload_file -p "redis.host=172.28.0.11" -p "redis.port=6379" -p "redis.cluster=true" -threads $threads
	$YCSB_BIN run redis -s -P $workload_file -p "redis.host=172.28.0.11" -p "redis.port=6379" -p "redis.cluster=true" -threads $threads \
		| grep -A 50 "OVERALL" \
		| grep -v "TOTAL_GC" \
		| tee -a $output_file
echo "*********************" | tee -a $output_file

	create_redis_cluster $(($ms*2)) $cpus 2

	echo "load data"
	echo $YCSB_BIN load redis -s -P $workload_file -p "redis.host=172.28.0.11" -p "redis.port=6379" -p "redis.cluster=true" -threads $threads 
	$YCSB_BIN load redis -s -P $workload_file -p "redis.host=172.28.0.11" -p "redis.port=6379" -p "redis.cluster=true" -threads $threads > /dev/null
	sleep 2

	echo "OUTPUT: memory $(($ms*2)) node 2" | tee -a $output_file
echo "*********************" | tee -a $output_file
	echo $YCSB_BIN run redis -s -P $workload_file -p "redis.host=172.28.0.11" -p "redis.port=6379" -p "redis.cluster=true" -threads $threads
	$YCSB_BIN run redis -s -P $workload_file -p "redis.host=172.28.0.11" -p "redis.port=6379" -p "redis.cluster=true" -threads $threads  \
		| grep -A 50 "OVERALL" \
		| grep -v "TOTAL_GC" \
		|tee -a $output_file
echo "*********************" | tee -a $output_file

	create_redis_cluster $(($ms*2)) $cpus 1

	echo "load data"
	echo $YCSB_BIN load redis -s -P $workload_file -p "redis.host=172.28.0.11" -p "redis.port=6379" -p "redis.cluster=true" -threads $threads 
	$YCSB_BIN load redis -s -P $workload_file -p "redis.host=172.28.0.11" -p "redis.port=6379" -p "redis.cluster=true" -threads $threads > /dev/null
	sleep 2

	echo "OUTPUT: memory $(($ms*2)) node 1" | tee -a $output_file
echo "*********************" | tee -a $output_file
	echo $YCSB_BIN run redis -s -P $workload_file -p "redis.host=172.28.0.11" -p "redis.port=6379" -p "redis.cluster=true" -threads $threads
	$YCSB_BIN run redis -s -P $workload_file -p "redis.host=172.28.0.11" -p "redis.port=6379" -p "redis.cluster=true" -threads $threads  \
		| grep -A 50 "OVERALL" \
		| grep -v "TOTAL_GC" \
		| tee -a $output_file
echo "*********************" | tee -a $output_file


done
