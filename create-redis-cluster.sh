num_ins=$3
rm=0
msize=$1
swap_f=5
mswap_size=$(($msize*$swap_f))
cpus=$2
node_id=$4

msize="$msize"m
mswap_size=${mswap_size}m

echo swap: $mswap_size



if [ "$4" == "rm" ];then
	rm=1
fi

for port in $(seq 1 $num_ins); do
	docker container kill redis-${port}
	rm -rf ./mydata/redis/node-$port/data/*
done
yes|docker container prune
docker network rm redis-group

if [ "$rm" == "1" ];then
	exit
fi

docker network create --driver bridge --subnet 172.28.0.0/16 redis-group

for port in $(seq 1 $num_ins); do
mkdir -p ./mydata/redis/node-${port}/conf
touch ./mydata/redis/node-${port}/conf/redis.conf

cat << EOF >./mydata/redis/node-${port}/conf/redis.conf
port 6379
bind 0.0.0.0
cluster-enabled yes
cluster-config-file nodes.conf
cluster-node-timeout 5000
cluster-announce-ip 172.28.0.1${port}
cluster-announce-port 6379
cluster-announce-bus-port 16379
appendonly no
EOF

done

port_num=6379
ports=""

echo num_ins: $num_ins

echo "Creating docker instances..."
for port in $(seq 1 $num_ins); do

echo "### docker run"
	#--memory $msize\
	#--memory-swap $mswap_size \
	#--cpus $cpus \
ports="$ports 172.28.0.1${port}:6379 "
numactl --membind=$node_id docker run --privileged -p 637${port}:6379 -p 1637${port}:16379 --name redis-${port} \
	-v `pwd`/mydata/redis/node-${port}/data:/data \
	-v `pwd`/mydata/redis/node-${port}/conf/redis.conf:/etc/redis/redis.conf \
	-d --net redis-group --ip 172.28.0.1${port} redis:latest redis-server /etc/redis/redis.conf

#echo "### Show docker stats"
#docker stats redis-$port --no-stream --format "{{ json . }}" | python3 -m json.tool
#echo "create redis-$port completed"
#echo
done

echo "Reset docker instances..."
for port in $(seq 1 $num_ins); do
sleep 2
echo "reset cluster"
docker exec --privileged -it redis-$port redis-cli flushall >/dev/null
docker exec --privileged -it redis-$port redis-cli cluster reset>/dev/null
echo "### check redis info for memory usage"
docker exec --privileged -it redis-$port redis-cli info | grep human
done

echo 
echo "Create redis cluster..."

if [ "$num_ins" -lt 3 ];then
	#echo "NOTE: We need at least 3 nodes for the cluster, you can pass the same nodes multiple times if less than 3 3 nodes are given, or create a thread node with no data by cluster meet #IP_node3#:7000"
if [ "$num_ins" -eq 2 ];then
	ports="$ports $ports"
fi
if [ "$num_ins" -eq 1 ];then
	ports="$ports $ports $ports"
fi
fi
docker exec --privileged -it redis-1 redis-cli --cluster create $ports --cluster-replicas 0 --cluster-yes > /dev/null

if [ "$?" != "0" ];then
	echo "create cluster failed, exit"
	exit
fi

sleep 5
docker ps
echo

exit

echo "Below are informational message: "
echo "*********************"
echo -e "Execute \n \
docker exec -it redis-1 /bin/bash \n \
redis-cli --cluster create $ports --cluster-replicas 0 --cluster-yes \n \
redis-cli -c \n \
"

echo "Edit workload configuration"
echo "load data"
echo /bin/ycsb.sh load redis -s -P workloads/workloada -p "redis.host=172.28.0.11" -p "redis.port=6379" -p "redis.cluster=true" -threads 1 -s

echo "run tests like below"
echo /bin/ycsb.sh run redis -s -P workloads/workloada -p "redis.host=172.28.0.11" -p "redis.port=6379" -p "redis.cluster=true" -threads 1 -s
echo "*********************"
