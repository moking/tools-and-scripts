QEMU=${1}
KERNEL_PATH=${2}
QEMU_IMG=${3}

QEMU=/root/CXL/qemu/build/qemu-system-x86_64
KERNEL_PATH=/root/CXL/linux/arch/x86/boot/bzImage
KERNEL_PATH=/home/fan/kernel-fixes/arch/x86/boot/bzImage
QEMU_IMG=qemu-image.qcow2
QEMU_IMG=qemu-image-latest.qcow2


KERNEL_CMD="root=/dev/sda rw console=tty0 console=ttyS0,115200 nokaslr ignore_loglevel efi=nosoftreserve"

${QEMU} \
-kernel ${KERNEL_PATH} \
--append "${KERNEL_CMD}" \
 -smp 4 \
 -enable-kvm \
 -netdev "user,id=network0,hostfwd=tcp::2022-:22" \
-drive file=${QEMU_IMG},index=0,media=disk,format=qcow2 \
--device "e1000,netdev=network0" \
-machine q35,cxl=on -m 4g,maxmem=128G,slots=8 \
-fsdev "local,security_model=passthrough,id=fsdev0,path=/lib/modules" \
-device "virtio-9p-pci,id=fs0,fsdev=fsdev0,mount_tag=modshare" \
-fsdev "local,security_model=passthrough,id=fsdev1,path=/home/fan" \
-device "virtio-9p-pci,id=fs1,fsdev=fsdev1,mount_tag=homeshare" \
-fsdev "local,security_model=passthrough,id=fsdev2,path=/usr/local/lib" \
-device "virtio-9p-pci,id=fs2,fsdev=fsdev2,mount_tag=local_libshare" \
-object memory-backend-file,id=cxl-mem0,share=on,mem-path=/tmp/cxltest.raw,size=2G \
	-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest1.raw,size=2G \
	-object memory-backend-file,id=cxl-mem2,share=on,mem-path=/tmp/cxltest2.raw,size=2G \
	-object memory-backend-file,id=cxl-mem3,share=on,mem-path=/tmp/cxltest3.raw,size=2G \
	-object memory-backend-file,id=cxl-lsa0,share=on,mem-path=/tmp/lsa0.raw,size=256M \
	-object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa1.raw,size=256M \
	-object memory-backend-file,id=cxl-lsa2,share=on,mem-path=/tmp/lsa2.raw,size=256M \
	-object memory-backend-file,id=cxl-lsa3,share=on,mem-path=/tmp/lsa3.raw,size=256M \
	-device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
	-device cxl-rp,port=0,bus=cxl.1,id=root_port0,chassis=0,slot=0 \
	-device cxl-rp,port=1,bus=cxl.1,id=root_port1,chassis=0,slot=1 \
	-device cxl-upstream,bus=root_port0,id=us0 \
	-device cxl-downstream,port=0,bus=us0,id=swport0,chassis=0,slot=4 \
	-device cxl-type3,bus=swport0,memdev=cxl-mem0,lsa=cxl-lsa0,id=cxl-pmem0 \
	-device cxl-downstream,port=1,bus=us0,id=swport1,chassis=0,slot=5 \
	-device cxl-type3,bus=swport1,memdev=cxl-mem1,lsa=cxl-lsa1,id=cxl-pmem1 \
	-device cxl-downstream,port=2,bus=us0,id=swport2,chassis=0,slot=6 \
	-device cxl-type3,bus=swport2,memdev=cxl-mem2,lsa=cxl-lsa2,id=cxl-pmem2 \
	-device cxl-downstream,port=3,bus=us0,id=swport3,chassis=0,slot=7 \
	-device cxl-type3,bus=swport3,memdev=cxl-mem3,lsa=cxl-lsa3,id=cxl-pmem3 \
	-M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=4k \
-serial stdio -display none 
#-monitor telnet:127.0.0.1:55555,server,nowait \

#--trace "cxl_type3_*" \
#--cpu host,pmu=true 
