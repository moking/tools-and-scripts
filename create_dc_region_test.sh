region=$(cat /sys/bus/cxl/devices/decoder0.0/create_dc_region)
echo $region> /sys/bus/cxl/devices/decoder0.0/create_dc_region
echo 256 > /sys/bus/cxl/devices/$region/interleave_granularity
echo 1 > /sys/bus/cxl/devices/$region/interleave_ways

echo "dc" >/sys/bus/cxl/devices/decoder2.0/mode
echo 0x30000000 >/sys/bus/cxl/devices/decoder2.0/dpa_size

echo 0x30000000 > /sys/bus/cxl/devices/$region/size
echo  "decoder2.0" > /sys/bus/cxl/devices/$region/target0
echo 1 > /sys/bus/cxl/devices/$region/commit
echo $region > /sys/bus/cxl/drivers/cxl_region/bind
#echo $region> /sys/bus/cxl/devices/decoder0.0/delete_region
