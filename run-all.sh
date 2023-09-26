count=20000000
threads=16

for w in 'workloada' 'workloadb' 'workloadc'; do
    sudo bash run-ycsb.sh $w $count $count $threads uniform
    sleep 5
done
