#!/bin/bash
if [ ! -d "$1" ]; then
  echo "$0 /repos/rpms/repo-directory http://base/url/to/rpms"
  exit 1
fi
if [ -z "$2" ]; then
  echo "$0 /repos/rpms/repo-directory http://base/url/to/rpms"
  exit 1
fi

reponame=$(basename "$1")
cat > "/repos/rpms/${reponame}.repo" <<EOF
[$reponame]
metadata_expire = 86400
enabled_metadata = 1
baseurl = $2/$reponame
ui_repoid_vars = basearch
name = reposync: $reponame
gpgkey = file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
enabled = 1
gpgcheck = 1
EOF
