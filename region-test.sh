echo "file drivers/cxl/* +p" > /sys/kernel/debug/dynamic_debug/control
dmesg -C
way=1

if [ "$CXL_ROOT" == "" ];then
	CXL_ROOT=/home/fan/code/ndctl/
fi
if [ "$1" == "2" ]; then
echo $CXL_ROOT/build/cxl/cxl create-region -m -d decoder0.0 -w 2 -s 512M mem0 $2
$CXL_ROOT/build/cxl/cxl create-region -m -d decoder0.0 -w 2 -s 512M mem0 $2 --debug
else
echo $CXL_ROOT create-region -m -d decoder0.0 -w 1 mem0 -s 512M
$CXL_ROOT/build/cxl/cxl create-region -m -d decoder0.0 -w 1 mem0 -s 256M --debug
fi
