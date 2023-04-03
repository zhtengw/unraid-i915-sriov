#!/bin/bash
CURDIR=$(pwd)
URTMP=${CURDIR}/tmp
BZROOT=${URTMP}/bzroot
TMPROOT=${CURDIR}/tmproot

download () {
#URVER="6.11.5"
#URVER="6.12.0-rc2"
URVER="$1"
#CHANNEL="stable"
#CHANNEL="test"
#CHANNEL="next"
CHANNEL="$2"
URZIP="unRAIDServer-${URVER}-x86_64.zip"
read -p "Pack base on version ${URVER} in ${CHANNEL}"
# The link is found from https://unraid.net/download
# echo https://unraid-dl.sfo2.cdn.digitaloceanspaces.com/${CHANNEL}/${URZIP}
if ! wget -c https://unraid-dl.sfo2.cdn.digitaloceanspaces.com/${CHANNEL}/${URZIP} ; then
  exit 1
fi
}

unpack_bzroot() {
BZROOT=$1;
if [ -z "${BZROOT}" ] || [ ! -e ${BZROOT} ];
then
    echo "Path for bzroot not provided."
    exit
fi

EXTDIR=$2
SKIPBLK=$(cpio -ivt -H newc < ${BZROOT} 2>&1 > /dev/null | awk '{print $1}')

echo "Skip ${SKIPBLK} to extract "${BZROOT};

mkdir ${TMPROOT}
# Extract ${EXTDIR}
		dd if=${BZROOT} bs=512 skip=${SKIPBLK} | xzcat | (cd ${TMPROOT}; cpio -i -d -H newc --no-absolute-filenames ${EXTDIR} ) 
}

kernel_prepare() {
if ! download $@ ;then
  echo error;
fi
unzip ${URZIP} -d ${URTMP}

# Extract usr/src
if [[ ${URVER} > "6.12" ]];
then
	EXTDIR="src"
	mkdir -p ${TMPROOT}/usr
	unsquashfs -d tmproot/usr -q ${URTMP}/bzfirmware -extract-file ${EXTDIR}
else
	EXTDIR="usr/src/linux-*"
	unpack_bzroot ${BZROOT} ${EXTDIR}
fi

KERNAME=$(ls ${TMPROOT}/usr/src/)
KERVER=$(echo ${KERNAME} | cut -d'-' -f2)
KERVERUR=$(echo ${KERNAME} | cut -d'-' -f2-)
KERVERM=$(echo ${KERVER} | cut -d'.' -f1)

# Download source from kernel.org
wget -c  https://cdn.kernel.org/pub/linux/kernel/v${KERVERM}.x/linux-${KERVER}.tar.xz

tar xf linux-${KERVER}.tar.xz

cp -r ${TMPROOT}/usr/src/${KERNAME}/* linux-${KERVER}/
cp -r ${TMPROOT}/usr/src/${KERNAME}/.config linux-${KERVER}/

cd linux-${KERVER}
for patch in $(ls ./*.patch)
do
    patch -p1 < ${patch}
done

cd ../
mv linux-${KERVER} ${KERNAME}

# Kernel prepare
cd ${KERNAME}
if [[ ${URVER} < "6.12" ]] && [[ ${URVER} > "6.11" ]];
then
	patch -p0 < ${CURDIR}/config-5.19-enable-pxp.patch
fi
make oldconfig
make modules_prepare
cd ${CURDIR}

echo "Kernel source ${KERNAME} prepared."
}

# Compile kernel
#cp config-${KERVERUR} ${KERNAME}/.config
#cd ${KERNAME}
#make -j4
#make INSTALL_MOD_PATH=${CURDIR}/tmpmodules modules_install
#cd ${CURDIR}
##cp -r /lib/modules/${KERVERUR} tmpmodules

build_i915(){
kernel_prepare $@
# Build i915-sriov module
if [[ ${URVER} > "6.12" ]];then
	git clone -b master https://github.com/zhtengw/i915-sriov-dkms.git
elif [[ ${URVER} > "6.11" ]];then
	git clone -b 5.19 https://github.com/zhtengw/i915-sriov-dkms.git
else
	git clone -b 5.15 https://github.com/zhtengw/i915-sriov-dkms.git
fi
cd i915-sriov-dkms
make -j4 -C ${CURDIR}/${KERNAME} M=${CURDIR}/i915-sriov-dkms KVER=${KERVER}
xz i915.ko
cd ${CURDIR}
mkdir -p tmpplugin/lib/modules/${KERVERUR}/kernel/drivers/gpu/drm/i915
cp i915-sriov-dkms/i915.ko.xz tmpplugin/lib/modules/${KERVERUR}/kernel/drivers/gpu/drm/i915

if [[ ${URVER} < "6.11" ]];then
    mkdir -p tmpplugin/lib/firmware/i915/
    wget -c https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/i915/tgl_guc_70.bin -O tmpplugin/lib/firmware/i915/tgl_guc_70.bin
fi

# Make i915 package
PKGNAME="i915-sriov"
PKGARCH="x86_64"
PKGBUILD="2"
if [[ ! -e makepkg ]];
then
	bash unraid_unpack_bzroot.sh ${BZROOT} sbin/makepkg
	cp ${TMPROOT}/sbin/makepkg ${CURDIR}
fi
mkdir -p packages
cd tmpplugin
#${CURDIR}/makepkg --linkadd y --chown y ${CURDIR}/packages/${PKGNAME}-${KERVERUR}-${PKGARCH}-${PKGBUILD}.txz
${CURDIR}/makepkg --linkadd y --chown y ${CURDIR}/packages/${PKGNAME}-${KERVERUR}.txz
cd ${CURDIR}/packages
md5sum ${PKGNAME}-${KERVERUR}.txz > ${PKGNAME}-${KERVERUR}.txz.md5
cd ${CURDIR}
}

# Get new kernel image after building
#cp ${KERNAME}/arch/x86/boot/bzImage ./bzimage
#sha256sum bzimage > bzimage.sha256
#
# Extract bzmodules
#rdsquashfs -q -u / -p tmpmodules bzmodules # with squashfs-tools-ng
#unsquashfs -d tmpmodules -q bzmodules # with squashfs-tools
# 
# Generate new bzmodules 
##gensquashfs -q -D tmpmodules  bzmodules # with squashfs-tools-ng
#mksquashfs tmpmodules bzmodules -quiet -comp xz # with squashfs-tools
#sha256sum bzmodules > bzmodules.sha256

clean() {
# Clean up
if [ -z ${CURDIR} ];then
  exit 1;
fi
if [ -e ${CURDIR}/tmproot ];then
  /bin/rm -r ${CURDIR}/tmproot
fi
if [ -e ${CURDIR}/tmpmodules ];then
  /bin/rm -r ${CURDIR}/tmpmodules
fi
if [ -e ${CURDIR}/tmpplugin ];then
  /bin/rm -r ${CURDIR}/tmpplugin
fi
if [ -e ${CURDIR}/tmp ];then
  /bin/rm -r ${CURDIR}/tmp
fi
if [ -n "${KERNAME}" ] && [ -e ${CURDIR}/${KERNAME} ];then
  /bin/rm -r ${CURDIR}/${KERNAME}
fi
if [ -e ${CURDIR}/i915-sriov-dkms ];then
  /bin/rm -r ${CURDIR}/i915-sriov-dkms
fi
}

$@
clean
