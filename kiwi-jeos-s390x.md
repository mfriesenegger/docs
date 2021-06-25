# Using kiwi to build s390x images

The intent is to document building kiwi images for multiple deployment options.

- SLES KVM qcow2 JeOS images
- SLES JeOS images for ECKD, FBA(EDEV) and FCP(SCSI) for z/VM and LPAR

The scope of this document is open ended to included info on:

- cloud-init enablement
- firstboot configurations
- etc...

The kiwi definitions will work for all service packs of a SLES version.  The definitions have been tested mostly with SLES12 SP5, SLES15 SP1 SLES15 SP2.  

## kiwi information

- http://osinside.github.io/kiwi/

## Setup a VM where kiwi will build images

**RECOMMENDATION:**  Install and use kiwi on a z/VM guest for DASD, FBA and FCP images.  Install and use kiwi builder on KVM VM for qcow2 and FCP images.  Other combinations may work but builds might fail.  An example failure is building a SLES 12 SP5 FBA image on a SLES15 SP2 KVM VM where the latest kiwi is installed will cause an image build time error.

- Install SLES15 SP2 or later in VM where kiwi will be installed and run
  - Recommended to use SLES15 SP2 s390x or newer for the KVM host
- Register with SCC

  ```
  SUSEConnect -p sle-module-desktop-applications/15.2/s390x
  SUSEConnect -p sle-module-development-tools/15.2/s390x
  ```

- Fully patch the SLES15 SP2 VM
- **NOTE: If kpartx-0.8.2+140.5146cae-4.3.1 is installed then replace with older kpartx-0.8.2+18.9ff73e7-2.1**
  - This latest kpartx version does not work properly recognize a 4K virtual DASD file - [bug 1139775](https://bugzilla.suse.com/show_bug.cgi?id=1139775)
- Install kiwi

  ```
  zypper in python3-kiwi kiwi-tools kiwi-templates-SLES15-JeOS kiwi-man-pages kiwi-boot-descriptions dracut-kiwi-overlay dracut-kiwi-lib
  ```
    - **NOTE: Verify kiwi version is 9.21.20 or newer. If not then add the repo used for testing so DASD support fixes are available**

- **FOR TESTING:** Update kiwi with the latest at https://build.opensuse.org/package/show/Virtualization:Appliances:Builder/python-kiwi

  ```
  zypper ar -fc https://download.opensuse.org/repositories/Virtualization:/Appliances:/Builder/SLE_15_SP2/ kiwi
  ```

## Build a SLES JeOS qcow2 image

The JeOS kiwi template is from the following packages but adapted to build on s390x.

- kiwi-templates-SLES12-JeOS-12.5-6.3.1.noarch for SLES12 SP5
- kiwi-templates-SLES15-JeOS-15-37.5.1.noarch for SLES15 SP1

The following will build a SLES12 SP5 qcow2 image without firstboot or cloud-init to customize the image on initial boot.  Adapt the kiwi-ng command to build a SLES15 SP2 image.

- Copy the kiwi definitions to the kiwi build VM

```
cp -a /root/docs-private/suse-SLE12-Enterprise-JeOS-s390x /root
cp -a /root/docs-private/suse-SLE15-Enterprise-JeOS-s390x /root
```

- To build with kiwi in one step

```
kiwi-ng --logfile kiwi-12sp5-kvm-build.txt --profile kvm system build --description /root/suse-SLE12-Enterprise-JeOS-s390x/ --target-dir /tmp/kiwi-12sp5-kvm
```

- Copy the qcow2 image file to the KVM host to verify it boots.  This document assumes you know how to create and start a KVM VM for this test.

## Build a SLES JeOS qcow2 image with cloud-init

The kiwi definitions used for this section are based on the definitions from the **Build a SLES JeOS qcow2 image** section.  If the **Build a SLES JeOS qcow2 image** section was tested on the kiwi build VM then the instructions in italics can be skipped.

- _Copy the kiwi definitions to the kiwi build VM_

```
cp -a /root/docs-private/suse-SLE12-Enterprise-JeOS-s390x /root
cp -a /root/docs-private/suse-SLE15-Enterprise-JeOS-s390x /root
```

- To build with kiwi in two steps

```
kiwi-ng --logfile kiwi-12sp5-kvm-prepare.txt --profile OpenStack-Cloud system prepare --description /root/suse-SLE12-Enterprise-JeOS-s390x/ --root /tmp/kiwi-12sp5-kvm/build/image-root
kiwi-ng --logfile kiwi-12sp5-kvm-create.txt --profile OpenStack-Cloud system create --root /tmp/kiwi-12sp5-kvm/build/image-root --target-dir /tmp/kiwi-12sp5-kvm
```

- Copy the qcow2 image file to the KVM host to verify it boots.  This document assumes you know how to create and start a KVM VM for this test.

## Build a SLES JeOS oem dasd eckd image

The oem dasd eckd raw image file will be deployed using dd over a ssh connection from the kiwi build host to a target Z system.  Deployment of an image has been tested to ECKD DASD minidisks attach to a z/VM guest.  A deployment to ECKD DASD attached to a Z LPAR has not been tested at this time.

The steps in this section builds on the information presented in the previous sections but has significant differences.

- Use kiwi-ng to build an image using the oem-dasd profile

- Boot the target Z system into SLES15 SP2 rescue mode and enable the eckd dasd.  

  - For a z/VM guest use the following parmfile example to boot into rescue mode.
```
InstNetDev=osa OsaInterface=qdio Layer2=1 PortNo=0 OSAHWAddr=         
HostIP=10.161.128.6/20 Hostname=limgdflt.suse.de language=en_US
Gateway=10.161.143.254 Nameserver=10.160.0.1 Domain=suse.de           
ReadChannel=0.0.1000 WriteChannel=0.0.1001 DataChannel=0.0.1002       
install=ftp://dist.suse.de/install/SLP/SLE-15-SP2-Full-GM/s390x/DVD1/
ssh=1 sshpassword=suserocks rescue=1
```
  - Use ```chzdev dasd -e <device number>``` to enable the dasd device as /dev/dasda.

- The following command simplifies the deployment of the bootable image file.  The script must be copied from docs-private/bin to /root/bin. The target Z system where the image will be deployed must be booted into rescue mode with the target DASD enabled.  The command requires two parameters. The command will show additional usage details if any of the required parameters are missing.
  - The first parameter is the path to the bootable raw file.
  - The second parameter is the IP address of the guest the image will be deployed.
  - The third parmeter is sector size which is optional and either 512 or 4096. The default is 512 if nothing is specified.

```
deploy-oem-image.sh /tmp/kiwi-15sp2-dasd-xfs/SLES15-SP2-JeOS.s390x-15.2.raw 10.161.128.6 4096
```

- Once the image is deployed, shutdown the Z system running rescue mode and IPL the boot device to confirm that the deployed image boots properly.

## Build a SLES JeOS oem fba edev image

The steps in this section build on the information presented in the previous section.

The biggest difference between this section and the dasd eckd image section is the profile used for the kiwi image definition.  Once the fba image is built, it will be deployed in a similar method like the dasd eckd image.

Be aware of the following items when building and deploying a fba image:

- Be sure to pull the latest from this github project.
- The kiwi profile to use is named **oem-fba**.
- Use the kiwi-ng command examples from previous sections to build this image.
- Specify 512 or do not specify the third option when using deploy-oem-image.sh to deploy an image.
