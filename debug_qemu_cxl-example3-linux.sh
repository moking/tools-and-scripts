QEMU=${1}
KERNEL_PATH=${2}
QEMU_IMG=${3}

QEMU=/root/CXL/qemu/build/qemu-system-x86_64
KERNEL_PATH=/root/CXL/linux/arch/x86/boot/bzImage
QEMU_IMG=qemu-image.qcow2

enable_kvm="-enable-kvm -cpu host"
enable_kvm=""

KERNEL_CMD="root=/dev/sda rw console=tty0 console=ttyS0,115200 ignore_loglevel nokaslr"
#SHARED_CFG="-net nic -net user,smb=/home/fan/qemu/shared_dir -net nic,model=virtio"

${QEMU} -s \
	-kernel ${KERNEL_PATH} \
	-append "${KERNEL_CMD}" \
	-smp 16 \
	${enable_kvm} \
	${SHARED_CFG}\
	-netdev "user,id=network0,hostfwd=tcp::2024-:22" \
	-drive file=${QEMU_IMG},index=0,media=disk,format=qcow2 \
	-device "e1000,netdev=network0" \
	-machine q35,cxl=on -m 8G,maxmem=32G,slots=8\
	-serial stdio \
	-display none \
	-virtfs local,path=/lib/modules,mount_tag=modshare,security_model=mapped \
	-virtfs local,path=/home/fan,mount_tag=homeshare,security_model=mapped \
	-virtfs local,path=/root/Mail,mount_tag=mailshare,security_model=mapped \
	-object memory-backend-file,id=cxl-mem0,share=on,mem-path=/tmp/cxltest.raw,size=256M \
	-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest1.raw,size=256M \
	-object memory-backend-file,id=cxl-mem2,share=on,mem-path=/tmp/cxltest2.raw,size=256M \
	-object memory-backend-file,id=cxl-mem3,share=on,mem-path=/tmp/cxltest3.raw,size=256M \
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
	-M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=4k


#-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest.raw,size=256M \
	#-object memory-backend-file,id=cxl-mem2,share=on,mem-path=/tmp/cxltest2.raw,size=256M \
	#-object memory-backend-file,id=cxl-mem3,share=on,mem-path=/tmp/cxltest3.raw,size=256M \
	#-object memory-backend-file,id=cxl-mem4,share=on,mem-path=/tmp/cxltest4.raw,size=256M \
	#-object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa.raw,size=256M \
	#-object memory-backend-file,id=cxl-lsa2,share=on,mem-path=/tmp/lsa2.raw,size=256M \
	#-object memory-backend-file,id=cxl-lsa3,share=on,mem-path=/tmp/lsa3.raw,size=256M \
	#-object memory-backend-file,id=cxl-lsa4,share=on,mem-path=/tmp/lsa4.raw,size=256M \
	#-device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
	#-device pxb-cxl,bus_nr=222,bus=pcie.0,id=cxl.2 \
	#-device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=2 \
	#-device cxl-type3,bus=root_port13,memdev=cxl-mem1,lsa=cxl-lsa1,id=cxl-pmem0 \
	#-device cxl-rp,port=1,bus=cxl.1,id=root_port14,chassis=0,slot=3 \
	#-device cxl-type3,bus=root_port14,memdev=cxl-mem2,lsa=cxl-lsa2,id=cxl-pmem1 \
	#-device cxl-rp,port=0,bus=cxl.2,id=root_port15,chassis=0,slot=5 \
	#-device cxl-type3,bus=root_port15,memdev=cxl-mem3,lsa=cxl-lsa3,id=cxl-pmem2 \
	#-device cxl-rp,port=1,bus=cxl.2,id=root_port16,chassis=0,slot=6 \
	#-device cxl-type3,bus=root_port16,memdev=cxl-mem4,lsa=cxl-lsa4,id=cxl-pmem3 \
	#-M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.targets.1=cxl.2,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=8k

	#-M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G,cxl-fmw.1.targets.0=cxl.2,cxl-fmw.1.size=4G,cxl-fmw.2.targets.0=cxl.1,cxl-fmw.2.targets.1=cxl.2,cxl-fmw.2.size=4G,cxl-fmw.2.interleave-granularity=8k 

	#-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest.raw,size=256M \
	#-object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa.raw,size=256M \
	#-device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
	#-device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=2 \
	#-device cxl-type3,bus=root_port13,memdev=cxl-mem1,lsa=cxl-lsa1,id=cxl-pmem0 \
	#-M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G
