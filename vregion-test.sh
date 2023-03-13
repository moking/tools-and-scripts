echo "file drivers/cxl/* +p" > /sys/kernel/debug/dynamic_debug/control
dmesg -C
way=1
CXL=/home/fan/ndctl-official/ndctl/build/cxl/cxl
CXL=/home/fan/code/ndctl/build/cxl/cxl
if [ "$1" == "2" ]; then
echo $CXL create-region -m -d decoder0.0 -w 2 -s 512M mem0 $2 -t ram
$CXL create-region -m -d decoder0.0 -w 2 -s 512M mem0 $2 -t ram
else
echo $CXL create-region -m -d decoder0.0 -w 1 mem0 -s 512M -t ram
$CXL create-region -m -d decoder0.0 -w 1 mem0 -s 512M -t ram --debug
fi
