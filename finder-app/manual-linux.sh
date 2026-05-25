#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi

if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # TODO: Add your kernel build steps here
make ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE} mrproper
make ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE} defconfig
make -j4 ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE} Image
make ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE} dtbs

#mkdir -p ${OUTDIR}/image
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}
# mkdir -p ${OUTDIR}/dtbs/
# cp arch/arm64/boot/dts/*.dtb ${OUTDIR}/dtbs/


    
fi

echo "Adding the Image in outdir"

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
mkdir -p ${OUTDIR}/rootfs
cd ${OUTDIR}/rootfs
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir -p usr/bin usr/lib usr/sbin
mkdir -p var/log
mkdir -p dev/pts
mkdir -p dev/shm
mkdir -p dev/mqueue
mkdir -p dev/hugepages
mkdir -p dev/console
ln -s /proc/self/fd dev/fd
ln -s /proc/self/fd/0 dev/stdin
ln -s /proc/self/fd/1 dev/stdout
ln -s /proc/self/fd/2 dev/stderr



cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone  https://git.busybox.net/busybox/
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox
    make ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE} distclean # Ensure a clean build
    make ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE} defconfig # Use the default configuration
else
    cd busybox
fi

# TODO: Make and install busybox
make -j4 ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE}  # Build busybox with 4 parallel jobs
make ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=${OUTDIR}/rootfs install # Install busybox to the rootfs directory

echo "Displaying library dependencies"
${CROSS_COMPILE}readelf -a ${OUTDIR}/busybox/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a ${OUTDIR}/busybox/busybox | grep "Shared library"

# TODO: Add library dependencies to rootfs
# Copy library dependencies
echo "Copying library dependencies to rootfs"
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)
echo "copying interpreter and dependencies from sysroot ${SYSROOT}"
cp -a ${SYSROOT}/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib/
echo "copying  dynamic libraries"
cp -a ${SYSROOT}/lib64/libm.so.6 ${OUTDIR}/rootfs/lib64/
cp -a ${SYSROOT}/lib64/libresolv.so.2 ${OUTDIR}/rootfs/lib64/
cp -a ${SYSROOT}/lib64/libc.so.6 ${OUTDIR}/rootfs/lib64/
# cp -a ${SYSROOT}/lib64/libgcc_s.so.1 ${OUTDIR}/rootfs/lib64/
# cp -a ${SYSROOT}/lib64/libpthread.so.0 ${OUTDIR}/rootfs/lib64/
# cp -a ${SYSROOT}/lib64/libdl.so.2 ${OUTDIR}/rootfs/lib64/
# cp -a ${SYSROOT}/lib64/libutil.so.1 ${OUTDIR}/rootfs/lib64/
# cp -a ${SYSROOT}/lib64/libnss_files.so.2 ${OUTDIR}/rootfs/lib64/
# cp -a ${SYSROOT}/lib64/libnss_dns.so.2 ${OUTDIR}/rootfs/lib64/
# cp -a ${SYSROOT}/lib64/libnss_compat.so.2 ${OUTDIR}/rootfs/lib64/
# cp -a ${SYSROOT}/lib64/libnss_nis.so.2 ${OUTDIR}/rootfs/lib64/
# cp -a ${SYSROOT}/lib64/libnss_ldap.so.2 ${OUTDIR}/rootfs/lib64/
# cp -a ${SYSROOT}/lib64/libnss_hesiod.so.2 ${OUTDIR}/rootfs/lib64/
# cp -a ${SYSROOT}/lib64/libnss_files.so.2 ${OUTDIR}/rootfs/lib64/
# cp -a ${SYSROOT}/lib64/libnss_dns.so.2 ${OUTDIR}/rootfs/lib64/
# cp -a ${SYSROOT}/lib64/libnss_compat.so.2 ${OUTDIR}/rootfs/lib64/
# cp -a ${SYSROOT}/lib64/libnss_nis.so.2 ${OUTDIR}/rootfs/lib64/
# cp -a ${SYSROOT}/lib64/libnss_ldap.so.2 ${OUTDIR}/rootfs/lib64/


# TODO: Make device nodes
echo "Creating device nodes in rootfs"
sudo rm -rf ${OUTDIR}/rootfs/dev
sudo mkdir -p ${OUTDIR}/rootfs/dev 
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/console c 5 1
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/tty c 5 0
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/tty0 c 4 0
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/ttyS0 c 4 64
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/ttyS1 c 4 65
# TODO: Clean and build the writer utility
echo "Cleaning and building the writer utility"
cd ${FINDER_APP_DIR}
make clean
make CROSS_COMPILE=${CROSS_COMPILE} all
echo "Copying finder related scripts and executables to rootfs"
# TODO: Copy the finder related scripts and executables to the /home directory
cp writer ${OUTDIR}/rootfs/home/
cp finder.sh ${OUTDIR}/rootfs/home/
cp finder-test.sh ${OUTDIR}/rootfs/home/
cp autorun-qemu.sh ${OUTDIR}/rootfs/home/
cp -r ../conf/ ${OUTDIR}/rootfs/home/
cp Makefile ${OUTDIR}/rootfs/home/
cp writer.sh ${OUTDIR}/rootfs/home/
cp writer.c ${OUTDIR}/rootfs/home/

# on the target rootfs
echo "Changing permissions for the scripts in rootfs"
cd ${OUTDIR}/rootfs

# TODO: Chown the root directory
sudo chown -R root:root ${OUTDIR}/rootfs
sudo chmod -R 755 ${OUTDIR}/rootfs
# sudo chmod 1777 ${OUTDIR}/rootfs/tmp
# sudo chmod 1777 ${OUTDIR}/rootfs/var/tmp
# sudo chmod 1777 ${OUTDIR}/rootfs/var/log
# sudo chmod 1777 ${OUTDIR}/rootfs/var/log
# sudo chmod 1777 ${OUTDIR}/rootfs/var/tmp
# sudo chmod 1777 ${OUTDIR}/rootfs/var/log
sudo chmod +rwx ${OUTDIR}/rootfs/home/autorun-qemu.sh
sudo chmod +rwx ${OUTDIR}/rootfs/home/finder.sh
sudo chmod +rwx ${OUTDIR}/rootfs/home/finder-test.sh
sudo chmod +rwx ${OUTDIR}/rootfs/home/writer
sudo chmod +rwx ${OUTDIR}/rootfs/home/writer.c
sudo chmod +rwx ${OUTDIR}/rootfs/home/finder.sh
sudo chmod +rwx ${OUTDIR}/rootfs/home/finder-test.sh
sudo chmod +rwx ${OUTDIR}/rootfs/home/autorun-qemu.sh
sudo chmod +rwx ${OUTDIR}/rootfs/home/conf/*


# TODO: Create initramfs.cpio.gz
echo "Creating initramfs.cpio.gz"
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ${OUTDIR}/initramfs.cpio.gz # Create the initramfs.cpio.gz file from the contents of the rootfs directory
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}/Image # Copy the kernel image to the output directory
