#! /bin/bash
QEMU_ROOT=/home/fan/cxl/devel/qemu
KERNEL_ROOT=/home/fan/cxl/linux-fixes/

QEMU_IMG=/tmp/qemu-image.qcow2
QEMU_IMG=/home/fan/cxl/images/qemu-image.img
#QEMU_IMG=/home/fan/cxl/libvirt/images/kdevops/vagrant_dcd-v3.img

dbg_opt="cxl_acpi.dyndbg=+fplm cxl_pci.dyndbg=+fplm cxl_core.dyndbg=+fplm cxl_mem.dyndbg=+fplm cxl_pmem.dyndbg=+fplm cxl_port.dyndbg=+fplm cxl_region.dyndbg=+fplm cxl_test.dyndbg=+fplm cxl_mock.dyndbg=+fplm cxl_mock_mem.dyndbg=+fplm dax.dyndbg=+fplm dax_cxl.dyndbg=+fplm device_dax.dyndbg=+fplm"

KERNEL_CMD="root=/dev/sda rw console=ttyS0,115200 ignore_loglevel nokaslr $dbg_opt"

top_file=/tmp/cxl-top.txt

echo "" > $top_file

echo '
rp=13
mem_id=0
slot=2
chassis=0
bus=1
bus_nr=12
fmw=0
' > /tmp/cxl-val

get_val() {
    key=$1
    val=`cat /tmp/cxl-val | grep -w "$key" | awk -F= '{print $2}'`
    echo $val
}

inc() {
    key=$1
    line=`cat /tmp/cxl-val | grep -w "$key"`
    val=`cat /tmp/cxl-val | grep -w "$key" | awk -F= '{print $2}'`
    val=$(($val+1))
    newline=$key"="$val
    sed -i "s/$line/$newline/g" /tmp/cxl-val
}

create_object() {
    name=$1
    size=$2
    path=$3
    if [ "$path" == "" -o ! -d $path ];then
        path=/tmp/
    fi

    if [ "$size" == "" ];then
        size="512M"
    fi
    echo "-object memory-backend-file,id=$name,share=on,mem-path=$path/$name.raw,size=$size " >> $top_file
    echo $name
}

create_cxl_bus() {
    bus=`get_val "bus"`
    bus_nr=`get_val "bus_nr"`
    echo "-device pxb-cxl,bus_nr=$bus_nr,bus=pcie.0,id=cxl.$bus " >> $top_file
    echo "cxl.$bus"
    inc "bus"
    inc "bus_nr"
 }

create_cxl_rp() {
    rp=`get_val "rp"`
    slot=`get_val "slot"`
    chassis=`get_val "chassis"`
    echo "-device cxl-rp,port=$rp,bus=cxl.1,id=root_port$rp,chassis=$chassis,slot=$slot " >> $top_file
    echo "root_port$rp"
    inc "rp"
    inc "slot"
}

create_cxl_mem() {
     port_name=$1
     mem_id=`get_val "mem_id"`
     mem=$(create_object "mem$mem_id")
     lsa=$(create_object "lsa$mem_id")
     echo " -device cxl-type3,bus=$port_name,memdev=$mem,lsa=$lsa,id=cxl-memdev$mem_id ">>$top_file
     echo "cxl-memdev$mem_id"
     inc "mem_id"
}

create_cxl_fmw() {
    size=$1
    bus=$2
    fmw=`get_val "fmw"`
    if [ "$size" == "" ];then
        size="4G"
    fi
    if [ "$bus" == "" ];then
        bus="cxl.1"
    fi
    ig="8k"
    echo "-M cxl-fmw.0.targets.0=$bus,cxl-fmw.$fmw.size=$size,cxl-fmw.$fmw.interleave-granularity=$ig " >> $top_file 
    echo "cx-fmw.$fmw"
    inc "fmw"
}

gen_topology_str() {
    topo_str=`cat $top_file`
    topo_str=`echo $topo_str |sed "s/\n/ /g"`
    echo $topo_str
}


bus1=`create_cxl_bus`
rp1=`create_cxl_rp`
rp2=`create_cxl_rp`
mem=$(create_cxl_mem $rp1)
mem2=$(create_cxl_mem $rp2)
fmw=$(create_cxl_fmw)

topo_str=`gen_topology_str`


RP1="-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest.raw,size=512M \
     -object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa.raw,size=512M \
     -device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
     -device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=2 \
     -device cxl-type3,bus=root_port13,memdev=cxl-mem1,lsa=cxl-lsa1,id=cxl-pmem0 \
     -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=8k"

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

M2="-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest.raw,size=512M \
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

run_qemu() {
    if [ "$1" != "" ];then
        topo="$1"
    fi
    echo "***: Start running Qemu..."

    echo "${QEMU} \
        -kernel ${KERNEL_PATH} \
        -append \"${KERNEL_CMD}\" \
        -smp $num_cpus \
        -accel $mode \
        -serial mon:stdio \
        -nographic \
        ${SHARED_CFG} \
        ${net_config} \
        -drive file=${QEMU_IMG},index=0,media=disk,format=raw \
        -machine q35,cxl=on -m 8G,maxmem=32G,slots=8 \
        -virtfs local,path=/lib/modules,mount_tag=modshare,security_model=mapped \
        -virtfs local,path=/home/fan,mount_tag=homeshare,security_model=mapped \
        $topo" > /tmp/cmd

    ${QEMU} \
        -kernel ${KERNEL_PATH} \
        -append "${KERNEL_CMD}" \
        -smp $num_cpus \
        -accel $mode \
        -serial mon:stdio \
        -nographic \
        ${SHARED_CFG} \
        ${net_config} \
        -drive file=${QEMU_IMG},index=0,media=disk,format=raw \
        -machine q35,cxl=on -m 8G,maxmem=32G,slots=8 \
        -virtfs local,path=/lib/modules,mount_tag=modshare,security_model=mapped \
        -virtfs local,path=/home/fan,mount_tag=homeshare,security_model=mapped \
        $topo 1>&/dev/null &

    sleep 2
    running=`ps -ef | grep qemu-system-x86_64 | grep -c raw`
    if [ $running -gt 0 ];then
        echo "QEMU:running" > /tmp/qemu-status
        echo "QEMU instance is up, access it: ssh root@localhost -p $ssh_port"
        sleep 2
    else
        echo "Qemu: start Fail!"
    fi
}

shutdown_qemu() {
    if [ ! -f /tmp/qemu-status ];then
        echo "Warning: qemu is not running, skip shutdown!"
    fi
    running=`cat /tmp/qemu-status | grep -c "QEMU:running"`
    if [ $running -eq 0 ];then
        echo "Warning: qemu is not running, skip shutdown!"
    else
        ssh root@localhost -p $ssh_port "poweroff"
        echo "" > /tmp/qemu-status
        echo "Qemu: shutdown"
    fi
}

help() {
    if [ "$1" == "-h" ]; then
        echo -e "Valid topology \n\
            opt: \n\
            sw: with a switch \n\
            rp1: with only one root port \n\
            hb2: with two home bridges  \n\
            m2: with two memdev and 1 hb  \n\
            "
    fi
}

cleanup() {
    rm -f /tmp/lsa*
    rm -f /tmp/cxltest*
}

set_default_options(){
    mode="tcg"
    num_cpus=1
    TOPO='rp1'
    build_qemu=false
    build_kernel=false
    create_image=false
    run=false
    login=false
    shutdown=false
    install_ndctl=false
}

display_options() {
    echo "***************************"
    echo Run $0 with options:
    echo " mode $mode"
    echo " num_cpus $num_cpus"
    echo " topology $TOPO"
    echo " build_qemu $build_qemu "
    echo " build_kernel $build_kernel"
    echo " KERNEL_ROOT $KERNEL_ROOT"
    echo " QEMU_ROOT $QEMU_ROOT"
    echo " create_image $create_image "
    echo " run $run "
    echo " shutdown $shutdown "
    echo " install_ndctl $install_ndctl "

    echo "***************************"
}

get_cxl_topology() {
    topo=""
    if [ "$1" == "sw" ];then
        topo=$SW
    elif [ "$1" == "rp1" ];then
        topo=$RP1
    elif [ "$1" == "hb2" ];then
        topo=$HB2
    elif [ "$1" == "m2" ];then
        topo=$M2
    else
        echo topology \"$1\" not supported, exit;
    fi
    echo $topo;
}

build_source_code() {
    dir=$1
    cmd=$2

    if [ ! -d $dir ]; then
        echo $dir not found, exit building
        exit
    else
        echo cd $dir
        cd $dir
    fi
    if [ ! -s "$cmd" ];then
        cmd="make -j16"
    fi

    echo $cmd
    #$cmd
}


create_qemu_image() {
    IMG=$QEMU_IMG
    DIR=/tmp/img
    qemu-img create $IMG 16g
    sudo mkfs.ext4 $IMG
    mkdir $DIR
    sudo mount -o loop $IMG $DIR
    sudo debootstrap --arch amd64 stable $DIR
    sudo chroot $DIR
    echo '
    passwd -d root
    qemu-img convert -O qcow2 qemu-image.img qemu-image.qcow2
    sudo umount $DIR
    rmdir $DIR
    '
    echo "qemu image: $IMG"
    exit
}

setup_ndctl() {
    url=$1

    if [ "$url" == "" -o `echo $url | grep -c "github"` -eq 0 ]; then
        url=https://github.com/pmem/ndctl.git
    fi

    ssh root@localhost -p $ssh_port "apt-get install -y git meson bison pkg-config cmake libkmod-dev libudev-dev uuid-dev libjson-c-dev libtraceevent-dev libtracefs-dev asciidoctor keyutils libudev-dev libkeyutils-dev libiniparser-dev"
    ssh root@localhost -p $ssh_port "git clone $url "
    ssh root@localhost -p $ssh_port "\
        cd ndctl;\
        meson setup build;\
        meson compile -C build;\
        meson install -C build
    "
    echo "**********************"
    echo "cxl list:"
    ssh root@localhost -p $ssh_port "cxl list"
    echo "**********************"
    if [ "$?" != "0" ];then
        echo "Install ndctl failed!"
    else
        echo "Install ndctl completed!"
    fi
}

set_default_options
# processing arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -T|--topology) TOPO="$2"; shift ;;
        -N|--CPUS) num_cpus="$2"; shift ;;
        -A|--accel) mode="$2"; shift ;;
        -Q|--qemu_root) QEMU_ROOT="$2"; shift ;;
        -K|--kernel_root) KERNEL_ROOT="$2"; shift ;;
        -BK|--build-kernel) build_kernel=true ;;
        -BQ|--build-qemu) build_qemu=true ;;
        -I|--create-image) create_image=true ;;
        --install-ndctl) install_ndctl=true ;;
        --ndctl-url) ndctl_url=$2; shift ;;
        -P|--port) ssh_port="$2"; shift ;;
        -L|--login) login=true ;;
        -R|--run) run=true ;;
        --poweroff|--shutdown) shutdown=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

QEMU=$QEMU_ROOT/build/qemu-system-x86_64
KERNEL_PATH=$KERNEL_ROOT/arch/x86/boot/bzImage


topo=$(get_cxl_topology $TOPO)
echo $topo

display_options

if $build_kernel ; then
    echo "Build the kernel"
    build_source_code $KERNEL_ROOT
fi

if $build_qemu; then
    echo "Build the qemu"
    build_source_code $QEMU_ROOT
fi

if $create_image; then
    create_qemu_image
fi



if [ ! -s "$port" ];then
    ssh_port="2024"
fi
net_config="-netdev user,id=network0,hostfwd=tcp::$ssh_port-:22 -device e1000,netdev=network0" 


if $run; then
    run_qemu "$topo_str"
fi
if $login; then
    ssh root@localhost -p $ssh_port
fi

if $shutdown; then
    shutdown_qemu
fi

if $install_ndctl; then
    setup_ndctl $ndctl_url
fi


