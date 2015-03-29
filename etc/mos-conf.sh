## mOS-1.1 builder properties

__mos_chroot_path=/mnt/mos-builder
__mos_btrfs_path=/mnt/mos-builder-btrfs
__mos_build_path=/opt/mos-image-factory/images

__mos_version=2.0
__mos_build_number=70
__mos_arch=x86_64
__mos_header=mOS
__mos_name=${__mos_header}-${__mos_version}-${__mos_build_number}-${__mos_arch}
__mos_image_size=5000
__main_repos[0]='openSUSE-13.1-oss@http://ftp.roedu.net/mirrors/opensuse.org/distribution/13.1/repo/oss/'
__main_repos[1]='openSUSE-13.1-update@http://ftp.roedu.net/mirrors/opensuse.org/update/13.1/'
__main_repos[2]='@http://ftp.roedu.net/mirrors/opensuse.org/repositories/systemsmanagement:/puppet/openSUSE_13.1/systemsmanagement:puppet.repo'
__main_repos[3]='@http://ftp.roedu.net/mirrors/opensuse.org/repositories/Virtualization/openSUSE_13.1/Virtualization.repo'
__uvt_repos[0]='mosaic@http://mos.repositories.mosaic-apps.eu/v2/packages/mosaic/rpm/'
__uvt_repos[1]='mosaic-external@http://mos.repositories.mosaic-apps.eu/v2/packages/external/rpm/'
__uvt_repos[2]='modaclouds@http://mos.repositories.mosaic-apps.eu/v2/packages/modaclouds/rpm/'
__uvt_repos[3]='specs@http://mos.repositories.mosaic-apps.eu/v2/packages/specs/rpm/'
__s3_repos[0]='mosaic-s3@https://s3-eu-west-1.amazonaws.com/mos-packages/v2/mosaic/rpm/'
__s3_repos[1]='mosaic-external-s3@https://s3-eu-west-1.amazonaws.com/mos-packages/v2/external/rpm/'
__s3_repos[2]='modaclouds-s3@https://s3-eu-west-1.amazonaws.com/mos-packages/v2/modaclouds/rpm/'
__s3_repos[3]='specs-s3@https://s3-eu-west-1.amazonaws.com/mos-packages/v2/specs/rpm/'

__kernel_ec2="kernel-ec2"
__kernel_hvm="kernel-default"
__mos_base_packages="aaa_base \
                    openssh \
                    util-linux \
                    ca-certificates-cacert \
                    nano \
                    zypper \
                    iputils \
                    less \
                    btrfsprogs \
                    curl \
                    rsyslog \
                    libudev1 \
                    udev \
                    tar \
                    device-mapper \
                    sudo"
__mos_bootstrapper="mos-node-bootstrapper"
# echo -n "passwd" | openssl passwd -1 -stdin
__mos_builder_gpg='http://ftp.info.uvt.ro/mos/opensuse/13.1/packages/repodata/mos-build-system.asc'
__mos_default_password='$1$xK3UHx1m$bnS4sW/fOHbaxCMGdRTpd.'
__mos_operator_username='mos-operator'
__mos_operator_password='$1$HA2ygWZc$xFgM60NHVByppBwl53Jp91'
                 