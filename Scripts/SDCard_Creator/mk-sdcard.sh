################################################################
#
#
#RPVSolutions
#Kill9
# SDCard Creator
#2016

VERBOSE="-v"

DEPLOY=.

# rootfs
if ! [[ ${2} == /* ]]; then
	ROOTFS_DEFAULT="$(basename $(ls ${DEPLOY}/*.tar.* -t | head -1))"
	ROOTFS_DEFAULT=${2-${ROOTFS_DEFAULT}}
	ROOTFS="${DEPLOY}/${ROOTFS_DEFAULT}"
else
	ROOTFS=${2}
fi

# boot
MLO="${DEPLOY}/MLO"
UBOOT="${DEPLOY}/u-boot.img"

IMAGE="zImage"
DTB="am335x-bone.dtb"

# card info
DISK=$1
BOOT_LABEL=boot
ROOT_LABEL=rootfs
MNTPOINT="$(mktemp -d)"
BOOT_MNT=${MNTPOINT}/${BOOT_LABEL}
ROOT_MNT=${MNTPOINT}/${ROOT_LABEL}

check_variables_e(){
	echo "${1}=\"${!1}\" don't exist!!"
	echo "Please correct this in top script $0"
	exit
}
check_variables_d(){
	[[ -d ${!1} ]] && return
	check_variables_e $1
}
check_variables_f(){
	[[ -f ${!1} ]] && return
	check_variables_e $1
}

# check variables
check_variables_d DEPLOY
check_variables_f ROOTFS
check_variables_f MLO
check_variables_f UBOOT

# need root and disk
if [[ $(/usr/bin/id -u) -ne 0 ]] || [[ ${DISK} == "" ]] ; then
    echo "You need to run as root:"
    echo "sudo $0 [disk] [image]"
    echo
    echo "[disk]: the device disk"
    echo "$(ls {/dev/sd*,/dev/hd*,/dev/mmc*} 2>/dev/null | tr '\n' ' ')"
    echo
    echo "[image]: the default image name is the newst one (${ROOTFS_DEFAULT})"
    echo "$(ls -tr ${DEPLOY}/*.tar.* | xargs -n1 basename)"
    #echo "$(ls ${DEPLOY}/*.tar.* | xargs -n1 basename | tr '\n' ' ')"
    exit
fi


# uenv
_uenv(){
UENV=$(mktemp)
cat <<EOF > ${UENV}
#
# u-boot-denx/include/configs/am335x_evm.h
#
# we don't need this file to boot!!
# the uboot default configuration boot the kernel with the device tree

# U-Boot (boot in command line):
#bootfile=zImage
#loadimage=load mmc 0 \${loadaddr} \${bootdir}/\${bootfile}
#loadfdt=load mmc 0 \${fdtaddr} \${bootdir}/\${fdtfile}
#runcmd=run loadimage; run findfdt; run loadfdt; run mmcargs
#uenvcmd=run runcmd; bootz 0x80200000 - 0x80F80000

# U-Boot (boot in command line):
#fatinfo mmc
#fatls mmc 0:1
#load mmc 0 \${fdtaddr} am335x-bone.dtb
#load mmc 0 \${fdtaddr} am335x-boneblack.dtb
#load mmc 0 \${loadaddr} zImage
#bootz 0x80200000 - 0x80F80000

#fixrtc
#musb_hdrc.use_dma=0
#netconsole=4444@192.168.99.1/br0,6666@192.168.99.255/00:50:b6:0b:49:f8 loglevel=7 (NAO FUNCA)
#initcall_debug printk.time=y quiet init=/sbin/bootchartd
optargs=ipv6.disable=1 cgroup_disable=memory capemgr.disable_partno=BB-BONELT-HDMI,BB-BONELT-HDMIN
EOF

echo "Create uBoot uEnv..."
(cd ${BOOT_MNT} && mv ${VERBOSE} ${UENV} uEnv.txt)
}

_format(){
#
# Fromat partitions
#
echo "Format ${BOOT_LABEL} [${DISK}1] with vfat..."
mkfs.vfat -F 16 ${DISK}1 -n ${BOOT_LABEL} || exit
echo "Format ${ROOT_LABEL} [${DISK}2] with ext4..."
#mkfs.ext4 -c ${DISK}2 -L ${ROOT_LABEL} || exit
mkfs.ext4 ${DISK}2 -L ${ROOT_LABEL} || exit
}

_partitions(){
#
# Creat partition layout
#
echo "Clearing MBR [${DISK}]..."
dd if=/dev/zero of=${DISK} bs=1M count=16 || exit
echo "Create Partition Layout..."
sfdisk --in-order --Linux --unit M ${DISK} <<-__EOF__
1,48,0xE,*
,,,-
__EOF__
sync
}

_mount(){
#
# Mount DISKs
#
cat /etc/mtab | grep ${DISK} && \
echo "ERROR: ${DISK} is already mounted" && \
exit

sudo mkdir -p ${VERBOSE} ${BOOT_MNT}
sudo mkdir -p ${VERBOSE} ${ROOT_MNT}

echo "Mounting ${DISK} ..."
mount -t vfat ${VERBOSE} ${DISK}1 ${BOOT_MNT} && \
mount -t ext4 ${VERBOSE} ${DISK}2 ${ROOT_MNT} && \
echo "DONE" &&
return

echo "ERROR: could not mount ${DISK}"
_umount
rm -r ${VERBOSE} ${MNTPOINT}
exit
}

_umount(){
#
# Un-mount DISKs
#
echo $1
echo "un-Mounting ${DISK}..."
sync
umount ${VERBOSE} ${BOOT_MNT} && \
umount ${VERBOSE} ${ROOT_MNT} && \
rm -r ${VERBOSE} ${MNTPOINT} && \
echo "DONE" || \
echo "ERROR: could not unmount ${DISK}"
exit
}

_populate_root(){
echo "Populate rootfs..."
rm -rf ${VERBOSE} ${ROOT_MNT}/* && \
tar ${VERBOSE} -xpf ${ROOTFS} -C ${ROOT_MNT} || \
_umount "ERROR"
echo "rootfs successfully extracted!"
}

_populate_boot(){
echo "Populate bootfs..."
cp ${VERBOSE} ${MLO} ${UBOOT} ${BOOT_MNT} || _umount "ERROR"
echo "bootfs successfully copyed!"
_uenv
}

_populate(){
_populate_boot
_populate_root
}

# format...
if ! [ -b ${DISK}1 ] || ! [ -b ${DISK}2 ] ; then
	echo "disk ${DISK} don't have partitions: ${DISK}1 and ${DISK}2"
	echo -n "CONTINUE format ${DISK} partition (Y)? Ctrl^C to STOP: "
	read RESP
	[[ "$RESP" != "Y" ]] && exit
	_partitions
	_format
fi

#_format
#exit

# running..,
_mount
_populate
_umount "DONE"
