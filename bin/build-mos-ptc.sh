#!/bin/bash

if [ $# -lt 3 ];then
        echo "Usage: $0 mOS-name mOS-version mOS-build-number [mOS-size]"
        exit 1
fi

__cwd=$(readlink -f "$( dirname "$0" )")
. ${__cwd}/../etc/mos-conf.sh

__mos_header=$1
__mos_version=$2
__mos_build_number=$3
__mos_name=${__mos_header}-${__mos_version}-${__mos_build_number}-${__mos_arch}

if [ ! -z "$4" ];then
	__mos_image_size=$4
fi 

if [ ! -d ${__mos_build_path} ];then
        echo " -- Creating build path [${__mos_build_path}] ..."
        mkdir -p ${__mos_build_path}
fi

if [ ! -d ${__mos_chroot_path} ];then
        echo " -- Creating chroot path [${__mos_chroot_path}] ..."
        mkdir -p ${__mos_chroot_path}
        mkdir -p ${__mos_btrfs_path}
fi

##########

echo " -- Creating ${__mos_name} disk with dd ..."
dd if=/dev/zero of=${__mos_build_path}/${__mos_name} seek=${__mos_image_size} count=0 bs=1M

echo " -- Mapping the disk file with a loop device ..."
_mos_loop_dev=$(losetup -f ${__mos_build_path}/${__mos_name} --show)
echo "    -- Mapped with device ${_mos_loop_dev}"

echo " -- Create partitions: boot and rootfs ..."
fdisk ${_mos_loop_dev} <<EOF
n
p
1

+512M
n
p
2


a
1
w
EOF

losetup -d ${_mos_loop_dev}
__mos_loop_dev=$(basename $(kpartx -v -s -a ${__mos_build_path}/${__mos_name} | cut -d" " -f8 | head -1))

echo " -- Creating /boot partition ext4 "
mkfs.ext4 -L mos-boot /dev/mapper/${__mos_loop_dev}p1

echo " -- Creating BTRFS on /dev/mapper/${__mos_loop_dev}p2|${__mos_build_path}/${__mos_name}"
mkfs.btrfs -f /dev/mapper/${__mos_loop_dev}p2 -L mos-rootfs

echo " -- Mount rootfs temporary into ${__mos_btrfs_path}"
mount /dev/mapper/${__mos_loop_dev}p2 ${__mos_btrfs_path}

echo " -- Create minimum structure "
cd ${__mos_btrfs_path}
btrfs subvolume create mos
btrfs subvolume create mos/volumes
btrfs subvolume create mos/volumes/mos-swaps
btrfs subvolume create mos/volumes/mos-slash-current
btrfs subvolume create mos/volumes/mos-slash-current/etc
btrfs subvolume create mos/volumes/mos-slash-current/var
btrfs subvolume create mos/volumes/mos-slash-current/var/cache
btrfs subvolume create mos/volumes/mos-slash-current/me2

__mos_mos_volid=$(btrfs subvolume list . | grep "path mos$" | cut -d " " -f2)
__mos_volumes_volid=$(btrfs subvolume list . | grep "path mos/volumes$" | cut -d " " -f2)
__mos_slash_current_volid=$(btrfs subvolume list . | grep mos/volumes/mos-slash-current$ | cut -d " " -f2)

__mos_boot_part=$(losetup -v -f --show /dev/mapper/${__mos_loop_dev}p1)
__mos_root_part=$(losetup -v -f --show /dev/mapper/${__mos_loop_dev}p2)

mount -o subvolid=${__mos_slash_current_volid} ${__mos_root_part} ${__mos_chroot_path}
mkdir ${__mos_chroot_path}/boot
mount ${__mos_boot_part} ${__mos_chroot_path}/boot

echo " -- Creating swap file ..."
dd if=/dev/zero of=${__mos_btrfs_path}/mos/volumes/mos-swaps/1.swap seek=32000 count=0 bs=1M
mkswap ${__mos_btrfs_path}/mos/volumes/mos-swaps/1.swap

echo " -- Adding mOS-${__mos_version} standard repositories:"
for _r in ${__repos[@]};
do
	__rn=$(echo ${_r} | cut -d"@" -f1)
	__rl=$(echo ${_r} | cut -d"@" -f2)
	echo "    -- ${__rn}"
	zypper --no-gpg-checks --gpg-auto-import-keys -n -R ${__mos_chroot_path} ar -G ${__rl} ${__rn}	
done

echo " -- Installing ${__mos_version} base system ..."
zypper --no-gpg-checks --gpg-auto-import-keys -n -R ${__mos_chroot_path} install -l ${__mos_base_packages}

echo " -- Installing mOS kernel ..."
zypper --no-gpg-checks --gpg-auto-import-keys -n -R ${__mos_chroot_path} install -l ${__kernel_hvm}

echo " -- Setting default root password ..."
echo 'root:'${__mos_default_password} | chpasswd -e -R ${__mos_chroot_path}

echo " -- Add /mos directory ..."
mkdir ${__mos_chroot_path}/mos

echo " -- Adding mos-rootfs, mos-boot label for root partition ..."
echo "LABEL=mos-rootfs / btrfs defaults 1 1" > ${__mos_chroot_path}/etc/fstab
echo "LABEL=mos-rootfs /mos btrfs defaults,subvolid=${__mos_mos_volid} 0 0" >> ${__mos_chroot_path}/etc/fstab
echo "LABEL=mos-boot /boot ext4 defaults 0 1" >> ${__mos_chroot_path}/etc/fstab
echo "tmpfs /run tmpfs size=1G,exec,nosuid,nodev,relatime 0 0" >> ${__mos_chroot_path}/etc/fstab
echo "tmpfs /var/tmp tmpfs size=2G,exec,nosuid,nodev,relatime 0 0" >> ${__mos_chroot_path}/etc/fstab
echo "tmpfs /var/run tmpfs size=1G,exec,nosuid,nodev,relatime 0 0" >> ${__mos_chroot_path}/etc/fstab
echo "tmpfs /var/lock tmpfs size=512M,noexec,nosuid,nodev,relatime 0 0" >> ${__mos_chroot_path}/etc/fstab
echo "tmpfs /tmp tmpfs size=2G,exec,nosuid,nodev,relatime 0 0" >> ${__mos_chroot_path}/etc/fstab

echo " -- Setting default hostname ..."
echo "mos-cloud" > ${__mos_chroot_path}/etc/HOSTNAME

echo " -- Preparing modules list for initrd ..."
sed -i 's/INITRD_MODULES=.*/INITRD_MODULES="virtio virtio_net virtio_blk virtio_pci virtio_scsi btrfs acpiphp pci_hotplug"/g' ${__mos_chroot_path}/etc/sysconfig/kernel

echo " -- hack to support OpenSUSE 13.1 mkinitrd"
sed -i 's/additional_args=--allow-unsupported-modules/additional_args=/g' ${__mos_chroot_path}/lib/mkinitrd/scripts/setup-modules.sh

echo " -- Creating ${__mos_chroot_path}/{dev,proc,sys} directories ..."
mkdir ${__mos_chroot_path}/dev ${__mos_chroot_path}/proc ${__mos_chroot_path}/sys
mount -o bind /dev/ ${__mos_chroot_path}/dev
mount -t proc none ${__mos_chroot_path}/proc
mount -t sysfs none ${__mos_chroot_path}/sys

#echo " -- Import mOS Builder GPG key ..."
#chroot ${__mos_chroot_path} rpm --import ${__mos_builder_gpg}

echo " -- Creating custom initrd ..."
chroot ${__mos_chroot_path} mkinitrd -A -d LABEL=mos-rootfs -m "virtio virtio_net virtio_blk virtio_pci virtio_scsi btrfs"

echo " -- Setting eth0 interface to dhcp ..."
cat > ${__mos_chroot_path}/etc/sysconfig/network/ifcfg-eth0 <<EOF
BOOTPROTO="dhcp"
NAME="eth0 - network interface"
STARTMODE="hotplug"
USERCONTROL="no"
EOF

echo " -- Setting up sshd service ..."
echo "UseDNS no" >> ${__mos_chroot_path}/etc/ssh/sshd_config
chroot ${__mos_chroot_path} chkconfig sshd on

echo " -- Set default-volume-id to ${__mos_slash_current_volid} ..."
btrfs subvolume set-default ${__mos_slash_current_volid} ${__mos_btrfs_path}/mos

echo " -- Generate fake device.map ..."
echo "(hd0) /dev/${__mos_loop_dev}" > ${__mos_chroot_path}/tmp/device.map

echo " -- Setup grub2 ..."
grub2-install \
	--no-floppy \
	--modules="biosdisk part_msdos ext2 configfile normal multiboot btrfs" \
	--root-directory=${__mos_chroot_path} \
	--grub-mkdevicemap=${__mos_chroot_path}/tmp/device.map \
	--target=i386-pc \
	/dev/${__mos_loop_dev}

echo " -- Generate grub.cfg ..."
__mos_initrd=$(readlink ${__mos_chroot_path}/boot/initrd)
__mos_kernel=$(readlink ${__mos_chroot_path}/boot/vmlinuz)

cat >  ${__mos_chroot_path}/boot/grub2/grub.cfg <<EOF
set default=0
set timeout=3

menuentry 'mOS-2.0' {
        echo    'Loading kernel ...'
linux   /${__mos_kernel} root=LABEL=mos-rootfs nomodeset net.ifnames=0 testbed zeroconf=192.168.178.10
        echo    'Loading initial ramdisk ...'
        initrd  /${__mos_initrd}
}
EOF

# Some updates
sed -i 's/retry_delay_ip_read=2/retry_delay_ip_read=4/g' ${__mos_chroot_path}/opt/mos-node-bootstrapper/etc/mos-init.conf
sed -i 's/retry_count_ip_read=10/retry_count_ip_read=15/g' ${__mos_chroot_path}/opt/mos-node-bootstrapper/etc/mos-init.conf
sed -i 's/mos-repo/mosaic/' ${__mos_chroot_path}/opt/mos-node-bootstrapper/lib/update.sh

echo " -- Creating layout particularities ..."
chroot ${__mos_chroot_path} mv /root /var/
chroot ${__mos_chroot_path} ln -s /var/root /root
chroot ${__mos_chroot_path} mv /srv /var/
chroot ${__mos_chroot_path} ln -s /var/srv /srv
cd /
umount  ${__mos_chroot_path}/{boot,dev,proc,sys}
sleep 1
chroot ${__mos_chroot_path} chmod 000 /var/tmp /var/run /var/lock /tmp /dev /proc /sys /selinux

echo " -- Create clean snapshots ..."
cd ${__mos_btrfs_path}
btrfs subvolume snapshot mos/volumes/mos-slash-current mos/volumes/mos-slash-base
btrfs subvolume snapshot mos/volumes/mos-slash-current/etc mos/volumes/mos-etc-base
btrfs subvolume snapshot mos/volumes/mos-slash-current/var mos/volumes/mos-var-base
btrfs subvolume snapshot mos/volumes/mos-slash-current/var/cache mos/volumes/mos-var-cache-base
btrfs subvolume snapshot mos/volumes/mos-slash-current/me2 mos/volumes/mos-me2-base

echo " -- Done. Exiting and cleaning up ..."
cd /
umount ${__mos_chroot_path}
umount ${__mos_btrfs_path}
sleep 1
losetup -d ${__mos_boot_part}
sleep 1
losetup -d ${__mos_root_part}
sleep 1
kpartx -d ${__mos_build_path}/${__mos_name}

echo "${__mos_name} was built. The file: ${__mos_build_path}/${__mos_name}"