#!/bin/bash

__cwd=$(readlink -f "$( dirname "$0" )")
. ${__cwd}/../etc/mos-conf.sh
. ${__cwd}/../lib/mos-lib.sh
. ${__cwd}/../lib/mos-templates.sh


if [ $# -lt 4 ];then
        if_image_factory_help
        exit 1
fi

__mos_header=$2
__mos_version=$3
__mos_build_number=$4
__mos_name=${__mos_header}-${__mos_version}-${__mos_build_number}-${__mos_arch}

if [ ! -z "$5" ];then
	__mos_image_size=$5
fi 

##########

case $1 in
	"ec2")
		if_prepare_build_environment
		. ${__cwd}/../lib/ec2-lib.sh
		mos_ec2_template
	;;
	"hvm")
		if_prepare_build_environment
		. ${__cwd}/../lib/default-lib.sh
		mos_default_template
	;;
	*) 
		if_image_factory_help
		exit 1
	;;
esac
