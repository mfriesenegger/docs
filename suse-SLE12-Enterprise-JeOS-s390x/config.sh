#!/bin/bash
# Copyright (c) 2015 SUSE LLC
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#======================================
# Functions...
#--------------------------------------
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

set -euxo pipefail

mkdir /var/lib/misc/reconfig_system

#======================================
# Greeting...
#--------------------------------------
echo "Configure image: [$kiwi_iname]-[$kiwi_profiles]..."

#======================================
# add missing fonts
#--------------------------------------
CONSOLE_FONT="lat9w-16.psfu"

echo ** "reset machine settings"
# sed -i 's/^root:[^:]*:/root:*:/' /etc/shadow
rm -f /etc/machine-id \
      /var/lib/zypp/AnonymousUniqueId \
      /var/lib/systemd/random-seed \
      /var/lib/dbus/machine-id
touch /etc/machine-id

#======================================
# SuSEconfig
#--------------------------------------
echo "** Running suseConfig..."
suseConfig

echo "** Running ldconfig..."
/sbin/ldconfig

#======================================
# Setup baseproduct link
#--------------------------------------
suseSetupProduct

#======================================
# Specify default runlevel
#--------------------------------------
baseSetRunlevel 3

#======================================
# Add missing gpg keys to rpm
#--------------------------------------
suseImportBuildKey

#======================================
# Enable sshd
#--------------------------------------
chkconfig sshd on

if [ "${kiwi_profiles}" = "OpenStack-Cloud" ]; then
	# not useful for cloud
	systemctl mask systemd-firstboot.service

	suseInsertService cloud-init-local
	suseInsertService cloud-init
	suseInsertService cloud-config
	suseInsertService cloud-final
else # Not Cloud
	# cloud-init-config-suse does that itself
	baseUpdateSysConfig /etc/sysconfig/network/dhcp DHCLIENT_SET_HOSTNAME yes

	# Enable yast- or jeos-firstboot
	systemctl mask systemd-firstboot.service
	mkdir -p /var/lib/YaST2
	touch /var/lib/YaST2/reconfig_system

	# Enable SuSEfirewall2 if installed
	if rpm -q SuSEfirewall2 >/dev/null; then
		chkconfig SuSEfirewall2 on
		baseUpdateSysConfig /etc/sysconfig/SuSEfirewall2 FW_CONFIGURATIONS_EXT sshd
	fi

	if [ -f "/etc/YaST2/firstboot.xml" ]; then
		# Allow for modified firstboot flow
		if [ -f /etc/YaST2/firstboot-rpi3.xml ]; then
			baseUpdateSysConfig /etc/sysconfig/firstboot FIRSTBOOT_CONTROL_FILE /etc/YaST2/firstboot-rpi3.xml
		fi
		# Make systemd-localed happy
		echo 'LANG=en_US.UTF-8' > /etc/locale.conf
	else
		if rpm -q jeos-firstboot >/dev/null; then
			# use jeos-firstboot.service instead of systemd-firstboot.service
			systemctl enable jeos-firstboot.service
		fi
	fi
fi

# Set GRUB2 to boot graphically (bsc#1097428)
sed -Ei"" "s/#?GRUB_TERMINAL=.+$/GRUB_TERMINAL=gfxterm/g" /etc/default/grub
sed -Ei"" "s/#?GRUB_GFXMODE=.+$/GRUB_GFXMODE=auto/g" /etc/default/grub

# Not sure which of those is effective now.
baseUpdateSysConfig /etc/sysconfig/console CONSOLE_FONT "$CONSOLE_FONT"
echo FONT="$CONSOLE_FONT" >> /etc/vconsole.conf

# Workarounds for bsc#1104077
baseUpdateSysConfig /etc/sysconfig/language RC_LANG "en_US.UTF-8"
echo KEYMAP=us >> /etc/vconsole.conf

#======================================
# SSL Certificates Configuration
#--------------------------------------
echo '** Rehashing SSL Certificates...'
update-ca-certificates

if [ ! -s /var/log/zypper.log ]; then
	> /var/log/zypper.log
fi

#======================================
# Import trusted rpm keys
#--------------------------------------
for i in /usr/lib/rpm/gnupg/keys/gpg-pubkey*asc; do
    # importing can fail if it already exists
    rpm --import $i || true
done

# only for debugging
#systemctl enable debug-shell.service

#=====================================
# Configure snapper
#-------------------------------------
if [ "${kiwi_btrfs_root_is_snapshot-false}" = 'true' ]; then
        echo "creating initial snapper config ..."
        # we can't call snapper here as the .snapshots subvolume
        # already exists and snapper create-config doens't like
        # that.
        cp /etc/snapper/config-templates/default /etc/snapper/configs/root
        # Change configuration to match SLES12-SP1 values
        sed -i -e '/^TIMELINE_CREATE=/s/yes/no/' /etc/snapper/configs/root
        sed -i -e '/^NUMBER_LIMIT=/s/50/10/'     /etc/snapper/configs/root

        baseUpdateSysConfig /etc/sysconfig/snapper SNAPPER_CONFIGS root
fi

#=====================================
# Enable ntpd if installed
#-------------------------------------
if [ -f /etc/ntp.conf ]; then
	suseInsertService ntpd
	# Let YaST2 firstboot configure it otherwise
	if ! rpm -q yast2-firstboot >/dev/null; then
		for i in 0 1 2 3; do
			echo "server $i.suse.pool.ntp.org iburst" >> /etc/ntp.conf
		done
	fi
fi

#======================================
# Configure system for IceWM usage
#--------------------------------------
# XXX remove explicit RPi mentioning
if [[ "$kiwi_profiles" == *"X11"* ]] || [[ "$kiwi_profiles" == *"RaspberryPi"* ]]; then
	baseUpdateSysConfig /etc/sysconfig/displaymanager DISPLAYMANAGER xdm
	baseUpdateSysConfig /etc/sysconfig/displaymanager DISPLAYMANAGER_STARTS_XSERVER yes
	baseUpdateSysConfig /etc/sysconfig/windowmanager DEFAULT_WM icewm

	# We want to start in gfx mode
	baseSetRunlevel 5
	suseConfig
fi

#======================================
# Disable recommends on virtual images (keep hardware supplements, see bsc#1089498)
#--------------------------------------
if [[ "$kiwi_profiles" != *"RaspberryPi"* ]]; then
	sed -i 's/.*solver.onlyRequires.*/solver.onlyRequires = true/g' /etc/zypp/zypp.conf
fi

#======================================
# Disable installing documentation
#--------------------------------------
if [[ "$kiwi_profiles" != *"RaspberryPi"* ]]; then
	sed -i 's/.*rpm.install.excludedocs.*/rpm.install.excludedocs = yes/g' /etc/zypp/zypp.conf
fi

#======================================
# Configure Raspberry Pi specifics
#--------------------------------------
if [[ "$kiwi_profiles" == *"RaspberryPi"* ]]; then
	# Add necessary kernel modules to initrd (will disappear with bsc#1084272)
	echo 'add_drivers+=" bcm2835_dma dwc2 "' > /etc/dracut.conf.d/raspberrypi_modules.conf

	# Work around HDMI connector bug and network issues
  	cat > /etc/modprobe.d/50-rpi3.conf <<-EOF
		# No HDMI hotplug available
		options drm_kms_helper poll=0
		# Prevent too many page allocations (bsc#1012449)
		options smsc95xx turbo_mode=N
	EOF
	cat > /usr/lib/sysctl.d/50-rpi3.conf <<-EOF
		# Avoid running out of DMA pages for smsc95xx (bsc#1012449)
		vm.min_free_kbytes = 2048
	EOF

	# Do network configuration via yast2-firstboot
	rm -f /etc/sysconfig/network/ifcfg-eth0

	# Make sure the netconfig md5 files are correct
	netconfig update -f
fi

if [[ "$kiwi_profiles" == *"kvm"* ]]; then
  if rpm -q jeos-firstboot >/dev/null; then
	  #=================================================
	  # Fix efivars in /usr/lib/jeos-firstboot for s390x
	  #-------------------------------------------------
	  sed -i '/^run modprobe efivars$/i if modinfo efivars > /dev/null 2>&1; then' /usr/lib/jeos-firstboot
	  sed -i '/^run modprobe efivars$/a fi' /usr/lib/jeos-firstboot
	  sed -i '/^run modprobe efivars$/c \\trun modprobe efivars' /usr/lib/jeos-firstboot
  fi
fi

# Not compatible with set -e
baseCleanMount || true

exit 0
