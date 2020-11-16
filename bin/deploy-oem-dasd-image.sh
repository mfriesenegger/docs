#!/bin/bash

if [ ! -e ${1} ]; then
  echo "Exiting because ${1} is not found."
  exit 1
fi

if [ -z ${2} ]; then
  echo "Exiting because missing DASD device information."
  echo
  echo "Usage: $0 <raw filename> <ip address>
  echo "  where:
  echo "raw filename is patch to raw file created by kiwi"
  echo "ip address of the guest the image will be deployed to"
  exit 1
fi

echo "Ready to deloy ${1}?"
echo -n "y/n "
read answer

if [ $answer = "y" ]; then
  echo "Deploying oem-dasd image"
  ssh-keygen -R ${2} -f /root/.ssh/known_hosts
  losetup --sector-size 4096 -f --show ${1}
  dd if=/dev/loop0 status=progress | ssh root@${2} "dd of=/dev/dasda"
  losetup -d /dev/loop0
fi
