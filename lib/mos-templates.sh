#!/bin/bash

function mos_ec2_template() {
## create disk layout
	if_create_disk_layout
	
## create file system layout
	if_create_fs_layout
	
## create swap space
	if_create_swap_space
	
## add mOS repositories
	if_add_mos_main_repos
	if_add_mos_s3_repos
	
## install mOS base system
	if_install_mos_base
	if_install_mos_ec2_kernel
	
## disable root password
	if_disable_mos_root_password
	
## add mos-operator account
	if_create_mos_operator
	
## create custom paths
	if_create_custom_paths
	
## create default fstab
	if_create_fstab
	
## mount devices as bind
	if_mount_bind_devices
	
## customize mos services
	if_customize_mos_services
	
## generate ec2 boot configuration
	if_generate_ec2_boot_conf
	
## generate particularities
	if_generate_btrfs_layout
	
## cleanup
	if_cleanup_installation
}

function mos_default_template() {
## create disk layout
	if_create_disk_layout
	
## create file system layout
	if_create_fs_layout
	
## create swap space
	if_create_swap_space
	
## add mOS repositories
	if_add_mos_main_repos
	if_add_mos_default_repos
	
## install mOS base system
	if_install_mos_base
	if_install_mos_default_kernel
	
## disable root password
	if_disable_mos_root_password
	
## add mos-operator account
	if_create_mos_operator
	
## create custom paths
	if_create_custom_paths
	
## create default fstab
	if_create_fstab
	
## mount devices as bind
	if_mount_bind_devices
	
## customize mos services
	if_customize_mos_services
	
## generate default boot configuration
	if_generate_default_boot_conf
	
## generate particularities
	if_generate_btrfs_layout
	
## cleanup
	if_cleanup_installation
}

