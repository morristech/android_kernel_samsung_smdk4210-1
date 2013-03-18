#!/bin/bash

###############################################################################
# To all DEV around the world :)                                              #
# to build this kernel you need to be ROOT and to have bash as script loader  #
# do this:                                                                    #
# cd /bin                                                                     #
# rm -f sh                                                                    #
# ln -s bash sh                                                               #
# now go back to kernel folder and run:                                       #                                                         #
# sh clean_kernel.sh                                                          #
#                                                                             #
# Now you can build my kernel.                                                #
# using bash will make your life easy. so it's best that way.                 #
# Have fun and update me if something nice can be added to my source.         #
###############################################################################

# location
export KERNELDIR=`readlink -f .`
export PARENT_DIR=`readlink -f ..`

# kernel
export ARCH=arm
export USE_SEC_FIPS_MODE=true
export KERNEL_CONFIG="dragonheart_n7000_defconfig"

# build script
export USER=`whoami`
export HOST_CHECK=`uname -n`
export OLDMODULES=`find -name *.ko`

# system compiler
# gcc 4.7.2 (Linaro 12.07)
export CROSS_COMPILE=${KERNELDIR}/android-toolchain/bin/arm-eabi-

NAMBEROFCPUS=`grep 'processor' /proc/cpuinfo | wc -l`

if [ "${1}" != "" ]; then
	export KERNELDIR=`readlink -f ${1}`
fi;

if [ ! -f ${KERNELDIR}/.config ]; then
	cp ${KERNELDIR}/arch/arm/configs/${KERNEL_CONFIG} .config
	make ${KERNEL_CONFIG}
fi;

. ${KERNELDIR}/.config

# remove previous zImage files
if [ -e ${KERNELDIR}/zImage ]; then
	rm ${KERNELDIR}/zImage
fi;
if [ -e ${KERNELDIR}/arch/arm/boot/zImage ]; then
	rm ${KERNELDIR}/arch/arm/boot/zImage
fi;

# remove all old modules before compile
cd ${KERNELDIR}
for i in $OLDMODULES; do
	rm -f $i
done;

# remove previous initramfs files
if [ -f "/tmp/cpio*" ]; then
	echo "removing old temp iniramfs_tmp.cpio"
	rm -rf /tmp/cpio*
fi;

# clean initramfs old compile data
rm -f usr/initramfs_data.cpio
rm -f usr/initramfs_data.o

cd ${KERNELDIR}/
cp .config arch/arm/configs/${KERNEL_CONFIG}
if [ $USER != "root" ]; then
	make -j${NAMBEROFCPUS} modules || exit 1
else
	nice -n -15 make -j${NAMBEROFCPUS} modules || exit 1
fi;

# copy modules
mkdir -p out/system/lib/modules
find -name '*.ko' -exec cp -av {} out/system/lib/modules \;
${CROSS_COMPILE}strip --strip-debug out/system/lib/modules/*.ko
chmod 755 out/system/lib/modules/*

if [ $USER != "root" ]; then
	time make -j${NAMBEROFCPUS} zImage
else
	time nice -n -15 make -j${NAMBEROFCPUS} zImage
fi;

if [ -e ${KERNELDIR}/arch/arm/boot/zImage ]; then
	${KERNELDIR}/mkshbootimg.py ${KERNELDIR}/zImage ${KERNELDIR}/arch/arm/boot/zImage ${KERNELDIR}/payload.tar.xz ${KERNELDIR}/recovery.tar.xz

	# copy all needed to out kernel folder
	rm ${KERNELDIR}/out/zImage
	rm ${KERNELDIR}/out/DH-Kernel_*
	stat ${KERNELDIR}/zImage
	GETVER=`grep 'DH-Kernel v.*' arch/arm/configs/${KERNEL_CONFIG} | sed 's/.* .//g' | sed 's/".*//g'`
	cp ${KERNELDIR}/zImage /${KERNELDIR}/out/
	cd ${KERNELDIR}/out/
	if [ $HOST_CHECK == Ubuntu - Phoenix ]; then
		zip -r DH-Kernel_v${GETVER}-`date +"[%m-%d]-[%H-%M]"`.zip .
	else
		zip -r DH-Kernel_v${GETVER}-nightly-`date +"[%m-%d]-[%H-%M]"`.zip .
	fi
	STATUS=`adb get-state` >> /dev/null;
	if [ "$STATUS" == "device" ]; then
		read -p "Push kernel to android (y/n)?"
		if [ "$REPLY" == "y" ]; then
			adb push ${KERNELDIR}/out/DH-Kernel_v*.zip /sdcard/;
		fi;
	fi;
else
	echo "Kernel STUCK in BUILD!"
fi;
