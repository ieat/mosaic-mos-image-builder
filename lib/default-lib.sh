#!/bin/bash
function if_install_mos_default_kernel() {
	echo " -- Installing mOS ${__mos_version} default kernel ..."
	zypper --no-gpg-checks --gpg-auto-import-keys -n -R ${__mos_chroot_path} install -l ${__kernel_hvm}
}
function if_add_mos_default_repos() {
	echo " -- Adding mOS-${__mos_version} UVT and S3(disabled) repositories:"
	for _r in ${__uvt_repos[@]};
	do
		__rn=$(echo ${_r} | cut -d"@" -f1)
		__rl=$(echo ${_r} | cut -d"@" -f2)
		echo "    -- ${__rn}"
		zypper --no-gpg-checks --gpg-auto-import-keys -n -R ${__mos_chroot_path} ar -G ${__rl} ${__rn}	
	done
	for _r in ${__s3_repos[@]};
	do
		__rn=$(echo ${_r} | cut -d"@" -f1)
		__rl=$(echo ${_r} | cut -d"@" -f2)
		echo "    -- ${__rn}"
	zypper --no-gpg-checks --gpg-auto-import-keys -n -R ${__mos_chroot_path} ar -G -d ${__rl} ${__rn}	
	done
}

function if_generate_default_boot_conf() {
	echo " -- Preparing modules list for initrd ..."
	sed -i 's/INITRD_MODULES=.*/INITRD_MODULES="virtio virtio_net virtio_blk virtio_pci virtio_scsi btrfs acpiphp pci_hotplug"/g' ${__mos_chroot_path}/etc/sysconfig/kernel
	
	echo " -- hack to support OpenSUSE 13.1 mkinitrd"
	sed -i 's/additional_args=--allow-unsupported-modules/additional_args=/g' ${__mos_chroot_path}/lib/mkinitrd/scripts/setup-modules.sh
	
	echo " -- Creating custom initrd ..."
	chroot ${__mos_chroot_path} mkinitrd -A -d LABEL=mos-rootfs -m "virtio virtio_net virtio_blk virtio_pci virtio_scsi btrfs"
	
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
	
	echo " -- Generate grub2.cfg ..."
	__mos_initrd=$(readlink ${__mos_chroot_path}/boot/initrd)
	__mos_kernel=$(readlink ${__mos_chroot_path}/boot/vmlinuz)
	
	cat >  ${__mos_chroot_path}/boot/grub2/grub.cfg <<EOF
set default=0
set timeout=3

menuentry 'mOS-2.0' {
        echo    'Loading kernel ...'
		linux   /${__mos_kernel} root=LABEL=mos-rootfs nomodeset net.ifnames=0
        echo    'Loading initial ramdisk ...'
        initrd  /${__mos_initrd}
}
EOF
	
	echo " -- Generate pvgrub config (for PV vms) ..."
	mkdir -p ${__mos_chroot_path}/boot/grub
	cat >  ${__mos_chroot_path}/boot/grub/menu.lst <<EOF
default 0
timeout 1


title mOS-2.0
root (hd0,0)
kernel /${__mos_kernel} root=LABEL=mos-rootfs nomodeset
initrd /${__mos_initrd}
EOF

}