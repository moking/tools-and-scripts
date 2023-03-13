NDCTL=/home/fan/code/ndctl/
echo "file drivers/cxl/* +p" > /sys/kernel/debug/dynamic_debug/control
dmesg -C
way=1

modprobe -a cxl_acpi cxl_core cxl_pci cxl_port cxl_mem
sleep 2

if [ "$1" == "2" ]; then
echo /home/fan/code/ndctl/build/cxl/cxl create-region -m -d decoder0.0 -w 2 -s 512M mem0 $2
$NDCTL/build/cxl/cxl create-region -m -d decoder0.0 -w 2 -s 512M mem0 $2
else
echo /home/fan/code/ndctl/build/cxl/cxl create-region -m -d decoder0.0 -w 1 mem0 -s 512M
$NDCTL/build/cxl/cxl create-region -m -d decoder0.0 -w 1 mem0 -s 256M
fi

sleep 2
modprobe -a dax_pmem device_dax

echo $NDCTL/build/ndctl/ndctl create-namespace -m dax -r region0
$NDCTL/build/ndctl/ndctl create-namespace -m dax -r region0

sleep 2

echo $NDCTL/build/daxctl/daxctl reconfigure-device --mode=system-ram --no-online dax0.0
$NDCTL/build/daxctl/daxctl reconfigure-device --mode=system-ram --no-online dax0.0
sleep 2

echo $NDCTL/build/daxctl/daxctl online-memory dax0.0
$NDCTL/build/daxctl/daxctl online-memory dax0.0

sleep 2
