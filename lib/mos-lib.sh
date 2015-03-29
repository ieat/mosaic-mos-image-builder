#!/bin/bash

function if_image_factory_help(){
	echo " [if] Usage:"
	echo
	echo "      build-mos-image.sh <image-type> <image-name> <image-version> <image-build> [<image-size>]"
	echo "           - <image-type>    = [ec2|hvm]"
	echo "           - <image-name>    = custom image name"
	echo "           - <image-version> = custom image version"
	echo "           - <image-build>   = custom image build number" 
	echo "           - [<image-size>]  = custom image size in MB"
	echo
}

function if_prepare_build_environment() {
	if [ ! -d "${__mos_build_path}" ];then
        echo " -- Creating build path [${__mos_build_path}] ..."
        mkdir -p ${__mos_build_path}
	fi

	if [ ! -d "${__mos_chroot_path}" ];then
        echo " -- Creating chroot path [${__mos_chroot_path}] ..."
        mkdir -p ${__mos_chroot_path}
        mkdir -p ${__mos_btrfs_path}
	fi
}

function if_disable_mos_root_password() {
	echo " -- Deleting root user password"
	passwd -R ${__mos_chroot_path} -d root
}

function if_create_default_home_dir() {
	if [ ! -d "${__mos_chroot_path}"/var/home ];then
		echo " -- Creating default /var/home directory for user accounts"
		mkdir -p ${__mos_chroot_path}/var/home
	fi
}

function if_create_mos_operator() {
	if_create_default_home_dir
	echo " -- Create mos operator account ..."
	useradd -R ${__mos_chroot_path} -d /var/home/${__mos_operator_username} -M -U -r ${__mos_operator_username}
	mkdir -p ${__mos_chroot_path}/var/home/${__mos_operator_username}
	chmod 755 ${__mos_chroot_path}/var/home/${__mos_operator_username}
	chroot ${__mos_chroot_path} ln -sT /opt/mos-node-tools/lib/operator-bash-login.bash /var/home/${__mos_operator_username}/.bash_login
	chroot ${__mos_chroot_path} ln -sT /opt/mos-node-tools/lib/operator-bash-logout.bash /var/home/${__mos_operator_username}/.bash_logout
	chroot ${__mos_chroot_path} ln -sT /opt/mos-node-tools/lib/operator-bash-rc.bash /var/home/${__mos_operator_username}/.bashrc
	chroot ${__mos_chroot_path} chown -Rh ${__mos_operator_username}:${__mos_operator_username} /var/home/${__mos_operator_username}
	echo -n ${__mos_operator_username}':'${__mos_operator_password} | chpasswd -e -R ${__mos_chroot_path}
	echo " -- Create mos-services system account ..."
	useradd -R ${__mos_chroot_path} -d /tmp/mos-services-home -s /bin/false -r -M -U mos-services
	echo " -- Add ${__mos_operator_username} in mos-services group"
	gpasswd --root ${__mos_chroot_path} -a ${__mos_operator_username} mos-services
	echo " -- Create mos-packages system account ..."
	useradd -R ${__mos_chroot_path} -d /tmp/mos-packages-home -s /bin/false -r -M -U mos-packages
}

function if_create_disk_layout() {
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
}

function if_create_fs_layout() {
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
	btrfs subvolume create mos/volumes/mos-slash-current/mos
	btrfs subvolume create mos/volumes/mos-slash-current/me2
	
	__mos_mos_volid=$(btrfs subvolume list . | grep "path mos$" | cut -d " " -f2)
	__mos_volumes_volid=$(btrfs subvolume list . | grep "path mos/volumes$" | cut -d " " -f2)
	__mos_slash_current_volid=$(btrfs subvolume list . | grep mos/volumes/mos-slash-current$ | cut -d " " -f2)
	
	__mos_boot_part=$(losetup -v -f --show /dev/mapper/${__mos_loop_dev}p1)
	__mos_root_part=$(losetup -v -f --show /dev/mapper/${__mos_loop_dev}p2)

	mount -o subvolid=${__mos_slash_current_volid} ${__mos_root_part} ${__mos_chroot_path}
	mkdir ${__mos_chroot_path}/boot
	mount ${__mos_boot_part} ${__mos_chroot_path}/boot
}

function if_create_swap_space() {
	echo " -- Creating swap file ..."
	dd if=/dev/zero of=${__mos_btrfs_path}/mos/volumes/mos-swaps/1.swap seek=32000 count=0 bs=1M
	mkswap ${__mos_btrfs_path}/mos/volumes/mos-swaps/1.swap
}

function if_add_mos_main_repos() {
	echo " -- Adding mOS-${__mos_version} main repositories:"
	for _r in ${__main_repos[@]};
	do
		__rn=$(echo ${_r} | cut -d"@" -f1)
		__rl=$(echo ${_r} | cut -d"@" -f2)
		echo "    -- ${__rn}"
		zypper --no-gpg-checks --gpg-auto-import-keys -n -R ${__mos_chroot_path} ar -G ${__rl} ${__rn}	
	done
}

function if_install_mos_base() {
	echo " -- Installing ${__mos_version} base system ..."
	zypper --no-gpg-checks --gpg-auto-import-keys -n -R ${__mos_chroot_path} install -l ${__mos_base_packages} 
	echo " -- Installing ${__mos_version} bootstrap packages ..."
	zypper --no-gpg-checks --gpg-auto-import-keys -n -R ${__mos_chroot_path} install -l ${__mos_bootstrapper}
}

function if_create_custom_paths() {
	echo " -- Add /.mos-rootfs directory ..."
	mkdir -p ${__mos_chroot_path}/.mos-rootfs
	echo " -- Add /mos layout ..."
	mkdir -p ${__mos_chroot_path}/mos/{etc,log,run,tmp,cgi}
}

function if_mount_bind_devices() {
	echo " -- Creating ${__mos_chroot_path}/{dev,proc,sys} directories ..."
	mkdir ${__mos_chroot_path}/dev ${__mos_chroot_path}/proc ${__mos_chroot_path}/sys
	mount -o bind /dev/ ${__mos_chroot_path}/dev
	mount -t proc none ${__mos_chroot_path}/proc
	mount -t sysfs none ${__mos_chroot_path}/sys	
}

function if_unmount_bind_devices() {
	cd /
	umount ${__mos_chroot_path}/{dev,proc,sys}
}

function if_create_fstab() {
	echo " -- Adding mos-rootfs, mos-boot label for root partition ..."
	echo "LABEL=mos-rootfs / btrfs defaults 1 1" > ${__mos_chroot_path}/etc/fstab
	echo "LABEL=mos-rootfs /.mos-rootfs btrfs defaults,subvolid=${__mos_mos_volid} 0 0" >> ${__mos_chroot_path}/etc/fstab
	echo "LABEL=mos-boot /boot ext4 defaults 0 1" >> ${__mos_chroot_path}/etc/fstab
	echo "tmpfs /run tmpfs size=1G,exec,nosuid,nodev,relatime 0 0" >> ${__mos_chroot_path}/etc/fstab
	echo "tmpfs /var/tmp tmpfs size=2G,exec,nosuid,nodev,relatime 0 0" >> ${__mos_chroot_path}/etc/fstab
	echo "tmpfs /var/run tmpfs size=1G,exec,nosuid,nodev,relatime 0 0" >> ${__mos_chroot_path}/etc/fstab
	echo "tmpfs /var/lock tmpfs size=512M,noexec,nosuid,nodev,relatime 0 0" >> ${__mos_chroot_path}/etc/fstab
	echo "tmpfs /tmp tmpfs size=2G,exec,nosuid,nodev,relatime 0 0" >> ${__mos_chroot_path}/etc/fstab
}

function if_customize_mos_services() {
	echo " -- Setting default hostname ..."
	echo "mos-cloud" > ${__mos_chroot_path}/etc/HOSTNAME
	
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
}

function if_generate_btrfs_layout() {
	echo " -- Creating layout particularities ..."
	if_create_default_home_dir
	chroot ${__mos_chroot_path} mv /root /var/home/
	chroot ${__mos_chroot_path} ln -s /var/home/root /root
	chroot ${__mos_chroot_path} mv /srv /var/
	chroot ${__mos_chroot_path} ln -s /var/srv /srv
	if_unmount_bind_devices
	chroot ${__mos_chroot_path} chmod 000 /var/tmp /var/run /var/lock /tmp /dev /proc /sys /selinux
	
	echo " -- Create clean snapshots ..."
	cd ${__mos_btrfs_path}
	btrfs subvolume snapshot mos/volumes/mos-slash-current mos/volumes/mos-slash-base
	btrfs subvolume snapshot mos/volumes/mos-slash-current/etc mos/volumes/mos-etc-base
	btrfs subvolume snapshot mos/volumes/mos-slash-current/var mos/volumes/mos-var-base
	btrfs subvolume snapshot mos/volumes/mos-slash-current/var/cache mos/volumes/mos-var-cache-base
	btrfs subvolume snapshot mos/volumes/mos-slash-current/mos mos/volumes/mos-mos-base
	btrfs subvolume snapshot mos/volumes/mos-slash-current/me2 mos/volumes/mos-me2-base
}

function if_cleanup_installation() {
	echo " -- Done. Exiting and cleaning up ..."
	cd /
	umount ${__mos_chroot_path}/boot
	sleep 1
	umount ${__mos_chroot_path}
	umount ${__mos_btrfs_path}
	sleep 1
	losetup -d ${__mos_root_part}
	sleep 1
	losetup -d ${__mos_boot_part}
	sleep 1
	kpartx -d ${__mos_build_path}/${__mos_name}
	echo "${__mos_name} was built. The file: ${__mos_build_path}/${__mos_name}"
}