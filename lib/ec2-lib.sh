#!/bin/bash

function if_install_mos_ec2_kernel() {
	echo " -- Installing mOS ${__mos_version} EC2 kernel ..."
	zypper --no-gpg-checks --gpg-auto-import-keys -n -R ${__mos_chroot_path} install -l ${__kernel_ec2}
}

function if_add_mos_s3_repos() {
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

function if_generate_ec2_boot_conf() {
	echo " -- Generate grub.cfg ..."
	__mos_initrd_ec2=$(readlink ${__mos_chroot_path}/boot/initrd-ec2)
	__mos_kernel_ec2=$(readlink ${__mos_chroot_path}/boot/vmlinuz-ec2)

	echo ' -- Generate pvgrub config (for PV vms) ...'
	mkdir -p ${__mos_chroot_path}/boot/grub
	cat >  ${__mos_chroot_path}/boot/grub/menu.lst <<EOF
default 0
timeout 1


title mOS-2.0
root (hd0,0)
kernel /${__mos_kernel_ec2} root=LABEL=mos-rootfs nomodeset xencons=xvc0 console=xvc0 multipath=off showopts rootfstype=btrfs
initrd /${__mos_initrd_ec2}
EOF

	echo " -- Preparing modules list for initrd ..."
	sed -i 's/INITRD_MODULES=.*/INITRD_MODULES="dm-mod xenblk xennet btrfs virtio virtio_net virtio_blk virtio_pci virtio_scsi acpihp pci_hotplug"/g' ${__mos_chroot_path}/etc/sysconfig/kernel

	echo " -- hack to support OpenSUSE 13.1 mkinitrd"
	sed -i 's/additional_args=--allow-unsupported-modules/additional_args=/g' ${__mos_chroot_path}/lib/mkinitrd/scripts/setup-modules.sh

	echo " -- Creating custom initrd ..."
	chroot ${__mos_chroot_path} mkinitrd -A -d LABEL=mos-rootfs -m "dm-mod xenblk xennet btrfs virtio virtio_net virtio_blk virtio_pci virtio_scsi acpihp pci_hotplug"

	#echo " -- Replace initrd with a custom one to support EC2"
	#curl -o ${__mos_chroot_path}/boot/${__mos_initrd_ec2} http://ftp.info.uvt.ro/mos/tools/ec2/initrd-3.11.10-21-ec2-new

	echo " -- Patch initird to support brtfs boot for AmazonEC2"
	mkdir /tmp/tmp-initrd
	cp ${__mos_chroot_path}/boot/${__mos_initrd_ec2} /tmp/tmp-initrd
	cd /tmp/tmp-initrd
	mv ${__mos_initrd_ec2} ${__mos_initrd_ec2}.gz && gunzip ${__mos_initrd_ec2}.gz
	cat ${__mos_initrd_ec2} | cpio -i
	rm ${__mos_initrd_ec2}
	curl -o /tmp/tmp-initrd/run_all.patch http://ftp.info.uvt.ro/mos/tools/ec2/run_all.patch
	patch < run_all.patch
	rm run_all.patch
	curl -o /tmp/tmp-initrd/usr/sbin/kpartx.static http://ftp.info.uvt.ro/mos/tools/ec2/kpartx.static
	chmod +x /tmp/tmp-initrd/usr/sbin/kpartx.static
	find . | cpio -H newc -o > ../initramfs.cpio && cd .. && mv -f initramfs.cpio ${__mos_initrd_ec2} && gzip -9 ${__mos_initrd_ec2}
	mv ${__mos_initrd_ec2}.gz ${__mos_chroot_path}/boot/${__mos_initrd_ec2}
	cd ..
	rm -rf /tmp/tmp-initrd
}