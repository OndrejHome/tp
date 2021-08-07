## Systemd service+timer for local Gentoo Portage mirror
Setup below uses ramdisk (tmpfs) for storing gentoo portage mirror.
Downloaded data are therefore not persistent between reboots.
You can skip setup of ramdisk and have data localy if you wish.

procedure below doesn't describe setup of rsync server to serve 
the files that were downloaded. For that follow the [Gentoo Wiki: Infrastructure/Mirrors/Rsync - Serving Data](https://wiki.gentoo.org/wiki/Project:Infrastructure/Mirrors/Rsync#Serving_data).
The service unit file here will retry rsync 30 minutes after fail 
if the verification failed up to 3 times. After 3 fails  manual intervention
(`systemctl reset-failed`) is needed to restore periodical sync.

### Setup
- create user for making sync and copy script for sync ot its home directory
~~~
# useradd -m --uid 1000 gentoo-sync
# cp gentoo-portage-sync-service.sh /home/gentoo-sync/gentoo-portage-sync-service.sh
~~~
- create and mount ramdisk for this user - at present gentoo portage takes up around 500MB of space
~~~
# mkdir /mnt/gentoo-portage
# cat /etc/fstab
...
tmpfs /mnt/gentoo-portage tmpfs nosuid,nodev,size=1g,uid=1000 0 0
# mount /mnt/gentoo-portage
# mount |grep gentoo-portage
tmpfs on /mnt/gentoo-portage type tmpfs (rw,nosuid,nodev,relatime,size=1048576k,uid=1000)
~~~
- copy the service and timer units and reload systemd
~~~
# cp gentoo-portage-sync.service gentoo-portage-sync.timer /etc/systemd/system/
# systemctl daemon-reload
~~~
- test out syncing the repository by starting the service
~~~
# systemctl start gentoo-portage-sync
# journalctl -f -u gentoo-portage-sync
...
Aug 07 12:32:24 xxx bash[yyyyyy]: INFO:root:/mnt/gentoo-portage verified in 36.62 seconds
Aug 07 12:32:24 xxx bash[yyyyyy]: Verification OK
Aug 07 12:32:24 xxx systemd[1]: gentoo-portage-sync.service: Deactivated successfully.
Aug 07 12:32:24 xxx systemd[1]: gentoo-portage-sync.service: Consumed 46.907s CPU time.
~~~
- start and enable the timer for daily sync
~~~
# systemctl enable --now gentoo-portage-sync.timer
# systemctl list-timers gentoo-portage-sync.timer
NEXT                        LEFT     LAST                        PASSED    UNIT                      ACTIVATES
Sun 2021-08-08 02:17:00 KST 13h left Sat 2021-08-07 12:00:09 KST 36min ago gentoo-portage-sync.timer gentoo-portage-sync.service
~~~
