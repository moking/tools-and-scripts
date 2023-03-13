echo "file drivers/cxl/* +p" > /sys/kernel/debug/dynamic_debug/control
#echo "file drivers/acpi/* +p" >> /sys/kernel/debug/dynamic_debug/control
dmesg -C
if [ "$1" == "-c" ];then
 rmmod cxl_acpi cxl_pci cxl_port cxl_mem cxl_pmem cxl_core
 if [ `lsmod | grep -c cxl` -gt 0 ];then
	 rmmod cxl_acpi cxl_pci cxl_port cxl_mem cxl_pmem cxl_core
 fi
 lsmod
else
 modprobe -a cxl_acpi cxl_core cxl_pci cxl_port cxl_mem
fi
