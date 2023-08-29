#QEMU=${1}
#KERNEL_PATH=${2}
#QEMU_IMG=${3}

if [ "$QEMU_ROOT" == "" ];then
	QEMU=/root/CXL/qemu/build/qemu-system-x86_64
else
	QEMU=/$QEMU_ROOT/build/qemu-system-x86_64
fi

if [ "$KERNEL_ROOT" == "" ];then
	KERNEL_PATH=/home/fan/kernel-fixes/arch/x86/boot/bzImage
else
	KERNEL_PATH=$KERNEL_ROOT/arch/x86/boot/bzImage
fi

echo $QEMU
echo $KERNEL_PATH

QEMU_IMG=qemu-image.qcow2
if [ "$IMG_ROOT" == "" ];then
	QEMU_IMG=qemu-image-latest.qcow2
else
	QEMU_IMG=$IMG_ROOT/qemu-image-latest.qcow2
fi

rm -f /tmp/lsa*
rm -f /tmp/cxltest*


KERNEL_CMD="root=/dev/sda rw console=tty0 console=ttyS0,115200 ignore_loglevel nokaslr"
#SHARED_CFG="-net nic -net user,smb=/home/fan/qemu/shared_dir -net nic,model=virtio"


#for hotplug, execute below at qemu monitor
#device_add nvme,id=n1,bus=rp1,serial=deadbeef,drive=nvm0

NVME_CONFIG="-device pxb-pcie,id=pcie.1,bus_nr=150 \
			 -device ioh3420,id=rp1,bus=pcie.1 \
			 -drive file=nvm.img,if=none,id=nvm0,format=raw"
RP1_DCD="-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest.raw,size=512M \
	 -object memory-backend-file,id=cxl-mem2,share=on,mem-path=/tmp/cxltest2.raw,size=2048M \
	 -object memory-backend-file,id=cxl-dcd0,share=on,mem-path=/tmp/cxltest-dcd.raw,size=4096M \
     -object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa.raw,size=512M \
     -object memory-backend-file,id=cxl-lsa3,share=on,mem-path=/tmp/lsa2.raw,size=512M \
     -device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
     -device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=2 \
     -device cxl-rp,port=1,bus=cxl.1,id=root_port14,chassis=0,slot=3 \
     -device cxl-type3,bus=root_port13,memdev=cxl-mem1,lsa=cxl-lsa1,nonvolatile-dc-memdev=cxl-dcd0,volatile-memdev=cxl-mem2,id=cxl-dcd0,num-dc-regions=2\
     -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=8k"

RP1_R="-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest-dcd.raw,size=4096M \
     -object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa.raw,size=512M \
     -device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
     -device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=2 \
     -device cxl-type3,bus=root_port13,memdev=cxl-mem1,lsa=cxl-lsa1,id=cxl-dcd0,num-dc-regions=2\
     -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=8k"

RP1="-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest-dcd.raw,size=4096M \
     -object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa.raw,size=512M \
     -device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
     -device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=2 \
     -device cxl-type3,bus=root_port13,lsa=cxl-lsa1,nonvolatile-dc-memdev=cxl-mem1,id=cxl-dcd0,num-dc-regions=2\
     -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=8k"

M2="-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest.raw,size=256M \
    -object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa.raw,size=512M \
    -object memory-backend-file,id=cxl-mem2,share=on,mem-path=/tmp/cxltest2.raw,size=512M \
    -object memory-backend-file,id=cxl-lsa2,share=on,mem-path=/tmp/lsa2.raw,size=512M \
    -device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
    -device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=2 \
    -device cxl-type3,bus=root_port13,memdev=cxl-mem1,lsa=cxl-lsa1,id=cxl-pmem0 \
    -device cxl-rp,port=1,bus=cxl.1,id=root_port14,chassis=0,slot=3 \
    -device cxl-type3,bus=root_port14,memdev=cxl-mem2,lsa=cxl-lsa2,id=cxl-pmem1 \
    -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=8k"

HB2="-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest.raw,size=256M \
     -object memory-backend-file,id=cxl-mem2,share=on,mem-path=/tmp/cxltest2.raw,size=512M \
     -object memory-backend-file,id=cxl-mem3,share=on,mem-path=/tmp/cxltest3.raw,size=768M \
     -object memory-backend-file,id=cxl-mem4,share=on,mem-path=/tmp/cxltest4.raw,size=1024M \
     -object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa.raw,size=256M \
     -object memory-backend-file,id=cxl-lsa2,share=on,mem-path=/tmp/lsa2.raw,size=256M \
     -object memory-backend-file,id=cxl-lsa3,share=on,mem-path=/tmp/lsa3.raw,size=256M \
     -object memory-backend-file,id=cxl-lsa4,share=on,mem-path=/tmp/lsa4.raw,size=256M \
     -device pxb-cxl,bus_nr=123,bus=pcie.0,id=cxl.1 \
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

HB2M2="-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest.raw,size=256M \
     -object memory-backend-file,id=cxl-mem2,share=on,mem-path=/tmp/cxltest2.raw,size=512M \
     -object memory-backend-file,id=cxl-mem3,share=on,mem-path=/tmp/cxltest3.raw,size=768M \
     -object memory-backend-file,id=cxl-mem4,share=on,mem-path=/tmp/cxltest4.raw,size=1024M \
     -object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa.raw,size=256M \
     -object memory-backend-file,id=cxl-lsa2,share=on,mem-path=/tmp/lsa2.raw,size=256M \
     -object memory-backend-file,id=cxl-lsa3,share=on,mem-path=/tmp/lsa3.raw,size=256M \
     -object memory-backend-file,id=cxl-lsa4,share=on,mem-path=/tmp/lsa4.raw,size=256M \
     -device pxb-cxl,bus_nr=123,bus=pcie.0,id=cxl.1 \
     -device pxb-cxl,bus_nr=222,bus=pcie.0,id=cxl.2 \
     -device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=2 \
     -device cxl-type3,bus=root_port13,memdev=cxl-mem1,lsa=cxl-lsa1,id=cxl-pmem0 \
     -device cxl-rp,port=1,bus=cxl.1,id=root_port14,chassis=0,slot=3 \
     -device cxl-rp,port=0,bus=cxl.2,id=root_port15,chassis=0,slot=5 \
     -device cxl-type3,bus=root_port15,memdev=cxl-mem2,lsa=cxl-lsa2,id=cxl-pmem1 \
     -device cxl-rp,port=1,bus=cxl.2,id=root_port16,chassis=0,slot=6 \
     -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.targets.1=cxl.2,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=8k"


HB2S="-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest.raw,size=256M \
     -object memory-backend-file,id=cxl-mem2,share=on,mem-path=/tmp/cxltest2.raw,size=512M \
     -object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa.raw,size=256M \
     -object memory-backend-file,id=cxl-lsa2,share=on,mem-path=/tmp/lsa2.raw,size=256M \
     -device pxb-cxl,bus_nr=123,bus=pcie.0,id=cxl.1 \
     -device pxb-cxl,bus_nr=222,bus=pcie.0,id=cxl.2 \
     -device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=1 \
     -device cxl-type3,bus=root_port13,memdev=cxl-mem1,lsa=cxl-lsa1,id=cxl-pmem0 \
     -device cxl-rp,port=1,bus=cxl.2,id=root_port14,chassis=0,slot=2 \
     -device cxl-type3,bus=root_port14,memdev=cxl-mem2,lsa=cxl-lsa2,id=cxl-pmem1 \
     -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.targets.1=cxl.2,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=8k"

HB3="-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest.raw,size=256M \
     -object memory-backend-file,id=cxl-mem2,share=on,mem-path=/tmp/cxltest2.raw,size=512M \
     -object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa.raw,size=256M \
     -object memory-backend-file,id=cxl-lsa2,share=on,mem-path=/tmp/lsa2.raw,size=256M \
     -device pxb-cxl,bus_nr=123,bus=pcie.0,id=cxl.1 \
     -device pxb-cxl,bus_nr=222,bus=pcie.0,id=cxl.2 \
     -device pxb-cxl,bus_nr=129,bus=pcie.0,id=cxl.3 \
     -device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=1 \
     -device cxl-type3,bus=root_port13,memdev=cxl-mem1,lsa=cxl-lsa1,id=cxl-pmem0 \
     -device cxl-rp,port=1,bus=cxl.2,id=root_port14,chassis=0,slot=2 \
     -device cxl-type3,bus=root_port14,memdev=cxl-mem2,lsa=cxl-lsa2,id=cxl-pmem1 \
     -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.targets.1=cxl.2,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=8k"


SW="-object memory-backend-file,id=cxl-mem0,share=on,mem-path=/tmp/cxltest.raw,size=256M \
    -object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest1.raw,size=512M \
    -object memory-backend-file,id=cxl-mem2,share=on,mem-path=/tmp/cxltest2.raw,size=768M \
    -object memory-backend-file,id=cxl-mem3,share=on,mem-path=/tmp/cxltest3.raw,size=1024M \
    -object memory-backend-file,id=cxl-lsa0,share=on,mem-path=/tmp/lsa0.raw,size=256M \
    -object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa1.raw,size=512M \
    -object memory-backend-file,id=cxl-lsa2,share=on,mem-path=/tmp/lsa2.raw,size=768M \
    -object memory-backend-file,id=cxl-lsa3,share=on,mem-path=/tmp/lsa3.raw,size=1024M \
    -device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
    -device cxl-rp,port=0,bus=cxl.1,id=root_port0,chassis=0,slot=1 \
    -device cxl-rp,port=1,bus=cxl.1,id=root_port1,chassis=0,slot=2 \
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
if [ "$1" == "sw" ];then
  CONF=$SW
elif [ "$1" == "rp1" ];then
  CONF=$RP1
elif [ "$1" == "rp1r" ];then
    CONF=$RP1_R
elif [ "$1" == "rp1-dcd" ];then
  CONF=$RP1_DCD
elif [ "$1" == "hb2" ];then
  CONF=$HB2
elif [ "$1" == "hb2s" ];then
  CONF=$HB2S
elif [ "$1" == "hb3" ];then
  CONF=$HB3
elif [ "$1" == "hb2m2" ];then
  CONF=$HB2M2
elif [ "$1" == "m2" ];then
  CONF=$M2
else
  echo $1 not supported, exit
  exit
fi

if [ "$2" == "wait" ];then
	wait=""
else
	wait=",nowait"
fi

${QEMU} -s \
	-kernel ${KERNEL_PATH} \
	-append "${KERNEL_CMD}" \
	-smp 1 \
	${SHARED_CFG}\
	-netdev "user,id=network0,hostfwd=tcp::2024-:22" \
	-drive file=${QEMU_IMG},index=0,media=disk,format=qcow2 \
	-device "e1000,netdev=network0" \
	-machine q35,cxl=on -m 8G,maxmem=32G,slots=8 \
	-monitor telnet:127.0.0.1:12345,server$wait \
	-qmp tcp:localhost:4444,server,wait=off \
	-serial stdio \
	-display none \
	-virtfs local,path=/lib/modules,mount_tag=modshare,security_model=mapped \
	-virtfs local,path=/home/fan,mount_tag=homeshare,security_model=mapped \
	$CONF
