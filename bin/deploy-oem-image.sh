#!/bin/bash

# TO DO: Enhance script to simplfy working with mandatory and optional parameters

function help {
  echo
  echo "Usage: $0 <raw filename> <ip address> [sector size]
  echo "  where:
  echo "raw filename is patch to raw file created by kiwi"
  echo "ip address of the guest the image will be deployed to"
  echo "sector size is optional and either 512 or 4096 default is 512"
  exit 1
}

if [ ! -e ${1} ]; then
  echo "Exiting because ${1} is not found."
  help
fi

if [ -z ${2} ]; then
  echo "Exiting because missing DASD device information."
  help
fi

if [ -z "$3" -o "$3" = "512" ]; then
  echo "Setting sector size to 512"
  SECTOR_SIZE=512
elif [ "$3" = "4096" ]; then
  echo "Setting sector size to 4096"
  SECTOR_SIZE=4096
else
  echo "Exiting because sector size can only be 512 or 4096."
  help
fi

echo "Ready to deloy ${1}?"
echo -n "y/n "
read answer

if [ $answer = "y" ]; then
  echo "Deploying oem-dasd image"
  ssh-keygen -R ${2} -f /root/.ssh/known_hosts
  losetup --sector-size ${SECTOR_SIZE} -f --show ${1}
  dd if=/dev/loop0 status=progress | ssh root@${2} "dd of=/dev/dasda"
  losetup -d /dev/loop0
fi
