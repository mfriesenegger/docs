# Using kiwi to build s390x images

The intent is to document building kiwi images for multiple deployment options.

- SLES KVM qcow2 JeOS images
- SLES JeOS images for ECKD and FCP (z/VM and LPAR)

The scope of this document is open ended to included info on:

- cloud-init enablement
- firstboot configurations
- etc...

## kiwi information

- http://osinside.github.io/kiwi/

## Setup a KVM VM where kiwi will build images

- Install SLES15 SP1 in KVM guest on KVM SLES15SP1 s390x host
- Register with SCC

  ```
  SUSEConnect -p sle-module-desktop-applications/15.1/s390x
  SUSEConnect -p sle-module-development-tools/15.1/s390x
  ```

- Install kiwi

  ```
  zypper in python3-kiwi kiwi-tools kiwi-templates-SLES15-JeOS kiwi-man-pages kiwi-boot-descriptions dracut-kiwi-overlay dracut-kiwi-lib
  ```


## Build a SLES JeOS qcow2 image

The JeOS kiwi template is from the following packages but adapted to build on s390x.

- kiwi-templates-SLES12-JeOS-12.5-6.3.1.noarch for SLES12 SP5
- kiwi-templates-SLES15-JeOS-15-37.5.1.noarch for SLES15 SP1

The following will build a SLES12 SP5 qcow2 image without firstboot or cloud-init to customize the image on initial boot.  Adapt the kiwi-ng command to build a SLES15 SP1 image.

- Checkout the highest numbered git tag for this section - https://github.com/mfriesenegger/docs.git must be cloned to /root on the kiwi build VM before using the following commands

```
cd /root/docs-private
git checkout basic-jeos-image
```

- Copy the kiwi definitions to the kiwi build VM

```
cp -a /root/docs-private/suse-SLE12-Enterprise-JeOS-s390x /root
cp -a /root/docs-private/suse-SLE15-Enterprise-JeOS-s390x /root
```

- Copy the following script to /root/bin

```
cp /root/docs-private/bin/make-kiwi-qcow2-boot.sh /root/bin
```

- Verify execute permission for /root/bin/make-kiwi-qcow2-boot.sh
- To build with kiwi in one step

```
kiwi-ng --logfile kiwi-12sp5-kvm-build.txt --profile kvm system build --description /root/suse-SLE12-Enterprise-JeOS-s390x/ --target-dir /tmp/kiwi-12sp5-kvm
```

- The following command requires one parameter which is the path to the qcow2 file built by kiwi-ng.

```
make-kiwi-qcow2-boot.sh /tmp/kiwi-12sp5-kvm/SLES12-SP5-JeOS.s390x-12.5.qcow2
```

- Copy the qcow2 image file to the KVM host to verify it boots.  This document assumes you know how to create and start a KVM VM for this test.

## Build a SLES JeOS qcow2 image with cloud-init

The kiwi definitions used for this section are based on the definitions from the **Build a SLES JeOS qcow2 image** section.  If the **Build a SLES JeOS qcow2 image** section was tested on the kiwi build VM then the instructions in italics can be skipped.

- Checkout the highest numbered git tag for this section - _https://github.com/mfriesenegger/docs.git must be cloned to /root on the kiwi build VM before using the following commands_

```
cd /root/docs-private
git tag | grep cloud-init-jeos-image
git checkout cloud-init-jeos-image
```

- Copy the kiwi definitions to the kiwi build VM

```
cp -a /root/docs-private/suse-SLE12-Enterprise-JeOS-s390x /root
cp -a /root/docs-private/suse-SLE15-Enterprise-JeOS-s390x /root
```

- _Copy the following script to /root/bin_

```
cp /root/docs-private/bin/make-kiwi-qcow2-boot.sh /root/bin
```

- _Verify execute permission for /root/bin/make-kiwi-qcow2-boot.sh_
- To build with kiwi in two steps

```
kiwi-ng --logfile kiwi-12sp5-kvm-prepare.txt --profile OpenStack-Cloud system prepare --description /root/suse-SLE12-Enterprise-JeOS-s390x/ --root /tmp/kiwi-12sp5-kvm/build/image-root
kiwi-ng --logfile kiwi-12sp5-kvm-create.txt --profile OpenStack-Cloud system create --root /tmp/kiwi-12sp5-kvm/build/image-root --target-dir /tmp/kiwi-12sp5-kvm
```

- The following command requires one parameter which is the path to the qcow2 file built by kiwi-ng.

```
make-kiwi-qcow2-boot.sh /tmp/kiwi-12sp5-kvm/SLES12-SP5-JeOS.s390x-12.5.qcow2
```

- Copy the qcow2 image file to the KVM host to verify it boots.  This document assumes you know how to create and start a KVM VM for this test.
