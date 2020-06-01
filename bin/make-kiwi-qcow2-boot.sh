#!/bin/bash

if [ $(file ${1} | grep -c "QEMU QCOW Image") -ne 1 ]; then
  echo "Exiting because ${1} is not a QCOW file."
  exit 1
fi

echo "Continue with making ${1} bootable?"
echo -n "y/n "
read answer

if [ $answer = "y" ]; then
  echo "Will update qcow2 image"
  modprobe nbd max_part=8
  qemu-nbd --connect=/dev/nbd0 ${1}
  mount /dev/nbd0p2 /mnt
  mount /dev/nbd0p1 /mnt/boot/zipl
  mount -o bind /dev /mnt/dev
  mount -o bind /sys /mnt/sys
  mount -o bind /proc /mnt/proc

  echo "#!/bin/bash" > /mnt/root/bin/fixit.sh
  echo "/usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg" >> /mnt/root/bin/fixit.sh
  echo "/usr/sbin/grub2-install" >> /mnt/root/bin/fixit.sh
  echo "cp /boot/zipl/config /boot/zipl/config.orig" >> /mnt/root/bin/fixit.sh
  echo "sed -i '/^:menu/ a targetoffset=2048' /boot/zipl/config" >> /mnt/root/bin/fixit.sh 
  echo "sed -i '/^:menu/ a targetblocksize=512' /boot/zipl/config" >> /mnt/root/bin/fixit.sh
  echo "sed -i '/^:menu/ a targettype=SCSI' /boot/zipl/config" >> /mnt/root/bin/fixit.sh
  echo "sed -i '/^:menu/ a targetbase=/dev/nbd0' /boot/zipl/config" >> /mnt/root/bin/fixit.sh
  echo "/sbin/zipl -c /boot/zipl/config -m menu" >> /mnt/root/bin/fixit.sh
  echo "mv /boot/zipl/config.orig /boot/zipl/config" >> /mnt/root/bin/fixit.sh
  echo "exit" >> /mnt/root/bin/fixit.sh

  chmod +x /mnt/root/bin/fixit.sh
  chroot /mnt /root/bin/fixit.sh
  rm /mnt/root/bin/fixit.sh
  umount /mnt/proc
  umount /mnt/sys
  umount /mnt/dev
  umount /mnt/boot/zipl
  umount /mnt
  qemu-nbd --disconnect /dev/nbd0
  modprobe -r nbd
fi
