#!/bin/bash
repo_file="$1"
repo_name="$2"
if [ ! -f "/repos/$repo_file" ]; then
  echo "'/repos/$repo_file' is not a file, adjust the REPO_FILE variable."
  exit 1
fi
echo "Preparing yum cache with 'yum makecache -y -c /repos/$repo_file'"
yum makecache -y -c "/repos/$repo_file"
echo "Syncing repository with 'reposync -c /repos/$repo_file -r $repo_name -p /data'"
reposync -c "/repos/$repo_file" -r "$repo_name" -p /data
echo "Generating repo metadata with 'createrepo -v /data/$repo_name'"
createrepo -v "/data/$repo_name"
