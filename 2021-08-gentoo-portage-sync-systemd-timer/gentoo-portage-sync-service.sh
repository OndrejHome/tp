#!/bin/bash
# based on example from https://wiki.gentoo.org/wiki/Project:Infrastructure/Mirrors/Rsync#Fetching_data  
RSYNC="/usr/bin/rsync"
OPTS="--recursive --links --perms --times -D --delete --timeout=300 --checksum -v"
SRC="rsync://rsync.us.gentoo.org/gentoo-portage" # for the rest of the world
DST="/mnt/gentoo-portage/"
  
echo "Started update at" `date` 
${RSYNC} ${OPTS} ${SRC} ${DST} 
echo "End: "`date` 

## ===================================
echo "Start verification"
if gemato verify -R -K /usr/share/openpgp-keys/gentoo-release.asc /mnt/gentoo-portage; then
  echo "Verification OK"
else
  echo "Verification FAILED"
  exit 1
fi
