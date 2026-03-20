#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -eu
#export PATH=$PATH:$HOME/arm-cross-compiler/arm-gnu-toolchain-13.3.rel1-x86_64-aarch64-none-linux-gnu/bin

# Output directory (can be overridden by the first CLI argument)
OUTDIR=/tmp/aeld

# Kernel and BusyBox sources
#KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1

# Select BusyBox mode:
# 1 = static BusyBox (no shared libs required)
# 0 = dynamic BusyBox (requires copying loader + libs)
BUSYBOX_STATIC=1


# Project app directory (holds writer.c, finder.sh, etc.)
FINDER_APP_DIR=$(realpath "$(dirname "$0")")

# Target architecture and toolchain prefix
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

# Allow overriding OUTDIR via CLI
if [ $# -lt 1 ]; then
    echo "Using default directory ${OUTDIR} for output"
else
    OUTDIR=$1
    echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p "${OUTDIR}"

echo "Preparing Kernel......"
cd "${OUTDIR}"
# Clone only if the repository does not exist
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
    git -c http.sslVerify=false clone "${KERNEL_REPO}" --depth 1 --single-branch --branch "${KERNEL_VERSION}"
fi

# Prepare image file if it doesn't exist
if [ ! -e "${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image" ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout "${KERNEL_VERSION}"

    # Kernel build steps
    echo "Cleaning and configuring kernel for ${ARCH}"
    make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" mrproper
    make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" defconfig

    echo "Building kernel Image, modules and dtbs"
    make -j"$(nproc)" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" Image modules dtbs

    echo "Kernel build done"
fi

echo "Adding the Image in outdir"
cp -u "${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image" "${OUTDIR}/Image" || true

echo "Preparing Root filesystem......"
echo "Creating the staging directory for the root filesystem"
cd "${OUTDIR}"
if [ -d "${OUTDIR}/rootfs" ]; then
    echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm -rf "${OUTDIR}/rootfs"
fi

# Create required base directories
mkdir -p "${OUTDIR}/rootfs"
cd "${OUTDIR}/rootfs"
mkdir -p bin sbin lib lib64 etc dev proc sys tmp usr/bin usr/sbin var var/log home

# Prepare Busybox
echo "Preparing BusyBox......"
cd "${OUTDIR}"

if [ ! -d "${OUTDIR}/busybox" ]; then
    git clone https://github.com/mirror/busybox.git
    cd busybox
    git checkout "${BUSYBOX_VERSION}"
    make distclean
else
    cd busybox
fi

# BusyBox default config
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" defconfig

# Apply build static or dinamic
if [ "${BUSYBOX_STATIC}" -eq 1 ]; then
    echo "Configuring BusyBox for STATIC build"
    sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
else
    echo "Configuring BusyBox for DYNAMIC build"
    sed -i 's/^CONFIG_STATIC=y/# CONFIG_STATIC is not set/' .config
fi

# Compile BusyBox
make -j"$(nproc)" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}"

# Install in rootfs
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" \
     CONFIG_PREFIX="${OUTDIR}/rootfs" install

# Lib copy for busybox dinamic
if [ "${BUSYBOX_STATIC}" -eq 0 ]; then

    # Show library dependencies of installed BusyBox
    echo "Library dependencies of dynamic BusyBox:"
    "${CROSS_COMPILE}"readelf -a "${OUTDIR}/rootfs/bin/busybox" | \
        grep "program interpreter" || true
    "${CROSS_COMPILE}"readelf -a "${OUTDIR}/rootfs/bin/busybox" | \
        grep "Shared library" || true

    echo "Copying dynamic loader & libraries"

    SYSROOT=$("${CROSS_COMPILE}"gcc -print-sysroot)
    echo "Using toolchain sysroot: ${SYSROOT}"

    # Loader dinamic
    if [ -f "${SYSROOT}/lib/ld-linux-aarch64.so.1" ]; then
        cp -u "${SYSROOT}/lib/ld-linux-aarch64.so.1" "${OUTDIR}/rootfs/lib/"
    elif [ -f "${SYSROOT}/lib64/ld-linux-aarch64.so.1" ]; then
        cp -u "${SYSROOT}/lib64/ld-linux-aarch64.so.1" "${OUTDIR}/rootfs/lib64/"
    fi

    # Copy shared libraries
    echo "Copying shared libraries required by BusyBox"
    LIBS=$(
        "${CROSS_COMPILE}"readelf -a "${OUTDIR}/rootfs/bin/busybox" | \
        sed -n 's/.*Shared library: \[\(.*\)\].*/\1/p'
    )

    for L in $LIBS; do
        FOUND=""
        for D in lib64 lib; do
            if [ -f "${SYSROOT}/${D}/${L}" ]; then
                cp -u -L "${SYSROOT}/${D}/${L}" "${OUTDIR}/rootfs/${D}/"
                FOUND="yes"
            fi
        done

        if [ -z "$FOUND" ]; then
            F=$(find "${SYSROOT}" -type f -name "${L}" -print -quit 2>/dev/null)
            if [ -n "$F" ]; then
                case "$F" in
                    *"/lib64/"*) DEST="${OUTDIR}/rootfs/lib64/" ;;
                    *"/lib/"*)   DEST="${OUTDIR}/rootfs/lib/" ;;
                    *)           DEST="${OUTDIR}/rootfs/lib64/" ;;
                esac
                cp -u -L "$F" "$DEST"
            else
                echo "WARNING: Library ${L} not found in sysroot"
            fi
        fi
    done

else
    echo "BusyBox is STATIC — no shared libs or loader needed"
fi

echo "Preparing Writer utility......"
# Clean and build the writer utility (static for simplicity)
if [ -f "${FINDER_APP_DIR}/writer.c" ]; then
    echo "Building writer from ${FINDER_APP_DIR}/writer.c"
    "${CROSS_COMPILE}"gcc -Wall -Werror -O2 -static -o "${OUTDIR}/writer" "${FINDER_APP_DIR}/writer.c"
    "${CROSS_COMPILE}"strip "${OUTDIR}/writer" || true
    install -m 0755 "${OUTDIR}/writer" "${OUTDIR}/rootfs/home/writer"
else
    echo "WARNING: ${FINDER_APP_DIR}/writer.c not found; skipping writer build"
fi

echo "Preparing finder-related scripts......"
# Copy the finder-related scripts and files to /home in the rootfs
mkdir -p "${OUTDIR}/rootfs/home/conf"
if [ -f "${FINDER_APP_DIR}/finder.sh" ]; then
    install -m 0755 "${FINDER_APP_DIR}/finder.sh" "${OUTDIR}/rootfs/home/finder.sh"
fi
if [ -f "${FINDER_APP_DIR}/finder-test.sh" ]; then
    install -m 0755 "${FINDER_APP_DIR}/finder-test.sh" "${OUTDIR}/rootfs/home/finder-test.sh"
fi
if [ -f "${FINDER_APP_DIR}/autorun-qemu.sh" ]; then
    install -m 0755 "${FINDER_APP_DIR}/autorun-qemu.sh" "${OUTDIR}/rootfs/home/autorun-qemu.sh"
fi
if [ -d "${FINDER_APP_DIR}/conf" ]; then
    cp -a "${FINDER_APP_DIR}/conf/" "${OUTDIR}/rootfs/home/conf/"
fi

# Fix ownership to root:root
echo "Setting ownership to root:root"
sudo chown -R root:root "${OUTDIR}/rootfs"

echo "Creating initramfs......"
# Create initramfs.cpio.gz
cd "${OUTDIR}/rootfs"
find . | cpio -H newc -ov --owner root:root > "${OUTDIR}/initramfs.cpio"
cd "${OUTDIR}"
gzip -f -9 initramfs.cpio
echo "Created: ${OUTDIR}/initramfs.cpio.gz"

echo "============ Summary ====================="
echo "Kernel Image:  ${OUTDIR}/Image"
echo "Initramfs:     ${OUTDIR}/initramfs.cpio.gz"
echo "RootFS staged: ${OUTDIR}/rootfs"
echo "Done."
