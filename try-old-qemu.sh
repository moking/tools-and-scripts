QEMU=${1}
KERNEL_PATH=${2}
QEMU_IMG=${3}

QEMU=/root/CXL/qemu-old/qemu/build/qemu-system-x86_64
KERNEL_PATH=/root/CXL/linux/arch/x86/boot/bzImage
KERNEL_PATH=/home/fan/kernel-fixes/arch/x86/boot/bzImage
QEMU_IMG=qemu-image.qcow2
QEMU_IMG=qemu-image-latest.qcow2

rm -f /tmp/lsa*
rm -f /tmp/cxltest*


KERNEL_CMD="root=/dev/sda rw console=tty0 console=ttyS0,115200 ignore_loglevel nokaslr"
#SHARED_CFG="-net nic -net user,smb=/home/fan/qemu/shared_dir -net nic,model=virtio"

NVME_CONFIG="-device pxb-pcie,id=pcie.1,bus_nr=99 \
			 -device ioh3420,id=rp1,bus=pcie.1 \
			 -drive file=nvm.img,if=none,id=nvm0,format=raw"


SS="-m 3072M \
-numa node,nodeid=0,memdev=m0,initiator=0 \
-numa cpu,node-id=0,socket-id=0 \
-object memory-backend-ram,size=2048M,id=m0 \
-object memory-backend-ram,id=cxl_mem,share=on,size=1024M \
-device pxb-cxl,id=cxl.0,bus=pcie.0,bus_nr=52,uid=5,len-window-base=1,window-base[0]=0x4c00000000,memdev[0]=cxl_mem \
-object memory-backend-ram,id=cxl-lsa0,share=on,size=768M \
-device cxl-rp,id=cxl_rp0,bus=cxl.0,addr=0.0,chassis=0,slot=0,port=0 \
-numa node,nodeid=1,memdev=cxl-lsa0,initiator=0 \
-object memory-backend-ram,id=cxl-lsa1,share=on,size=256M \
-device cxl-rp,id=cxl_rp1,bus=cxl.0,addr=1.0,chassis=0,slot=1,port=1 \
-numa node,nodeid=2,memdev=cxl-lsa1,initiator=0"
SS=""


#qemu monitor
#device_add cxl-type3,bus=root_port13,memdev=cxl-mem1,lsa=cxl-lsa1,id=cxl-pmem0 \

RP1="-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest.raw,size=512M \
     -object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa.raw,size=512M \
     -device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
     -device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=1 \
     -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=8k"

    # device_add cxl-type3,bus=root_port13,memdev=cxl-mem1,lsa=cxl-lsa1,id=cxl-pmem0 \
    # device_add cxl-type3,bus=root_port14,memdev=cxl-mem2,lsa=cxl-lsa2,id=cxl-pmem1 \
M2="-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest.raw,size=512M \
    -object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa.raw,size=512M \
    -object memory-backend-file,id=cxl-mem2,share=on,mem-path=/tmp/cxltest2.raw,size=512M \
    -object memory-backend-file,id=cxl-lsa2,share=on,mem-path=/tmp/lsa2.raw,size=512M \
    -device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
    -device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=2 \
    -device cxl-rp,port=1,bus=cxl.1,id=root_port14,chassis=0,slot=3 \
    -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=8k"

HB2="-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest.raw,size=256M \
     -object memory-backend-file,id=cxl-mem2,share=on,mem-path=/tmp/cxltest2.raw,size=256M \
     -object memory-backend-file,id=cxl-mem3,share=on,mem-path=/tmp/cxltest3.raw,size=256M \
     -object memory-backend-file,id=cxl-mem4,share=on,mem-path=/tmp/cxltest4.raw,size=256M \
     -object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa.raw,size=256M \
     -object memory-backend-file,id=cxl-lsa2,share=on,mem-path=/tmp/lsa2.raw,size=256M \
     -object memory-backend-file,id=cxl-lsa3,share=on,mem-path=/tmp/lsa3.raw,size=256M \
     -object memory-backend-file,id=cxl-lsa4,share=on,mem-path=/tmp/lsa4.raw,size=256M \
     -device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
     -device pxb-cxl,bus_nr=222,bus=pcie.0,id=cxl.2 \
     -device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=2 \
     -device cxl-type3,bus=root_port13,memdev=cxl-mem1,lsa=cxl-lsa1,id=cxl-pmem0 \
     -device cxl-rp,port=1,bus=cxl.1,id=root_port14,chassis=0,slot=3 \
     -device cxl-type3,bus=root_port14,memdev=cxl-mem2,lsa=cxl-lsa2,id=cxl-pmem1 \
     -device cxl-rp,port=0,bus=cxl.2,id=root_port15,chassis=0,slot=5 \
     -device cxl-type3,bus=root_port15,memdev=cxl-mem3,lsa=cxl-lsa3,id=cxl-pmem2 \
     -device cxl-rp,port=1,bus=cxl.2,id=root_port16,chassis=0,slot=6 \
     -device cxl-type3,bus=root_port16,memdev=cxl-mem4,lsa=cxl-lsa4,id=cxl-pmem3 \
     -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.targets.1=cxl.2,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=8k"


SW="-object memory-backend-file,id=cxl-mem0,share=on,mem-path=/tmp/cxltest.raw,size=256M \
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
    -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=4k"

if [ "$1" == "-h" ]; then
  echo -e "$0 [opt] \n\
    opt: \n\
      sw: with a switch \n\
      rp1: with only one root port \n\
      hb2: with two home bridges  \n\
      m2: with two memdev and 1 hb  \n\
    "
  exit
fi

CONF=$M2
if [ "$1" == "ss" ];then
  CONF=$SS
elif [ "$1" == "sw" ];then
  CONF=$SW
elif [ "$1" == "rp1" ];then
  CONF=$RP1
elif [ "$1" == "hb2" ];then
  CONF=$HB2
elif [ "$1" == "m2" ];then
  CONF=$M2
else
  CONF=""
  echo "No cxl topology given, please hot add"
  exit
fi

old_qemu=" \
-m 3072M \
-display none \
-serial stdio \
-machine type=q35,accel=kvm,nvdimm=off,cxl=on,hmat=on \
-enable-kvm -nographic -net nic -net user,hostfwd=tcp::2024-:22 \
-smp 4,sockets=1,cores=2,threads=2 \
-numa node,nodeid=0,memdev=m0,initiator=0 \
-numa cpu,node-id=0,socket-id=0 \
-object memory-backend-ram,size=2048M,id=m0 \
-object memory-backend-ram,id=cxl_mem,share=on,size=1024M \
-device pxb-cxl,id=cxl.0,bus=pcie.0,bus_nr=52,uid=5,len-window-base=1,window-base[0]=0x4c00000000,memdev[0]=cxl_mem \
-object memory-backend-ram,id=cxl-lsa0,share=on,size=768M \
-device cxl-rp,id=rp0,bus=cxl.0,addr=0.0,chassis=0,slot=0,port=0 \
-numa node,nodeid=1,memdev=cxl-lsa0,initiator=0 \
-object memory-backend-ram,id=cxl-lsa1,share=on,size=256M \
-device cxl-rp,id=rp1,bus=cxl.0,addr=1.0,chassis=0,slot=1,port=1 \
-numa node,nodeid=2,memdev=cxl-lsa1,initiator=0 \
"

#-serial stdio \
#-display none \
# -nographic \
${QEMU} -s \
	-kernel ${KERNEL_PATH} \
	-append "${KERNEL_CMD}" \
	-drive file=${QEMU_IMG},index=0,media=disk,format=qcow2 \
	-monitor telnet:127.0.0.1:12345,server,nowait \
	-virtfs local,path=/lib/modules,mount_tag=modshare,security_model=mapped \
	-virtfs local,path=/home/fan,mount_tag=homeshare,security_model=mapped \
	-virtfs local,path=/root/Mail,mount_tag=mailshare,security_model=mapped \
	${old_qemu} \
	$CONF
