About
=====

This is an open-source project released under the Apache 2.0 license (see the "Notice" section below).

This project aimes to build a custom lightweight version of a cloud operating system based on OpenSUSE 13.1. The operating system named is mOS.

Prerequisite
============
In order to build a custom mOS 2.x image you need to following requirements:

 * a running OpenSUSE 13.1 environment;
 * a list of linux tools: gcc, wget, curl;
 * a copy of this repository: ``git clone https://github.com/ieat/mosaic-mos-image-builder``

How to build
============
mOS 2.x can be built for two different cloud providers: AmazonEC2 and HVM. 

mOS 2.x for AmazonEC2 some special patches will be applied to the initrd and kernel to support Amazon particular XEN virtualization.

mOS 2.x with HVM should be compatible with any cloud stack that uses HVM virtualization as backend.

To build mOS 2.0:

.. code:: bash

 cd bin/
 ./build-mos-image.sh [ec2|HVM] mos_image_name mos_image_version mos_image_build_number mos_image_size_MB
 
where:

 * ``mos_image_name`` - a custom name for the built image;
 * ``mos_image_version`` - image version;
 * ``mos_image_built_number`` - current built number for the custom image;
 * ``mos_image_size_MB`` - image size expressed in MBytes;
 

How to run
==========

The resulting image is a raw image file. This image can be bundled using the desired cloud provider upload tools.

mOS 2.x was successfully tested on: AmazonEC2, Flexiant, Eucalyptus and OpenNebula. Other cloud providers might be supported as long as 
they offer HVM or XEN virtualization.

Notice
======

This product includes software developed at "Institute e-Austria, Timisoara".

* http://www.ieat.ro/

Developers:

* Silviu Panica ( silviu.panica@e-uvt.ro / silviu@solsys.ro )

Copyright: ::

   Copyright 2010-2015, Institute e-Austria, Timisoara, Romania
       http://www.ieat.ro/

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at:
       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
