QEMU=${1}
KERNEL_PATH=${2}
QEMU_IMG=${3}

QEMU=/root/CXL/qemu/build/qemu-system-x86_64
KERNEL_PATH=/root/CXL/linux/arch/x86/boot/bzImage
QEMU_IMG=qemu-image.qcow2


KERNEL_CMD="root=/dev/sda rw console=tty0 console=ttyS0,115200 nokaslr ignore_loglevel efi=nosoftreserve"
 
${QEMU} \
		-kernel ${KERNEL_PATH} \
		--append "${KERNEL_CMD}" \
		-smp 4 \
		-enable-kvm \
		-netdev "user,id=network0,hostfwd=tcp::2022-:22" \
		-drive file=${QEMU_IMG},index=0,media=disk,format=raw \
		--device "e1000,netdev=network0" \
		-machine q35,cxl=on -m 4g,maxmem=128G,slots=8 \
		-fsdev "local,security_model=passthrough,id=fsdev0,path=/lib/modules" \
		-device "virtio-9p-pci,id=fs0,fsdev=fsdev0,mount_tag=modshare" \
		-fsdev "local,security_model=passthrough,id=fsdev1,path=/home/fan" \
		-device "virtio-9p-pci,id=fs1,fsdev=fsdev1,mount_tag=homeshare" \
		-fsdev "local,security_model=passthrough,id=fsdev2,path=/usr/local/lib" \
		-device "virtio-9p-pci,id=fs2,fsdev=fsdev2,mount_tag=local_libshare" \
		-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest.raw,size=256M \
		-object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa.raw,size=256M \
		-device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
		-device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=2 \
		-device cxl-type3,bus=root_port13,memdev=cxl-mem1,lsa=cxl-lsa1,id=cxl-pmem0 \
		-M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=8k \
		-serial stdio -display none


