# Quay 3.8.6 (aarch64) proof-of-concept deployment guide
Specifics of this guide:
- IMPORTANT: As there is no `quay/quay-rhel8` aarch64 image available, the following cannot be supported by Red Hat.
- Quay image is build based on https://github.com/quay/quay repository tag `v3.8.6` on aarch64 system.
- Quay will be setup with custom SSL certificate (created in this guide)
- Quay configuration file is inspired by `mirror-registry` (https://github.com/quay/mirror-registry) that bundles Quay for use as registry for containers used by OCP installation
  - https://github.com/quay/mirror-registry/blob/v1.3.4/ansible-runner/context/app/project/roles/mirror_appliance/templates/config.yaml.j2

## HW requirements
Based on [Deploy Red Hat Quay for proof-of-concept (non-production) purposes (Quay 3.8) - 2.1. Prerequisites](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html-single/deploy_red_hat_quay_for_proof-of-concept_non-production_purposes/index#poc-prerequisites):
- RHEL 8.8 aarch64 system (this manual assumes minimal installation)
- 2 CPUs (I have used the 2x Cortex-A55@1.8GHz)
- 6GB RAM (quay image itself needs around 4GB RAM to run)
- 10GB disk for installation + more for actual stored data
- access (login+pass) to registry.redhat.io

## Initial OS check and preparations
- ensure that you have enough free disk space
~~~
# df -h /
Filesystem                Size  Used Avail Use% Mounted on
/dev/mapper/r8vg-root_lv  9.1G  1.2G  8.0G  13% /
~~~
- make sure that you have access to `baseos` and `appstream` repositories
~~~
# dnf repolist
...
repo id                            repo name
rhel-8-for-aarch64-appstream-rpms  Red Hat Enterprise Linux 8 for Aarch64 - AppStream (RPMs)
rhel-8-for-aarch64-baseos-rpms     Red Hat Enterprise Linux 8 for Aarch64 - BaseOS (RPMs)
...
~~~
- (recommended) update packages to latest version and freshly reboot OS
~~~
# dnf update
# reboot
~~~

## Quay preparations and installation
- [Deploy Red Hat Quay for proof-of-concept (non-production) purposes (Quay 3.8) - 2.2.2. Installing Podman](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html-single/deploy_red_hat_quay_for_proof-of-concept_non-production_purposes/index#poc-installing-podman) - install podman
~~~
# dnf install podman
~~~

- [Deploy Red Hat Quay for proof-of-concept (non-production) purposes (Quay 3.8) - 2.2.3. Registry authentication](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html-single/deploy_red_hat_quay_for_proof-of-concept_non-production_purposes/index#poc-registry-authentication) - login into `registry.redhat.io`
~~~
# podman login registry.redhat.io
Username: my_username
Password: ****
~~~

- pull the images used in this manual (NOTE: the quay image is custom build, other image versions are based on Quay documentation)
~~~
# podman pull quay.io/ofamera_test/quay:v3.8.6
# podman pull registry.redhat.io/rhel8/postgresql-13:1-109
# podman pull registry.redhat.io/rhel8/redis-6:1-110
~~~
~~~
# podman images
REPOSITORY                              TAG         IMAGE ID      CREATED       SIZE
quay.io/ofamera_test/quay               v3.8.6      4371eb14543b  10 days ago   1.55 GB
registry.redhat.io/rhel8/redis-6        1-110       8db0fcac7b59  3 months ago  326 MB
registry.redhat.io/rhel8/postgresql-13  1-109       cd1185ac78c6  3 months ago  530 MB
~~~

- [Deploy Red Hat Quay for proof-of-concept (non-production) purposes (Quay 3.8) - 2.2.4. Firewall configuration](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html-single/deploy_red_hat_quay_for_proof-of-concept_non-production_purposes/index#poc-firewall-configuration) - configure firewalld
~~~
# firewall-cmd --permanent --add-port=80/tcp
# firewall-cmd --permanent --add-port=443/tcp
# firewall-cmd --permanent --add-port=5432/tcp
# firewall-cmd --permanent --add-port=5433/tcp
# firewall-cmd --permanent --add-port=6379/tcp
# firewall-cmd --reload
~~~

- [Deploy Red Hat Quay for proof-of-concept (non-production) purposes (Quay 3.8) - 2.2.5. IP addressing and naming services](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html-single/deploy_red_hat_quay_for_proof-of-concept_non-production_purposes/index#poc-ip-naming) - for purpose of this manual the IP `192.168.8.33` corresponding to `quay.local` hostname will be sued and added to `/etc/hosts`
~~~
# echo '192.168.8.33 quay.local' >> /etc/hosts
~~~

- [Deploy Red Hat Quay for proof-of-concept (non-production) purposes (Quay 3.8) - 2.3.1. Setting up Postgres](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html-single/deploy_red_hat_quay_for_proof-of-concept_non-production_purposes/index#poc-setting-up-postgres) - configure postgresql container and its storage
~~~
# mkdir /mnt/postgres-quay
# setfacl -m u:26:-wx /mnt/postgres-quay
# getfacl /mnt/postgres-quay
getfacl: Removing leading '/' from absolute path names
# file: mnt/postgres-quay
# owner: root
# group: root
user::rwx
user:26:-wx
group::r-x
mask::rwx
other::r-x
~~~
~~~
# podman create --name postgresql-quay \
  -e POSTGRESQL_USER=quayuser \
  -e POSTGRESQL_PASSWORD=quaypass \
  -e POSTGRESQL_DATABASE=quay \
  -e POSTGRESQL_ADMIN_PASSWORD=adminpass \
  -p 5432:5432 \
  -v /mnt/postgres-quay:/var/lib/pgsql/data:Z \
  registry.redhat.io/rhel8/postgresql-13:1-109
# podman start postgresql-quay
~~~
- wait few moments (10-15s) before executing next command so container has chance to come up
~~~
# podman exec -it postgresql-quay /bin/bash -c 'echo "CREATE EXTENSION IF NOT EXISTS pg_trgm" | psql -d quay -U postgres'
CREATE EXTENSION
~~~
~~~
# podman ps
CONTAINER ID  IMAGE                                         COMMAND         CREATED         STATUS         PORTS                   NAMES
5aea6cde80d4  registry.redhat.io/rhel8/postgresql-13:1-109  run-postgresql  36 seconds ago  Up 19 seconds  0.0.0.0:5432->5432/tcp  postgresql-quay
~~~

- [Deploy Red Hat Quay for proof-of-concept (non-production) purposes (Quay 3.8) - 2.4.1. Setting up Redis](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html-single/deploy_red_hat_quay_for_proof-of-concept_non-production_purposes/index#poc-setting-up-redis) - create and start redis container
~~~
# podman create --name redis \
  -p 6379:6379 \
  -e REDIS_PASSWORD=strongpassword \
  registry.redhat.io/rhel8/redis-6:1-110
# podman start redis
~~~
~~~
# podman ps
CONTAINER ID  IMAGE                                         COMMAND         CREATED             STATUS         PORTS                   NAMES
...
7a6f25d4cb57  registry.redhat.io/rhel8/redis-6:1-110        run-redis       10 seconds ago      Up 5 seconds   0.0.0.0:6379->6379/tcp  redis
~~~

- [Deploy Red Hat Quay for proof-of-concept (non-production) purposes (Quay 3.8) - 3.1.1.1. Creating a certificate authority](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html-single/deploy_red_hat_quay_for_proof-of-concept_non-production_purposes/index#creating-a-certificate-authority) - create self-signed certification authority that will be used to issue certificate for quay
~~~
# mkdir /root/quay-ssl
# openssl genrsa -out /root/quay-ssl/rootCA.key 2048
# openssl req -x509 -new -nodes -key /root/quay-ssl/rootCA.key -sha256 -days 1024 -out /root/quay-ssl/rootCA.pem -subj "/C=IE/ST=GALWAY/L=GALWAY/O=QUAY/OU=DOCS/CN=quay.local/emailAddress=admin@localhost"
~~~
~~~
# ls -1 /root/quay-ssl/rootCA.*
/root/quay-ssl/rootCA.key
/root/quay-ssl/rootCA.pem
~~~

- [Deploy Red Hat Quay for proof-of-concept (non-production) purposes (Quay 3.8) - 3.1.1.2. Signing a certificate](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html-single/deploy_red_hat_quay_for_proof-of-concept_non-production_purposes/index#signing-a-certificate) - create certification request for `quay.local` and use self-signed CA to sing it
~~~
# openssl genrsa -out /root/quay-ssl/ssl.key 2048
# openssl req -new -key /root/quay-ssl/ssl.key -out /root/quay-ssl/ssl.csr -subj "/C=IE/ST=GALWAY/L=GALWAY/O=QUAY/OU=DOCS/CN=quay.local/emailAddress=admin@localhost"
~~~
~~~
# ls -1 /root/quay-ssl/ssl.*
/root/quay-ssl/ssl.csr
/root/quay-ssl/ssl.key
~~~
- make sure that in following configuration file the IP address of `quay.local` matches what is present in `/etc/hosts`
~~~
# cat > /root/quay-ssl/openssl.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = quay.local
IP.1 = 192.168.8.33
EOF
~~~
~~~
# openssl x509 -req -in /root/quay-ssl/ssl.csr -CA /root/quay-ssl/rootCA.pem -CAkey /root/quay-ssl/rootCA.key -CAcreateserial -out /root/quay-ssl/ssl.cert -days 356 -extensions v3_req -extfile /root/quay-ssl/openssl.cnf
~~~
~~~
# ls -1 /root/quay-ssl/ssl.*
/root/quay-ssl/ssl.cert
/root/quay-ssl/ssl.csr
/root/quay-ssl/ssl.key
~~~

- [Deploy Red Hat Quay for proof-of-concept (non-production) purposes (Quay 3.8) - 2.5. Configuring Red Hat Quay](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html-single/deploy_red_hat_quay_for_proof-of-concept_non-production_purposes/index#poc-configuring-quay) - instead of configuration editor for quay the `config.yaml` from quay/mirror-registry project will be used and modified to reflect used hostnames and passwords
~~~
# mkdir /mnt/config
# curl -o /mnt/config/config.yaml https://raw.githubusercontent.com/quay/mirror-registry/v1.3.4/ansible-runner/context/app/project/roles/mirror_appliance/templates/config.yaml.j2
# sed -i 's#^DB_URI:.*#DB_URI: postgresql://quayuser:quaypass@quay.local:5432/quay#' /mnt/config/config.yaml
# sed -i 's#^SERVER_HOSTNAME:.*#SERVER_HOSTNAME: quay.local#' /mnt/config/config.yaml
# sed -i 's#\s\+host:.*#  host: quay.local#' /mnt/config/config.yaml
# sed -i 's#\s\+password:.*#  password: strongpassword#' /mnt/config/config.yaml
~~~
- copy certificate and key into quay configuration directory and make it readable to quay ()
~~~
# cp /root/quay-ssl/ssl.cert /root/quay-ssl/ssl.key /mnt/config/
# setfacl -m u:1001:r-- /mnt/config/ssl.*
~~~
~~~
# ls -l /mnt/config/ssl*
-rw-r--r--. 1 root root 1375 May 22 14:37 /mnt/config/ssl.cert
-rw-------. 1 root root 1679 May 22 14:37 /mnt/config/ssl.key
~~~
~~~
# getfacl /mnt/config/ssl.*
getfacl: Removing leading '/' from absolute path names
# file: mnt/config/ssl.cert
# owner: root
# group: root
user::rw-
user:1001:r--
group::r--
mask::r--
other::r--

# file: mnt/config/ssl.key
# owner: root
# group: root
user::rw-
user:1001:r--
group::---
mask::r--
other::---
~~~
- (recommended) add the self-signed CA into trust store of server
~~~
# cp /root/quay-ssl/rootCA.pem /etc/pki/ca-trust/source/anchors
# update-ca-trust
~~~
~~~
# trust list |grep quay.local
    label: quay.local
~~~

- [Deploy Red Hat Quay for proof-of-concept (non-production) purposes (Quay 3.8) - 2.6.3. Prepare local storage for image data](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html-single/deploy_red_hat_quay_for_proof-of-concept_non-production_purposes/index#preparing-local-storage) - prepare storage folder for quay
~~~
# mkdir /mnt/storage
# setfacl -m u:1001:-wx /mnt/storage
~~~
~~~
# getfacl /mnt/storage
getfacl: Removing leading '/' from absolute path names
# file: mnt/storage
# owner: root
# group: root
user::rwx
user:1001:-wx
group::r-x
mask::rwx
other::r-x
~~~

- [Deploy Red Hat Quay for proof-of-concept (non-production) purposes (Quay 3.8) - 2.6.4. Deploy the Red Hat Quay registry](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html-single/deploy_red_hat_quay_for_proof-of-concept_non-production_purposes/index#deploy-quay-registry) - deploy quay registry using the custom build container image and start quay container
~~~
# podman create -p 80:8080 -p 443:8443  \
   --name=quay \
   -v /mnt/config:/conf/stack:Z \
   -v /mnt/storage:/datastorage:Z \
   quay.io/ofamera_test/quay:v3.8.6
# podman start quay
~~~
- patiently wait for quay to come up :)
~~~
# podman logs -f quay
...
Running init script '/quay-registry/conf/init/nginx_conf_create.sh'
Running init script '/quay-registry/conf/init/runmigration.sh'
...
Running init script '/quay-registry/conf/init/supervisord_conf_create.sh'
Running init script '/quay-registry/conf/init/zz_boot.sh'
2023-05-17 01:50:44,062 INFO RPC interface 'supervisor' initialized
2023-05-17 01:50:44,063 CRIT Server 'unix_http_server' running without any HTTP authentication checking
2023-05-17 01:50:44,064 INFO supervisord started with pid 7
2023-05-17 01:50:45,085 INFO spawned: 'stdout' with pid 49
2023-05-17 01:50:45,113 INFO spawned: 'blobuploadcleanupworker' with pid 50
2023-05-17 01:50:45,133 INFO spawned: 'builder' with pid 51
2023-05-17 01:50:45,147 INFO spawned: 'buildlogsarchiver' with pid 52
2023-05-17 01:50:45,162 INFO spawned: 'chunkcleanupworker' with pid 53
2023-05-17 01:50:45,177 INFO spawned: 'dnsmasq' with pid 54
2023-05-17 01:50:45,208 INFO spawned: 'expiredappspecifictokenworker' with pid 55
2023-05-17 01:50:45,253 INFO spawned: 'exportactionlogsworker' with pid 56
2023-05-17 01:50:45,266 INFO spawned: 'gcworker' with pid 57
2023-05-17 01:50:45,277 INFO spawned: 'globalpromstats' with pid 58
2023-05-17 01:50:45,362 INFO spawned: 'gunicorn-registry' with pid 59
2023-05-17 01:50:45,446 INFO spawned: 'gunicorn-secscan' with pid 60
2023-05-17 01:50:45,457 INFO spawned: 'gunicorn-web' with pid 61
2023-05-17 01:50:45,577 INFO spawned: 'logrotateworker' with pid 62
2023-05-17 01:50:45,668 INFO spawned: 'manifestbackfillworker' with pid 63
2023-05-17 01:50:45,676 INFO spawned: 'memcache' with pid 64
2023-05-17 01:50:45,687 INFO spawned: 'namespacegcworker' with pid 65
2023-05-17 01:50:45,834 INFO spawned: 'nginx' with pid 66
2023-05-17 01:50:45,846 INFO spawned: 'notificationworker' with pid 67
2023-05-17 01:50:45,945 INFO spawned: 'pushgateway' with pid 73
2023-05-17 01:50:46,018 INFO spawned: 'queuecleanupworker' with pid 76
2023-05-17 01:50:46,119 INFO spawned: 'repositoryactioncounter' with pid 77
2023-05-17 01:50:46,128 INFO spawned: 'repositorygcworker' with pid 80
2023-05-17 01:50:46,429 INFO spawned: 'securityscanningnotificationworker' with pid 81
2023-05-17 01:50:46,440 INFO spawned: 'securityworker' with pid 89
2023-05-17 01:50:46,589 INFO spawned: 'servicekey' with pid 90
2023-05-17 01:50:46,599 INFO spawned: 'storagereplication' with pid 95
2023-05-17 01:50:46,625 INFO spawned: 'teamsyncworker' with pid 96
...
notificationworker stdout | 2023-05-17 01:52:39,341 [67] [INFO] [apscheduler.executors.default] Job "QueueWorker.poll_queue (trigger: interval[0:00:10], next run at: 2023-05-17 01:52:49 UTC)" executed successfully
buildlogsarchiver stdout | 2023-05-17 01:52:44,866 [52] [INFO] [apscheduler.executors.default] Running job "ArchiveBuildLogsWorker._archive_redis_buildlogs (trigger: interval[0:00:30], next run at: 2023-05-17 01:53:14 UTC)" (scheduled at 2023-05-17 01:52:44.819839+00:00)
buildlogsarchiver stdout | 2023-05-17 01:52:44,982 [52] [INFO] [apscheduler.executors.default] Job "ArchiveBuildLogsWorker._archive_redis_buildlogs (trigger: interval[0:00:30], next run at: 2023-05-17 01:53:14 UTC)" executed successfully
notificationworker stdout | 2023-05-17 01:52:49,134 [67] [INFO] [apscheduler.executors.default] Running job "QueueWorker.poll_queue (trigger: interval[0:00:10], next run at: 2023-05-17 01:52:59 UTC)" (scheduled at 2023-05-17 01:52:49.121817+00:00)
notificationworker stdout | 2023-05-17 01:52:49,230 [67] [INFO] [apscheduler.executors.default] Job "QueueWorker.poll_queue (trigger: interval[0:00:10], next run at: 2023-05-17 01:52:59 UTC)" executed successfully
~~~
- NOTE: it takes around 3-5 minutes for quay to execute all random stuff inside and settle down at first run
- NOTE: the more CPUs you have the higher the memory consumption will be due to dynamic sizing of some services inside quay container - below is example from OS running 6GB RAM and 2 CPUs
~~~
# podman stats
ID            NAME             CPU %       MEM USAGE / LIMIT  MEM %       NET IO             BLOCK IO           PIDS        CPU TIME        AVG CPU %
1c239675d6cc  quay             16.51%      3.84GB / 6.109GB   62.86%      326.9kB / 429.6kB  298MB / 0B         125         6m9.190549712s  61.04%
5aea6cde80d4  postgresql-quay  0.63%       81.2MB / 6.109GB   1.33%       430.4kB / 324.3kB  1.384MB / 364.1MB  8           19.56908547s    1.13%
7a6f25d4cb57  redis            0.58%       8.126MB / 6.109GB  0.13%       6.529kB / 3.285kB  188.4kB / 38.91kB  5           14.46540623s    0.86%
~~~
~~~
#  df -h /
Filesystem                Size  Used Avail Use% Mounted on
/dev/mapper/r8vg-root_lv  9.1G  3.5G  5.6G  39% /
~~~

- [Configure Red Hat Quay (Quay 3.8) - 2.10.9.1. Using the API to create the first user](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html-single/configure_red_hat_quay/index#using-the-api-to-create-first-user) - create `quayadmin` account with password `password` via web API
~~~
# curl -k -d '{ "username": "quayadmin", "password": "password", "email": "init@quay.io", "access_token": "true" }' -H "Content-Type: application/json" -X POST https://quay.local/api/v1/user/initialize
{"access_token":"PE75QMW23HIXAGZX1IYCXWCR8AQYQJ640TSX04ZV","email":"init@quay.io","encrypted_password":"yEMJxm1KWDzgmwu6iMQzA5MPeq7KI6bimN9dXAg+yDuAK5J6sdfUTN3aAFn9uHik","username":"quayadmin"}
~~~

- [Deploy Red Hat Quay for proof-of-concept (non-production) purposes (Quay 3.8) - 2.7. Using Red Hat Quay](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html-single/deploy_red_hat_quay_for_proof-of-concept_non-production_purposes/index#using_red_hat_quay) - try to login into quay registry
~~~
# podman login quay.local -u quayadmin -p password
Login Succeeded!
~~~

- [Deploy Red Hat Quay for proof-of-concept (non-production) purposes (Quay 3.8) - 2.7.1. Push and pull images](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html-single/deploy_red_hat_quay_for_proof-of-concept_non-production_purposes/index#push_and_pull_images) - test pushing container image into registry
~~~
# podman pull busybox
# podman tag docker.io/library/busybox quay.local/quayadmin/busybox:latest
# podman push quay.local/quayadmin/busybox
~~~
~~~
# podman images
REPOSITORY                              TAG         IMAGE ID      CREATED       SIZE
docker.io/library/busybox               latest      f92f3ea6e4a8  2 days ago    3.96 MB
quay.local/quayadmin/busybox            latest      f92f3ea6e4a8  2 days ago    3.96 MB
~~~

- [Deploy Red Hat Quay for proof-of-concept (non-production) purposes (Quay 3.8) - 3.5.1. Using systemd unit files with Podman](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html-single/deploy_red_hat_quay_for_proof-of-concept_non-production_purposes/index#using_systemd_unit_files_with_podman) - configure containers to start on system boot using systemd
~~~
# podman generate systemd -n postgresql-quay > /etc/systemd/system/podman-postgresql-quay.service
# podman generate systemd -n redis > /etc/systemd/system/podman-redis.service
# podman generate systemd -n quay > /etc/systemd/system/podman-quay.service
# systemctl daemon-reload
~~~
~~~
# systemctl enable podman-postgresql-quay podman-redis podman-quay
~~~

## (optional) Reducing memory usage of Quay container
WARNING: Below configuration may break some of functionality that you may want to use with quay, however it is provided here as outline on how to approach the process of reducing resource footprint of quay if you are aware of services that you don't need and your priority is resource usage.

The easiest approach to disable the services in quay container is to use `QUAY_OVERRIDE_SERVICES` environment variable and choose the services that you think you may not need. The list of services is mentioned in https://github.com/quay/quay/blob/v3.8.6/conf/init/supervisord_conf_create.py#L19-L51

Below is example of disabling a vast majority of services in quay container, but still allowing some basic functionality while consuming only half of memory compared to original state.

~~~
# systemctl stop podman-quay
# podman stop quay
# podman rm quay
# podman create -p 80:8080 -p 443:8443  \
   --name=quay \
   -v /mnt/config:/conf/stack:Z \
   -v /mnt/storage:/datastorage:Z \
   -e QUAY_OVERRIDE_SERVICES="gunicorn-secscan=false,dnsmasq=false,ip-resolver-update-worker=false,securityscanningnotificationworker=false,storagereplication=false,builder=false,buildlogsarchiver=false,expiredappspecifictokenworker=false,globalpromstats=false,repositoryactioncounter=false,teamsyncworker=false,servicekey=false,securityworker=false,exportactionlogsworker=false" \
   quay.io/ofamera_test/quay:v3.8.6
# podman start quay
# podman generate systemd -n quay > /etc/systemd/system/podman-quay.service
# systemctl daemon-reload
# systemctl enable podman-quay
~~~
~~~
# podman stats
ID            NAME             CPU %       MEM USAGE / LIMIT  MEM %       NET IO             BLOCK IO           PIDS        CPU TIME         AVG CPU %
5aea6cde80d4  postgresql-quay  0.03%       83.03MB / 6.109GB  1.36%       2.029MB / 1.79MB   46.21MB / 515.7MB  8           1m13.155795854s  0.85%
7a6f25d4cb57  redis            0.99%       8.323MB / 6.109GB  0.14%       46.64kB / 26.65kB  1.933MB / 85.5kB   5           1m17.276739408s  0.90%
cd1ed336b977  quay             3.59%       1.971GB / 6.109GB  32.26%      50.02kB / 63.52kB  32.77kB / 0B       80          3m15.344921105s  37.43%
~~~

## How to build quay/quay image for aarch64
Below can be used as reference for how to build same image as one that is provided here from `xxx`.

The environment used for build was Fedora 38 (aarch64) with 6GB RAM, 20GB disk and 4CPU (Cortex-A55@1.8GHz).

- install needed packages
~~~
# dnf install podman git
~~~
- get the quay/quay source code at tag `v3.8.6`
~~~
# git clone --branch v3.8.6 --depth 1 https://github.com/quay/quay
~~~
- go into source directory and start the build (on my testing system with 4x Cortex-A55 cores the build takes 95-115 minutes, including the time that it is downloading various resources from Internet)
~~~
# cd quay
# podman build . -t localhost/quay:v3.8.6
~~~

## What next?
One daring plan is to try also adjusting https://github.com/quay/mirror-registry to work with aarch64 image :)
