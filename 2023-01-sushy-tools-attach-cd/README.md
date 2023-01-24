## Patch to enable (real) CD attach with sushy-tools instead of download+attach
Based on top of sushy-tools version `0.21.1` - [`commit de5fad7368b192cc4283882d2072c0bb152f9976 (tag: 0.21.1)`](https://opendev.org/openstack/sushy-tools/commit/de5fad7368b192cc4283882d2072c0bb152f9976)

This patch enables in libvirt driver ability to directly attach ISO image into CD-ROM drive instead of default behaviour in sushy-tools so far that downloads the file locally, then uploads it into 'default' pool on hypervisor and mount it as local file.

To enable this functionality you should build container image applying the patch in this directory. When running the container from this image add the option `SUSHY_EMULATOR_VMEDIA_DOWNLOAD_TO_HYPERVISOR = False` into your configuration file (typically `/etc/sushy-emulator.conf`).

### Files

- [Dockerfile](Dockerfile) - for building container image
- [patch-v3.patch](patch-v3.patch) - patch to be used in Dockerfile
- [patch-v3-git.patch](patch-v3-git.patch) - patch agains tag `0.21.1` of https://opendev.org/openstack/sushy-tools

### Sample container image
Container image containing the patch from here can be dowloaded from `quay.io/ofamera_test/sushy-tools:0.21.1-attach-cd-patch` and used as drop-in replacement for `quay.io/metal3-io/sushy-tools:latest`.

~~~
# podman pull quay.io/ofamera_test/sushy-tools:0.21.1-attach-cd-patch
~~~

### Commands for testing attach/detach CD-ROM
Below are sample commands that can be used to eject/insert CD-ROM.

- ejecting CD-ROM
~~~
# curl -k -d '{"Image":"", "Inserted": false}' -H "Content-Type: application/json" -X POST https://localhost:8000/redfish/v1/Managers/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/VirtualMedia/Cd/Actions/VirtualMedia.EjectMedia
~~~
- attaching CD-ROM
~~~
# curl -k -d '{"Image":"https://some.domain.local/Fedora-Server-dvd-x86_64-37-1.7.iso", "Inserted": true}' -H "Content-Type: application/json" -X POST https://localhost:8000/redfish/v1/Managers/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/VirtualMedia/Cd/Actions/VirtualMedia.InsertMedia
~~~

NOTE: Examples below are showing outputs for VM named 'fastvm-rhel-8.7-uefi-31' with UUID 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'.

### Example of attached CD-ROM in default sushy-tools (local file)

Example of attached CD-ROM when `SUSHY_EMULATOR_VMEDIA_DOWNLOAD_TO_HYPERVISOR = True` or not defined at all in configuration file (=original sushy-tools behaviour):
~~~
# virsh dumpxml test-vm
...
<disk type="file" device="cdrom">
  <driver name="qemu" type="raw"/>
  <source file="/var/lib/libvirt/images/Fedora-Server-dvd-x86_64-37-1-7-iso-747b29f5-5058-4f1b-a7b0-d0c6a86834ec.img"/>
  <target dev="sdx" bus="scsi"/>
  <readonly/>
  <address type="drive" controller="0" bus="0" target="0" unit="1"/>
</disk>
...
~~~

~~~
[2023-01-24 09:31:37,696] DEBUG in main: Initialized system resource backed by <sushy_tools.emulator.resources.systems.libvirtdriver.LibvirtDriver object at 0x7fa9f70b4460> driver
[2023-01-24 09:31:37,936] DEBUG in managers: Found manager {'Id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', 'UUID': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', 'Name': 'fastvm-rhel-8.7-uefi-31-Manager'} by UUID aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
/usr/local/lib/python3.9/site-packages/urllib3/connectionpool.py:1045: InsecureRequestWarning: Unverified HTTPS request is being made to host 'some.domain.local'. Adding certificate verification is strongly advised. See: https://urllib3.readthedocs.io/en/1.26.x/advanced-usage.html#ssl-warnings
  warnings.warn(
[2023-01-24 09:31:59,612] DEBUG in vmedia: Fetched image https://some.domain.local/Fedora-Server-dvd-x86_64-37-1.7.iso for aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
[2023-01-24 09:32:08,347] INFO in api_utils: Virtual media placed into device Cd of manager aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee for systems ['aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee']. Image https://some.domain.local/Fedora-Server-dvd-x86_64-37-1.7.iso inserted True
10.88.0.1 - - [24/Jan/2023 09:32:08] "POST /redfish/v1/Managers/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/VirtualMedia/Cd/Actions/VirtualMedia.InsertMedia HTTP/1.1" 204 -
~~~
~~~
[2023-01-24 09:32:53,876] DEBUG in vmedia: Removed local file /tmp/tmpgil62cjh/Fedora-Server-dvd-x86_64-37-1.7.iso for aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
[2023-01-24 09:32:53,876] DEBUG in main: Initialized system resource backed by <sushy_tools.emulator.resources.systems.libvirtdriver.LibvirtDriver object at 0x7fa9f70b4490> driver
[2023-01-24 09:32:54,087] DEBUG in managers: Found manager {'Id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', 'UUID': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', 'Name': 'fastvm-rhel-8.7-uefi-31-Manager'} by UUID aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
[2023-01-24 09:32:54,734] INFO in api_utils: Virtual media ejected from device Cd manager aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee systems ['aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee']
10.88.0.1 - - [24/Jan/2023 09:32:54] "POST /redfish/v1/Managers/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/VirtualMedia/Cd/Actions/VirtualMedia.EjectMedia HTTP/1.1" 204 -
~~~

### Example of attached CD-ROM in patched sushy-tools (remote file)

Example of attached CD-ROM when `SUSHY_EMULATOR_VMEDIA_DOWNLOAD_TO_HYPERVISOR = False`:
~~~
# virsh dumpxml test-vm
...
<disk type="network" device="cdrom">
  <driver name="qemu" type="raw"/>
  <source protocol="https" name="Fedora-Server-dvd-x86_64-37-1.7.iso">
    <host name="some.domain.local" port="443"/>
    <ssl verify="no"/>
  </source>
  <target dev="sdx" bus="scsi"/>
  <readonly/>
  <address type="drive" controller="0" bus="0" target="0" unit="1"/>
</disk>
...
~~~

~~~
[2023-01-24 09:34:47,983] DEBUG in main: Initialized system resource backed by <sushy_tools.emulator.resources.systems.libvirtdriver.LibvirtDriver object at 0x7fe734ea6430> driver
[2023-01-24 09:34:48,201] DEBUG in managers: Found manager {'Id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', 'UUID': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', 'Name': 'fastvm-rhel-8.7-uefi-31-Manager'} by UUID aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
[2023-01-24 09:34:48,206] DEBUG in vmedia: Fetched image https://some.domain.local/Fedora-Server-dvd-x86_64-37-1.7.iso for aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
[2023-01-24 09:34:49,155] INFO in api_utils: Virtual media placed into device Cd of manager aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee for systems ['aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee']. Image https://some.domain.local/Fedora-Server-dvd-x86_64-37-1.7.iso inserted True
10.88.0.1 - - [24/Jan/2023 09:34:49] "POST /redfish/v1/Managers/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/VirtualMedia/Cd/Actions/VirtualMedia.InsertMedia HTTP/1.1" 204 -
~~~
~~~
[2023-01-24 09:34:54,499] DEBUG in vmedia: Removed local file https://some.domain.local/Fedora-Server-dvd-x86_64-37-1.7.iso for aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
[2023-01-24 09:34:54,500] DEBUG in main: Initialized system resource backed by <sushy_tools.emulator.resources.systems.libvirtdriver.LibvirtDriver object at 0x7fe734ea65b0> driver
[2023-01-24 09:34:54,764] DEBUG in managers: Found manager {'Id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', 'UUID': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', 'Name': 'fastvm-rhel-8.7-uefi-31-Manager'} by UUID aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
[2023-01-24 09:34:55,454] INFO in api_utils: Virtual media ejected from device Cd manager aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee systems ['aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee']
10.88.0.1 - - [24/Jan/2023 09:34:55] "POST /redfish/v1/Managers/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/VirtualMedia/Cd/Actions/VirtualMedia.EjectMedia HTTP/1.1" 204 -
~~~

### Building the container image
This will be built on top of `registry.hub.docker.com/library/python:3.9-slim`. NOTE: `quay.io/metal3-io/sushy-tools:latest` is currently built from `registry.hub.docker.com/library/python:3.9`.

Below commands will upload resulting image to `quay.io/ofamera_test/sushy-tools:0.21.1-attach-cd-patch` - adjust this to match your environment where you can upload images.

~~~
# ls -1
Dockerfile
patch-v3.patch
# podman build -t quay.io/ofamera_test/sushy-tools:0.21.1-attach-cd-patch .
...
Successfully tagged localhost/sushy-tools:0.21.1-attach-cd-patch
61f1010c5aa809ada657bfcf056f9aa558feb506adc5404e2b7f4eb18060eb73
# podman images
REPOSITORY                              TAG                     IMAGE ID      CREATED        SIZE
quay.io/ofamera_test/sushy-tools        0.21.1-attach-cd-patch  61f1010c5aa8  4 minutes ago  354 MB
~~~
~~~
# podman login quay.io
# podman push --format v2s1 quay.io/ofamera_test/sushy-tools:0.21.1-attach-cd-patch
~~~
