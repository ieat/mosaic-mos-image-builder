#!/bin/bash

euca-bundle-image -i mOS-1.2-0-x86_64 --ramdisk eri-E72A3D3C --kernel eki-57FB3A91 -r x86_64
euca-upload-bundle -b mos1 -m /tmp/mOS-1.2-0-x86_64.manifest.xml
euca-register -n mOS-1_2-0-x86_64-4GB -d "mOS-1.2-0 - cloud image" -a x86_64 --ramdisk eri-E72A3D3C --kernel eki-57FB3A91 mos1/mOS-1.2-0-x86_64.manifest.xml
euca-modify-image-attribute -l -a all emi-B2504014

