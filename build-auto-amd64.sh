export ARCH='amd64'
# Install dependencies to build MTR
apt-get update
apt-get install -y --no-install-recommends wget gawk debootstrap mtools xorriso ca-certificates curl libusb-1.0-0-dev gcc make gzip xz-utils unzip libc6-dev

# Get proper files
if [ "$1" = "RELEASE" ]; then
    case "$ARCH" in
        'amd64')
            ROOTFS='https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/x86_64/alpine-minirootfs-3.17.3-x86_64.tar.gz'
            PALERA1N="https://github.com/palera1n/palera1n/releases/download/v2.0.0-beta.8/palera1n-linux-x86_64"
            ;;
        'i686')
            ROOTFS='https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/x86/alpine-minirootfs-3.17.3-x86.tar.gz'
            PALERA1N="https://github.com/palera1n/palera1n/releases/download/v2.0.0-beta.8/palera1n-linux-x86"
            ;;
        'aarch64')
            ROOTFS='https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/aarch64/alpine-minirootfs-3.17.3-aarch64.tar.gz'
            PALERA1N="https://github.com/palera1n/palera1n/releases/download/v2.0.0-beta.8/palera1n-linux-arm64"
            ;;
        'armv7')
            ROOTFS='https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/armv7/alpine-minirootfs-3.17.3-armv7.tar.gz'
            PALERA1N="https://github.com/palera1n/palera1n/releases/download/v2.0.0-beta.8/palera1n-linux-armel"
            ;;
    esac
    echo "INFO: RELEASE CHOSEN"
elif [ 1 = 1 ]; then


    url="https://cdn.nickchan.lol/palera1n/artifacts/c-rewrite/main/"
    latest_build=0
    html=$(curl -s "$url")
    latest_build=$(echo "$html" | awk -F'href="' '{print $2}' | awk -F'/' 'NF>1{print $1}' | sort -nr | head -1)

     case "$ARCH" in
        'amd64')
            ROOTFS='https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/x86_64/alpine-minirootfs-3.17.3-x86_64.tar.gz'
            PALERA1N="https://cdn.nickchan.lol/palera1n/artifacts/c-rewrite/main/$latest_build/palera1n-linux-x86_64"
            ;;
        'i686')
            ROOTFS='https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/x86/alpine-minirootfs-3.17.3-x86.tar.gz'
            PALERA1N="https://cdn.nickchan.lol/palera1n/artifacts/c-rewrite/main/$latest_build/palera1n-linux-x86"
            ;;
        'aarch64')
            ROOTFS='https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/aarch64/alpine-minirootfs-3.17.3-aarch64.tar.gz'
            PALERA1N="https://cdn.nickchan.lol/palera1n/artifacts/c-rewrite/main/$latest_build/palera1n-linux-arm64"
            ;;
        'armv7')
            ROOTFS='https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/armv7/alpine-minirootfs-3.17.3-armv7.tar.gz'
            PALERA1N="https://cdn.nickchan.lol/palera1n/artifacts/c-rewrite/main/$latest_build/palera1n-linux-armel"
            ;;
    esac
    echo "INFO: NIGHTLY CHOSEN"
elif [[ -z "$BUILD_TYPE" ]]; then
    echo "ERROR: NO BUILD TYPE CHOSEN"
    exit 1
fi

# Clean up previous attempts
umount -v work/rootfs/{dev,sys,proc} >/dev/null 2>&1
rm -rf work
mkdir -pv work/{rootfs,iso/boot/grub}
cd work

# Fetch ROOTFS
curl -sL "$ROOTFS" | tar -xzC rootfs
mount -vo bind /dev rootfs/dev
mount -vt sysfs sysfs rootfs/sys
mount -vt proc proc rootfs/proc
cp /etc/resolv.conf rootfs/etc
cat << ! > rootfs/etc/apk/repositories
http://dl-cdn.alpinelinux.org/alpine/v3.12/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
!

sleep 2
# ROOTFS packages & services
cat << ! | chroot rootfs /usr/bin/env PATH=/usr/bin:/usr/local/bin:/bin:/usr/sbin:/sbin /bin/sh
apk update
apk upgrade
apk add bash alpine-base usbmuxd ncurses udev openssh-client sshpass newt
apk add --no-scripts linux-lts linux-firmware-none
wget http://dl-cdn.alpinelinux.org/alpine/v3.18/main/x86_64/cfdisk-2.38.1-r8.apk
apk add --allow-untrusted cfdisk-2.38.1-r8.apk
apk add lsblk
apk add nano
apk add nano
rc-update add bootmisc
rc-update add hwdrivers
rc-update add udev
rc-update add udev-trigger
rc-update add udev-settle
!

# kernel modules
cat << ! > rootfs/etc/mkinitfs/features.d/palen1x.modules
kernel/drivers/usb/host
kernel/drivers/hid/usbhid
kernel/drivers/hid/hid-generic.ko
kernel/drivers/hid/hid-cherry.ko
kernel/drivers/hid/hid-apple.ko
kernel/net/ipv4
!
chroot rootfs /usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin \
	/sbin/mkinitfs -F "palen1x" -k -t /tmp -q $(ls rootfs/lib/modules)
rm -rfv rootfs/lib/modules
mv -v rootfs/tmp/lib/modules rootfs/lib
find rootfs/lib/modules/* -type f -name "*.ko" -exec strip -v --strip-unneeded {} \; -exec xz --x86 -v9eT0 \;
depmod -b rootfs $(ls rootfs/lib/modules)

# Echo TUI configurations
echo 'MTR' > rootfs/etc/hostname
echo "PATH=$PATH:$HOME/.local/bin" > rootfs/root/.bashrc # d
echo "export MTR_VERSION='$VERSION'" > rootfs/root/.bashrc
echo '/usr/bin/mtr_menu' >> rootfs/root/.bashrc
echo "Rootless" > rootfs/usr/bin/.jbtype
echo "" > rootfs/usr/bin/.args

# Unmount fs
umount -v rootfs/{dev,sys,proc}

# Fetch palera1n-c
curl -Lo rootfs/usr/bin/palera1n "$PALERA1N"
chmod +x rootfs/usr/bin/palera1n

# Copy files
cp -av ../inittab rootfs/etc
cp -v ../scripts/* rootfs/usr/bin
chmod -v 755 rootfs/usr/local/bin/*
ln -sv sbin/init rootfs/init
ln -sv ../../etc/terminfo rootfs/usr/share/terminfo # fix ncurses

# Boot config
cp -av rootfs/boot/vmlinuz-lts iso/boot/vmlinuz
cat << ! > iso/boot/grub/grub.cfg
insmod all_video
echo 'palen1x $VERSION'
linux /boot/vmlinuz quiet loglevel=3
initrd /boot/initramfs.xz
boot
!

# initramfs
pushd rootfs
rm -rfv tmp/* boot/* var/cache/* etc/resolv.conf
find . | cpio -oH newc | xz -C crc32 --x86 -vz9eT$(nproc --all) > ../iso/boot/initramfs.xz
popd

# ISO creation
grub-mkrescue -o "mtr-$ARCH.iso" iso --compress=xz
