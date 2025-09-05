#!/bin/sh
SD_MOUNT="/media/mmcblk0p1"
CONFIG_TXT_APPEND="gpu_mem=32"
POST_UPDATE="rc-service nodered restart"
POST_KERNEL_UPDATE="reboot"
ALPINE_ARCH="`cat /etc/apk/arch`"
ALPINE_BRANCH="`sed -rn 's/http.*\/([0-9|a-z|\-]+)\/main/\1/p' /etc/apk/repositories`"

echo "Packages update"
apk update && apk upgrade && apk cache sync && lbu commit
eval "$POST_UPDATE"

ALPINE_RELEASE="`cat /etc/alpine-release`"
echo "branch: $ALPINE_BRANCH, release: $ALPINE_RELEASE, arch: $ALPINE_ARCH"

if grep -wq "alpine-rpi-$ALPINE_RELEASE" "$SD_MOUNT/.alpine-release"; then 
    echo "No kernel/firmware update required" 
else 
    echo "Kernel/firmware update"
    tmpDir=$(mktemp -d)
    newImgFile="alpine-rpi-$ALPINE_RELEASE-$ALPINE_ARCH.tar.gz"
    cd "$tmpDir"
    wget "http://dl-cdn.alpinelinux.org/alpine/$ALPINE_BRANCH/releases/$ALPINE_ARCH/$newImgFile"
    wget "http://dl-cdn.alpinelinux.org/alpine/$ALPINE_BRANCH/releases/$ALPINE_ARCH/$newImgFile.sha512"
    if sha512sum -c "$newImgFile.sha512"; then
        echo "Kernel download ok"
        archiveDir=${SD_MOUNT}/archive/$(date --utc "+%Y-%m-%dT%H_%M_%S")
        mount -oremount,rw "$SD_MOUNT"
        rm -R ${SD_MOUNT}/archive/*
        mkdir -p "$archiveDir"
        mv "$SD_MOUNT/"* "$SD_MOUNT/".* -t "$archiveDir"
        tar -xzf "$newImgFile" -C "$SD_MOUNT"
        rm -R "$tmpDir"
        cp "$archiveDir/usercfg.txt" "$SD_MOUNT/"
        echo -e "\n$CONFIG_TXT_APPEND" >> "$SD_MOUNT/config.txt" 
        mount -oremount,ro "$SD_MOUNT"
        eval "$POST_KERNEL_UPDATE"
    else
        echo "Kernel download failed"
        rm -R "$tmpDir"
    fi
fi
