## Simple kube - playbook to deploy one node kubernetes cluster on CentOS 7.x
Deploy kubernetes cluster (1.16.x/1.17.x) on CentOS 7.x with docker and
flannel in `host-gw` mode in 4 minutes or less.

Configurable options:
- `kubernetes_version` - version of kubernetes which to install
- `pod_network` - Network that will be used for pods

This platbook is expected to fail on 'Do preflight check for kubernetes deployment' task 
if kubernetes is already installed or if there is any other issue with OS.

Flannel deployment recommended in kubernetes 1.16.x/1.17.x documentation is included here as template with amd64 architecture only.
