## Docker image for syncing yum repositories
Image is based on CentOS 7.7 and has a simple script that expects 2 arguments:
- name of repo file describing yum repository (typically file from `/etc/yum.repos.d/`
- name of one repository to sync (as the repo file can contain multiple)

### Building the image
~~~
# cd reposync
# docker build -t reposync:centos-7.7 ./
~~~

### Using the image with docker
`/tmp/repos/k17.repo` is repository file and the synced repository will be saved in `/tmp/data` directory.
~~~
# mkdir /tmp/{data,repos}
# cat > /tmp/repos/k17.repo <<EOF
[k17]
name=Kubernetes
baseurl=http://yum.kubernetes.io/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
includepkgs=kube*-1.17* kubernetes-cni cri-tools
EOF
~~~
Example output from syncing kubernetes repository.
~~~
# docker run --rm -d -it -v /tmp/repos:/repos -v /tmp/data:/data --name centos-reposync -e REPO_NAME='k17' -e REPO_FILE='k17.repo' reposync:centos-7.7; docker logs -f centos-reposync
Preparing yum cache with 'yum makecache -y -c /repos/k17.repo'
k17/signature                                            |  454 B     00:00
Retrieving key from https://packages.cloud.google.com/yum/doc/yum-key.gpg
Importing GPG key 0xA7317B0F:
 Userid     : "Google Cloud Packages Automatic Signing Key <gc-team@google.com>"
 Fingerprint: d0bc 747f d8ca f711 7500 d6fa 3746 c208 a731 7b0f
 From       : https://packages.cloud.google.com/yum/doc/yum-key.gpg
Retrieving key from https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
k17/signature                                            | 1.4 kB     00:12 !!!
(1/3): k17/filelists                                       |  22 kB   00:01
(2/3): k17/primary                                         |  63 kB   00:01
(3/3): k17/other                                           |  41 kB   00:00
k17                                                                     460/460
k17                                                                     460/460
k17                                                                     460/460
Metadata Cache Created
Syncing repository with 'reposync -c /repos/k17.repo -r k17 -p /data'
warning: /data/k17/Packages/29e7806d1d54cc0eea2963f4ab276778526538816c88c963ece7d1a05fd80792-cri-tools-1.0.0_beta.1-0.x86_64.rpm: Header V4 RSA/SHA512 Signature, key ID 3e1ba8d5: NOKEY
Public key for 29e7806d1d54cc0eea2963f4ab276778526538816c88c963ece7d1a05fd80792-cri-tools-1.0.0_beta.1-0.x86_64.rpm is not installed
(1/19): 29e7806d1d54cc0eea2963f4ab276778526538816c88c963ec | 4.0 MB   00:01
(2/19): e253c692a017b164ebb9ad1b6537ff8afd93c35e9ebc340a52 | 4.2 MB   00:01
(3/19): f70d8cb23c7b91c0509292f4862060367edabce8788b855c38 | 4.2 MB   00:00
(4/19): 53edc739a0e51a4c17794de26b13ee5df939bd3161b37f503f | 4.2 MB   00:00
(5/19): 14bfe6e75a9efc8eca3f638eb22c7e2ce759c67f95b43b16fa | 5.1 MB   00:00
(6/19): 2c6d2fa074d044b3c58ce931349e74c25427f173242c6a5624 | 8.7 MB   00:01
(7/19): 105d89f0607c7baf91305ba352e78000bd20aad5cdf706bfff | 8.7 MB   00:00
(8/19): 0ec02f105d2a5d0059711f73187d45cf5a03d366fe6e895cfc | 8.7 MB   00:01
(9/19): 120c3cc5366afa7767e6a627578699244c514bc84d4c5727b8 | 9.4 MB   00:02
(10/19): bf67b612b185159556555b03e1e3a1ac5b10096afe48e4a7b | 9.4 MB   00:02
(11/19): b44630896c69cd411db53be1d5cb5ae899a40aba7c0766317 | 9.4 MB   00:00
(12/19): 7d9e0a47eb6eaf5322bd45f05a2360a033c29845543a4e768 |  20 MB   00:03
(13/19): 2c0df9a4c416331d9447d7e3da9fbe108e7598b2a0cfd02cd |  20 MB   00:03
(14/19): 3ee7f2dff78e6fbb3ac3af8acb1a907f4bec1b1ef4cf627cb |  20 MB   00:02
(15/19): 0c923b191423caccc65c550ef07ce61b97f991ad54785dab7 | 9.8 MB   00:02
(16/19): e7a4403227dd24036f3b0615663a371c4e07a95be5fee5350 | 7.4 MB   00:01
(17/19): 79f9ba89dbe7000e7dfeda9b119f711bb626fe2c2d56abeb3 | 7.4 MB   00:01
(18/19): 548a0dcd865c16a50980420ddfa5fbccb8b59621179798e6d |  10 MB   00:01
(19/19): fe33057ffe95bfae65e2f269e1b05e99308853176e24a4d02 | 8.6 MB   00:02
Generating repo metadata with 'createrepo -v /data/k17'
Spawning worker 0 with 10 pkgs
Spawning worker 1 with 9 pkgs
Worker 0: reading Packages/0c923b191423caccc65c550ef07ce61b97f991ad54785dab70dc07a5763f4222-kubernetes-cni-0.3.0.1-0.07a8a2.x86_64.rpm
Worker 1: reading Packages/0ec02f105d2a5d0059711f73187d45cf5a03d366fe6e895cfc5c3d3d73e88b4e-kubeadm-1.17.1-0.x86_64.rpm
Worker 0: reading Packages/105d89f0607c7baf91305ba352e78000bd20aad5cdf706bffff3b31cd546dbf3-kubeadm-1.17.2-0.x86_64.rpm
Worker 1: reading Packages/120c3cc5366afa7767e6a627578699244c514bc84d4c5727b8afc09a547b5ea6-kubectl-1.17.1-0.x86_64.rpm
Worker 0: reading Packages/14bfe6e75a9efc8eca3f638eb22c7e2ce759c67f95b43b16fae4ebabde1549f3-cri-tools-1.13.0-0.x86_64.rpm
Worker 1: reading Packages/29e7806d1d54cc0eea2963f4ab276778526538816c88c963ece7d1a05fd80792-cri-tools-1.0.0_beta.1-0.x86_64.rpm
Worker 0: reading Packages/2c0df9a4c416331d9447d7e3da9fbe108e7598b2a0cfd02cdcd0429e35a0895c-kubelet-1.17.1-0.x86_64.rpm
Worker 1: reading Packages/2c6d2fa074d044b3c58ce931349e74c25427f173242c6a5624f0f789e329bc75-kubeadm-1.17.0-0.x86_64.rpm
Worker 0: reading Packages/3ee7f2dff78e6fbb3ac3af8acb1a907f4bec1b1ef4cf627cbe02fa553707f2e9-kubelet-1.17.2-0.x86_64.rpm
Worker 1: reading Packages/53edc739a0e51a4c17794de26b13ee5df939bd3161b37f503fe2af8980b41a89-cri-tools-1.12.0-0.x86_64.rpm
Worker 0: reading Packages/548a0dcd865c16a50980420ddfa5fbccb8b59621179798e6dc905c9bf8af3b34-kubernetes-cni-0.7.5-0.x86_64.rpm
Worker 1: reading Packages/79f9ba89dbe7000e7dfeda9b119f711bb626fe2c2d56abeb35141142cda00342-kubernetes-cni-0.5.1-1.x86_64.rpm
Worker 0: reading Packages/7d9e0a47eb6eaf5322bd45f05a2360a033c29845543a4e76821ba06becdca6fd-kubelet-1.17.0-0.x86_64.rpm
Worker 1: reading Packages/b44630896c69cd411db53be1d5cb5ae899a40aba7c0766317ea904390fcfc45b-kubectl-1.17.2-0.x86_64.rpm
Worker 0: reading Packages/bf67b612b185159556555b03e1e3a1ac5b10096afe48e4a7b7f5f9c4542238eb-kubectl-1.17.0-0.x86_64.rpm
Worker 1: reading Packages/e253c692a017b164ebb9ad1b6537ff8afd93c35e9ebc340a52c5bd42425c0760-cri-tools-1.11.0-0.x86_64.rpm
Worker 0: reading Packages/e7a4403227dd24036f3b0615663a371c4e07a95be5fee53505e647fd8ae58aa6-kubernetes-cni-0.5.1-0.x86_64.rpm
Worker 1: reading Packages/f70d8cb23c7b91c0509292f4862060367edabce8788b855c38a7c174f014b9e2-cri-tools-1.11.1-0.x86_64.rpm
Worker 0: reading Packages/fe33057ffe95bfae65e2f269e1b05e99308853176e24a4d027bc082b471a07c0-kubernetes-cni-0.6.0-0.x86_64.rpm
Workers Finished
Saving Primary metadata
Saving file lists metadata
Saving other metadata
Generating sqlite DBs
Starting other db creation: Sun Feb  2 04:56:18 2020
Ending other db creation: Sun Feb  2 04:56:18 2020
Starting filelists db creation: Sun Feb  2 04:56:18 2020
Ending filelists db creation: Sun Feb  2 04:56:18 2020
Starting primary db creation: Sun Feb  2 04:56:18 2020
Ending primary db creation: Sun Feb  2 04:56:18 2020
Sqlite DBs complete
~~~
