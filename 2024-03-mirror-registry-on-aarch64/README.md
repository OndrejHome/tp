# Openshift mirror-registry 1.3.10 (aarch64) proof-of-concept creation and deployment guide
[Mirror-registry](https://github.com/quay/mirror-registry) is QUAY deployment packaged for simplified deployment of container registry primarily as container registry mirror for openshift deployments. It uses ansible playbooks to install/upgrade/uninstall the quay on/from RHEL 8 or Fedora machines. This guide will provide steps for building mirror-registry offline bundle for aarch64 systems.

NOTE that some of images needed for building mirror-registry requires Red Hat (Developer) account.

IMPORTANT: As there is no `quay/quay-rhel8` aarch64 image available and we are building the mirror-registry bundle by ourselves, the following cannot be supported by Red Hat.

- [1. Current state and challenges (as of 2024-02) with mirror-registry on aarch64](#user-content-1-current-state-and-challenges-as-of-2024-02-with-mirror-registry-on-aarch64)
  - [1.1. Resolving challenge 1 - Dockerfile contains hardcoded `amd64` binaries for go](#user-content-11-resolving-challenge-1---dockerfile-contains-hardcoded-amd64-binaries-for-go)
  - [1.2. Resolving challenge 2 - Need for aarch64 Quay container image (QUAY_IMAGE)](#user-content-12-resolving-challenge-2---need-for-aarch64-quay-container-image-quay_image)
  - [1.3. Resolving challenge 3 -  Need for aarch64 based ansible container images (EE_IMAGE, EE_BUILDER_IMAGE)](#user-content-13-resolving-challenge-3---need-for-aarch64-based-ansible-container-images-ee_image-ee_builder_image)
- [2. Building the mirror-registry offline bundle](#user-content-2-building-the-mirror-registry-offline-bundle)
- [3. Deployment of mirror-registry on aarch64 system using offline `mirror-registry.tar.gz`](#user-content-3-deployment-of-mirror-registry-on-aarch64-system-using-offline-mirror-registrytargz)

## 1. Current state and challenges (as of 2024-02) with mirror-registry on aarch64

There are [no pre-build 'mirror-registry' archives](https://mirror.openshift.com/pub/openshift-v4/aarch64/clients/mirror-registry/) available like [mirror-registry bundles for x86_64 platform](https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/mirror-registry/). This leaves us with approach of building the mirror-registry offline bundle our selves.

What challenges we have when trying to build the mirror-registry for aarch64 platform?
- 1. Dockerfile contains hardcoded `amd64` binaries for 'go'
- 2. We need aarch64 Quay container image (QUAY_IMAGE)
- 3. We need aarch64 based ansible container images (EE_IMAGE, EE_BUILDER_IMAGE)

### 1.1. Resolving challenge 1 - Dockerfile contains hardcoded `amd64` binaries for go
Simply enough we can use aarch64 (`arm64`) version of binaries when building on aarch64 system. Borrowing code from quay Dockerfile help us to achieve exactly that. See the difference below.

~~~
diff --git a/Dockerfile b/Dockerfile
index 51ef30f..50c6669 100644
--- a/Dockerfile
+++ b/Dockerfile
@@ -22,8 +22,10 @@ ENV GOROOT=/usr/local/go
 ENV PATH=$GOPATH/bin:$GOROOT/bin:$PATH 
 
 # Get Go binary
-RUN curl -o go1.16.4.linux-amd64.tar.gz https://dl.google.com/go/go1.16.4.linux-amd64.tar.gz
-RUN tar -xzf go1.16.4.linux-amd64.tar.gz  &&\
+RUN ARCH=$(uname -m); echo $ARCH; \
+    if [ "$ARCH" == "x86_64" ] ; then ARCH="amd64" ; elif [ "$ARCH" == "aarch64" ] ; then ARCH="arm64" ; fi; \
+    curl -o go1.16.4.linux.tar.gz https://dl.google.com/go/go1.16.4.linux-${ARCH}.tar.gz
+RUN tar -xzf go1.16.4.linux.tar.gz  &&\
     mv go /usr/local
 
 COPY . /cli
~~~

### 1.2. Resolving challenge 2 - Need for aarch64 Quay container image (QUAY_IMAGE)
While there is no official aarch64 container image for quay as of time of writing this guide that I could easily find, it is easy to just build one by ourselves. To save some time I have done just that and result can be found at `quay.io/ofamera_test/quay:v3.8.14` - for steps (not that there are many) you can check out the [Quay 3.8.6 (aarch64) proof-of-concept deployment guide](../2023-05-quay-on-aarch64/README.md). For the mirror-registry build we will need to adjust `.env` file to use this image and  you can see the difference below.

~~~
diff --git a/.env b/.env
index 6f5620c..8b12d9f 100644
--- a/.env
+++ b/.env
@@ -2,6 +2,6 @@ EE_IMAGE=quay.io/quay/mirror-registry-ee:latest
 EE_BASE_IMAGE=registry.redhat.io/ansible-automation-platform-22/ee-minimal-rhel8:1.0.0-249
 EE_BUILDER_IMAGE=registry.redhat.io/ansible-automation-platform-22/ansible-builder-rhel8:1.1.0-103
 POSTGRES_IMAGE=registry.redhat.io/rhel8/postgresql-10:1-203.1669834630
-QUAY_IMAGE=registry.redhat.io/quay/quay-rhel8:v3.8.14
+QUAY_IMAGE=quay.io/ofamera_test/quay:v3.8.14
 REDIS_IMAGE=registry.redhat.io/rhel8/redis-6:1-92.1669834635
 PAUSE_IMAGE=registry.access.redhat.com/ubi8/pause:8.7-6
~~~

### 1.3. Resolving challenge 3 - Need for aarch64 based ansible container images (EE_IMAGE, EE_BUILDER_IMAGE)
While the used Ansible Automation Platform (AAP) 2.2 EE_IMAGE and EE_BUILDER_IMAGE have no aarch64 version the AAP 2.4 version has container images for aarch64 platform. Lets change the `.env` further to include also these AAP 2.4 container images.

~~~
diff --git a/.env b/.env
index 6f5620c..eb0c7d1 100644
--- a/.env
+++ b/.env
@@ -1,7 +1,7 @@
 EE_IMAGE=quay.io/quay/mirror-registry-ee:latest
-EE_BASE_IMAGE=registry.redhat.io/ansible-automation-platform-22/ee-minimal-rhel8:1.0.0-249
-EE_BUILDER_IMAGE=registry.redhat.io/ansible-automation-platform-22/ansible-builder-rhel8:1.1.0-103
+EE_BASE_IMAGE=registry.redhat.io/ansible-automation-platform-24/ee-minimal-rhel8:1.0.0-528
+EE_BUILDER_IMAGE=registry.redhat.io/ansible-automation-platform-24/ansible-builder-rhel8:3.0.0-168
 POSTGRES_IMAGE=registry.redhat.io/rhel8/postgresql-10:1-203.1669834630
-QUAY_IMAGE=registry.redhat.io/quay/quay-rhel8:v3.8.14
+QUAY_IMAGE=quay.io/ofamera_test/quay:v3.8.14
 REDIS_IMAGE=registry.redhat.io/rhel8/redis-6:1-92.1669834635
 PAUSE_IMAGE=registry.access.redhat.com/ubi8/pause:8.7-6
~~~

## 2. Building the mirror-registry offline bundle
What HW we will need to build the images.
- Fedora 39 aarch64 or RHEL 8.9 aarch64 system - I will use system with minimal installation
- 2x CPUs (I will use Cortex-A55@1.8GHz)
- 2GB RAM
- 25GB disk

Additionally we will need the Red Hat or Red Hat Developer account. Examples below were taken from Fedora 39 aarch64 system.

---

- First lets install packages needed for build.
  ~~~
  # dnf install git make podman patch
  ~~~

- Then clone mirror-registry repository (I will explicitly use one tagged as `v1.3.10` for consistency).
  ~~~
  # git clone --depth 1 --branch v1.3.10 https://github.com/quay/mirror-registry.git mirror-registry/
  # cd mirror-registry/
  ~~~

- Modify the `.env` and `Dockerfile` for aarch64 build either by:
  - Downloading and applying the [`mirror-registry-1.3.10-aarch64-custom.patch` patch file](https://raw.githubusercontent.com/OndrejHome/tp/master/2024-03-mirror-registry-on-aarch64/mirror-registry-1.3.10-aarch64-custom.patch).
    ~~~
    # curl -O https://raw.githubusercontent.com/OndrejHome/tp/master/2024-03-mirror-registry-on-aarch64/mirror-registry-1.3.10-aarch64-custom.patch
    # patch -p1 < mirror-registry-1.3.10-aarch64-custom.patch 
    patching file .env
    patching file Dockerfile
    ~~~
  - or by modifying the files directly, the differences are shown below.
    ~~~
    diff --git a/.env b/.env
    index 6f5620c..eb0c7d1 100644
    --- a/.env
    +++ b/.env
    @@ -1,7 +1,7 @@
     EE_IMAGE=quay.io/quay/mirror-registry-ee:latest
    -EE_BASE_IMAGE=registry.redhat.io/ansible-automation-platform-22/ee-minimal-rhel8:1.0.0-249
    -EE_BUILDER_IMAGE=registry.redhat.io/ansible-automation-platform-22/ansible-builder-rhel8:1.1.0-103
    +EE_BASE_IMAGE=registry.redhat.io/ansible-automation-platform-24/ee-minimal-rhel8:1.0.0-528
    +EE_BUILDER_IMAGE=registry.redhat.io/ansible-automation-platform-24/ansible-builder-rhel8:3.0.0-168
     POSTGRES_IMAGE=registry.redhat.io/rhel8/postgresql-10:1-203.1669834630
    -QUAY_IMAGE=registry.redhat.io/quay/quay-rhel8:v3.8.14
    +QUAY_IMAGE=quay.io/ofamera_test/quay:v3.8.14
     REDIS_IMAGE=registry.redhat.io/rhel8/redis-6:1-92.1669834635
     PAUSE_IMAGE=registry.access.redhat.com/ubi8/pause:8.7-6
    ~~~
    ~~~
    diff --git a/Dockerfile b/Dockerfile
    index 51ef30f..50c6669 100644
    --- a/Dockerfile
    +++ b/Dockerfile
    @@ -22,8 +22,10 @@ ENV GOROOT=/usr/local/go
     ENV PATH=$GOPATH/bin:$GOROOT/bin:$PATH 
     
     # Get Go binary
    -RUN curl -o go1.16.4.linux-amd64.tar.gz https://dl.google.com/go/go1.16.4.linux-amd64.tar.gz
    -RUN tar -xzf go1.16.4.linux-amd64.tar.gz  &&\
    +RUN ARCH=$(uname -m); echo $ARCH; \
    +    if [ "$ARCH" == "x86_64" ] ; then ARCH="amd64" ; elif [ "$ARCH" == "aarch64" ] ; then ARCH="arm64" ; fi; \
    +    curl -o go1.16.4.linux.tar.gz https://dl.google.com/go/go1.16.4.linux-${ARCH}.tar.gz
    +RUN tar -xzf go1.16.4.linux.tar.gz  &&\
         mv go /usr/local
     
     COPY . /cli
    ~~~

- Login into `registry.redhat.io` with Red Hat (Developer) account.
  ~~~
  # podman login registry.redhat.io
  Username: <RH_ACCOUNT>
  Password: <PASSWORD>
  Login Succeeded!
  ~~~

- Try to pull all the images that will be used for build. 
  - Note that EE_IMAGE from `.env` file is intentionally left out - that will be name of final generated EE image used by mirror-registry for running ansible playbooks.
  ~~~
  # source .env
  ~~~
  ~~~
  # for img in $EE_BASE_IMAGE $EE_BUILDER_IMAGE $POSTGRES_IMAGE $QUAY_IMAGE $REDIS_IMAGE $PAUSE_IMAGE registry.access.redhat.com/ubi8:latest; do podman pull $img; done
  ~~~
- Once all of images are pulled we should see listing similar to one below.
  ~~~
  # podman images
  REPOSITORY                                                               TAG               IMAGE ID      CREATED        SIZE
  quay.io/ofamera_test/quay                                                v3.8.14           44075df36385  7 days ago     1.01 GB
  registry.access.redhat.com/ubi8                                          latest            00cd8111755b  2 weeks ago    237 MB
  registry.redhat.io/ansible-automation-platform-24/ee-minimal-rhel8       1.0.0-528         49ba90898fbb  2 weeks ago    349 MB
  registry.redhat.io/ansible-automation-platform-24/ansible-builder-rhel8  3.0.0-168         6074a0902fb7  2 weeks ago    245 MB
  registry.redhat.io/rhel8/redis-6                                         1-92.1669834635   bb63fbf1e30e  15 months ago  326 MB
  registry.redhat.io/rhel8/postgresql-10                                   1-203.1669834630  ac126b7d8df3  15 months ago  494 MB
  registry.access.redhat.com/ubi8/pause                                    8.7-6             3d0330e3cd8d  16 months ago  30.4 MB
  ~~~

- Check the available disk space and RUN the build process (on my test system this takes **around 40 minutes**).
  - **NOTE:** A lot of disk space is needed only temporarily during build, with 21GB of available disk space at this step the build succeeded on my machine, but having only 20GB the build failed.
  ~~~
  # df -h /
  Filesystem               Size  Used Avail Use% Mounted on
  /dev/mapper/f39-root_lv   25G  4.1G   21G  17% /
  ~~~
  ~~~
  # RELEASE_VERSION='1.3.10-arm64-custom' make build-offline-zip
  ...
  Successfully tagged localhost/mirror-registry-offline:1.3.10-arm64-custom
  eacb43da6baa5d6f630a09b729911b734c2a0c57c676ceeb7a7919858e415e08
  podman run --name mirror-registry-offline-1.3.10-arm64-custom mirror-registry-offline:1.3.10-arm64-custom
  podman cp mirror-registry-offline-1.3.10-arm64-custom:/mirror-registry.tar.gz .
  podman rm mirror-registry-offline-1.3.10-arm64-custom
  mirror-registry-offline-1.3.10-arm64-custom
  ...
  ~~~
  ~~~
  # df -h /
  Filesystem               Size  Used Avail Use% Mounted on
  /dev/mapper/f39-root_lv   25G   13G   12G  51% /
  ~~~

- Check that we see the resulting mirror-registry archive.
  ~~~
  # du -BM mirror-registry.tar.gz
  656M	mirror-registry.tar.gz
  ~~~

## 3. Deployment of mirror-registry on aarch64 system using offline `mirror-registry.tar.gz`
What HW we will need for deploying the mirror-registry
- Fedora 39 aarch64 or RHEL 8.9 aarch64 system - I will use systems with minimal installation
- 2x CPUs (I will use Cortex-A55@1.8GHz)
- 6GB RAM (quay image itself needs around 4GB RAM to run)
- 15GB disk for installation + more for actual stored data 

Examples below were taken from RHEL 8.9 aarch64 system.

---

- Install packages needed for unpacking and running mirror-registry.
  ~~~
  # dnf install tar podman
  ~~~
- Unpack the archive and check its version (to confirm it is the one we have build).
  ~~~
  # tar xvf mirror-registry.tar.gz 
  image-archive.tar
  execution-environment.tar
  mirror-registry
  ~~~
  ~~~
  # ./mirror-registry --version
  
     __   __
    /  \ /  \     ______   _    _     __   __   __
   / /\ / /\ \   /  __  \ | |  | |   /  \  \ \ / /
  / /  / /  \ \  | |  | | | |  | |  / /\ \  \   /
  \ \  \ \  / /  | |__| | | |__| | / ____ \  | |
   \ \/ \ \/ /   \_  ___/  \____/ /_/    \_\ |_|
    \__/ \__/      \ \__
                    \___\ by Red Hat
   Build, Store, and Distribute your Containers
  
  mirror-registry version 1.3.10-arm64-custom
  ~~~
- Check available disk space and RUN the installation of mirror-registry (this takes **around 10 minutes**).
  - Example below will deploy mirror-registry with preconfigured user `mirroruser` and password `mirrorpass`.
  ~~~
  # df -h /
  Filesystem                Size  Used Avail Use% Mounted on
  /dev/mapper/r8vg-root_lv   14G  4.0G   11G  29% /
  ~~~
  ~~~
  # ./mirror-registry install --initUser mirroruser --initPassword mirrorpass
  ...
  
  PLAY RECAP ********************************************************************************************************************
  root@fastvm-rhel-8-9-aarch64-43 : ok=50   changed=31   unreachable=0    failed=0    skipped=17   rescued=0    ignored=0
  
  INFO[2024-02-29 11:19:09] Quay installed successfully, config data is stored in ~/quay-install
  INFO[2024-02-29 11:19:09] Quay is available at https://fastvm-rhel-8-9-aarch64-43:8443 with credentials (mirroruser, mirrorpass)
  ~~~
  ~~~
  # df -h /
  Filesystem                Size  Used Avail Use% Mounted on
  /dev/mapper/r8vg-root_lv   14G  7.9G  6.2G  56% /
  ~~~
- Open port for mirror-registry on firewall to be able to access it.
  ~~~
  # firewall-cmd --add-port 8443/tcp
  # firewall-cmd --add-port 8443/tcp --permanent
  ~~~

**Enjoy the mirror-registry (quay) running on your aarch64 system.**

- (Optional) Test uploading some existing container image to registry:
  - First add the registry CA into trusted OS store,
  - then login into registry,
  - lastly tag some existing container image and push it to registry.
  ~~~
  # cp quay-install/quay-rootCA/rootCA.pem /etc/pki/ca-trust/source/anchors/
  ~~~
  ~~~
  # update-ca-trust
  ~~~
  ~~~
  # podman login fastvm-rhel-8-9-aarch64-43:8443 -u mirroruser -p mirrorpass
  Login Succeeded!
  ~~~
  ~~~
  # podman tag quay.io/quay/mirror-registry-ee:latest fastvm-rhel-8-9-aarch64-43:8443/mirroruser/mirror-registry-ee:latest
  # podman push fastvm-rhel-8-9-aarch64-43:8443/mirroruser/mirror-registry-ee:latest
  ...
  Getting image source signatures
  Copying blob 70bf10cecc34 done  
  Copying config 7262aba691 done  
  Writing manifest to image destination
  ~~~
- (Optional) Cleanup installation files.
  ~~~
  # ls -1 mirror-registry* *tar
  execution-environment.tar
  image-archive.tar
  mirror-registry
  mirror-registry.tar.gz
  pause.tar
  postgres.tar
  quay.tar
  redis.tar
  ~~~
  ~~~
  # rm -f mirror-registry* *tar
  ~~~
- (optional) Check the final resource state of system.
  ~~~
  # free -m
                total        used        free      shared  buff/cache   available
  Mem:           5825        4251        1263          31         310         959
  Swap:           255         255           0
  ~~~
  ~~~
  # df -h /
  Filesystem                Size  Used Avail Use% Mounted on
  /dev/mapper/r8vg-root_lv   14G  3.7G   11G  26% /
  ~~~
  ~~~
  # podman images
  REPOSITORY                                                     TAG               IMAGE ID      CREATED      SIZE
  quay.io/ofamera_test/quay                                      v3.8.14           e4ffb8c77bfa  2 hours ago  1.01 GB
  registry.redhat.io/rhel8/postgresql-10                         1-203.1669834630  01de9f2d24f8  2 hours ago  454 MB
  registry.redhat.io/rhel8/redis-6                               1-92.1669834635   d3465feda1a4  2 hours ago  290 MB
  registry.access.redhat.com/ubi8/pause                          8.7-6             10b21cfa85e8  2 hours ago  30.4 MB
  quay.io/quay/mirror-registry-ee                                latest            7262aba691b2  2 hours ago  356 MB
  fastvm-rhel-8-9-aarch64-43:8443/mirroruser/mirror-registry-ee  latest            7262aba691b2  2 hours ago  356 MB
  ~~~
