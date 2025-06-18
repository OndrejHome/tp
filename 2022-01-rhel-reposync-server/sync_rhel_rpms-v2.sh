#!/bin/bash
# variables obtained from parameters
entitlement_dir="$1"
base_url="$2"
repo_id="$3"
repo_url="$4"
download_dir="$5"
latest_all="${6:-latest}"
# hard-coded variables
rpms_subdir='rpms'
repodata_subdir='repodata'
repo_state_file="$download_dir/repo-state.html"

## ===== initial variables checks and help message
if [ "$#" -lt '5' ]; then
  echo "$0 /dir/with/entitlements http://local-base-url repo-id http://repo.url/rhel-release/something /dir/for/download [latest|all]"
cat <<EOF
=== '/dir/with/entitlements' is expected to have following structure ===
/dir/with/entitlements/1234567890-key.pem 
  - from /etc/pki/entitlement/ directory on RHEL system after registering system
/dir/with/entitlements/1234567890.pem 
  - from /etc/pki/entitlement/ directory on RHEL system after registering system
/dir/with/entitlements/extra/RPM-GPG-KEY-redhat-release 
  - from /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release on RHEL system
/dir/with/entitlements/extra/redhat-uep.pem 
  - from /etc/rhsm/ca/redhat-uep.pem on RHEL system
===
EOF
  exit 1
fi

# validation of received parameters
if [ ! -d "$entitlement_dir" ]; then
  echo "$entitlement_dir is not a directory!"
  exit 1
fi

if [ ! -f $entitlement_dir/extra/RPM-GPG-KEY-redhat-release ]; then
  echo "'$entitlement_dir/extra/RPM-GPG-KEY-redhat-release' file missing! Get it from RHEL system (/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release)"
  exit 1
fi
if [ ! -f $entitlement_dir/extra/redhat-uep.pem ]; then
  echo "'$entitlement_dir/extra/redhat-uep.pem' file missing! Get it from RHEL system (/etc/rhsm/ca/redhat-uep.pem)"
  exit 1
fi

if [ ! -d "$download_dir" ]; then
  echo "'$download_dir' is not a directory!"
  exit 1
fi

if [ ! -f "$repo_state_file" ]; then
  echo "'$repo_state_file' file is missing or not a file!"
  exit 1
fi

if [ "$latest_all" != 'latest' ] && [ "$latest_all" != 'all' ]; then
  echo "if specified, last parameter must be either 'latest' (default if not specified) or 'all'"
  exit 1
fi

## ===== entitlement check
entitlement_key_file=$(echo $entitlement_dir/[0-9]*-key.pem|cut -d' ' -f1)
entitlement_cert_file=$(echo $entitlement_key_file |sed 's/-key.pem/.pem/')
if [ ! -f "$entitlement_key_file" ] || [ ! -f "$entitlement_cert_file" ]; then
  echo "Entitlement certificate file or key is missing, make sure that '$entitlement_dir' contains both entitlement cert and key file."
  exit 1
fi

### === MAIN part ===

# mark repository as 'repocheck'
if grep -q "td>$repo_id<" "$repo_state_file"; then
  sed -i "s;^.*td>$repo_id<.*$;<tr><td>== repocheck ==</td><td>$(date '+%Y-%m-%d %H:%M')</td><td>$repo_id</td><td><a href='$base_url/$rpms_subdir/${repo_id}.repo'>${repo_id}.repo</a></td></tr>;" "$repo_state_file"
else
  # if there is no line with repository, then create it in first table on page
  awk -i inplace -v "date=$(date '+%Y-%m-%d %H:%M')" -v "repourl=$base_url/$rpms_subdir/$repo_id.repo" -v "reponame=$repo_id" '{print} /<tbody>/ && !x {printf "<tr><td>== repocheck ==</td><td>%s</td><td>%s</td><td><a href=\"%s\">%s.repo</a></td></tr>\n",date,reponame,repourl,reponame; x++}' "$repo_state_file"
fi

# test if we are able to retrieve repository using the cert we have
curl --fail -k --cert "$entitlement_cert_file" --key "$entitlement_key_file" --head "$repo_url/repodata/repomd.xml" >/dev/null 2>&1
repo_acess_check="$?"
if [ "$repo_acess_check" = "0" ]; then
	echo "We can access repository data, proceeding with download"
  	sed -i "s;^.*td>$repo_id<.*$;<tr><td>OK repo access</td><td>$(date '+%Y-%m-%d %H:%M')</td><td>$repo_id</td><td><a href='$base_url/$rpms_subdir/${repo_id}.repo'>${repo_id}.repo</a></td></tr>;" "$repo_state_file"
else
	echo "We cannot get repository metadata with this ($entitlement_cert_file) certificate. giving up - exit code $repo_acess_check"
  	sed -i "s;^.*td>$repo_id<.*$;<tr><td>ERROR no repo access</td><td>$(date '+%Y-%m-%d %H:%M')</td><td>$repo_id</td><td><a href='$base_url/$rpms_subdir/${repo_id}.repo'>${repo_id}.repo</a></td></tr>;" "$repo_state_file"
	exit 2
fi
## =====

tmp_config_file=$(mktemp --suffix=.repo)
cat > "$tmp_config_file" <<EOF
[$repo_id]
name = $repo_id
baseurl = $repo_url
enabled = 1
gpgcheck = 1
gpgkey = file://$entitlement_dir/extra/RPM-GPG-KEY-redhat-release
sslverify = 1
sslcacert = $entitlement_dir/extra/redhat-uep.pem
sslclientkey = $entitlement_key_file
sslclientcert = $entitlement_cert_file
metadata_expire = 86400
enabled_metadata = 0
EOF
echo "Created temporary config '$tmp_config_file'"

## =====
echo "Creating repository directories and metadata symlinks..."
# 1/3
if [ ! -d "$download_dir/$rpms_subdir/$repo_id" ]; then
	mkdir "$download_dir/$rpms_subdir/$repo_id"
fi
# 2/3
if [ ! -d "$download_dir/$repodata_subdir/$repo_id" ]; then
	mkdir "$download_dir/$repodata_subdir/$repo_id"
fi
# 3/3
if [ ! -L "$download_dir/$rpms_subdir/$repo_id/repodata" ]; then
	ln -s "../../$repodata_subdir/$repo_id/repodata" "$download_dir/$rpms_subdir/$repo_id/repodata"
fi

sed -i "s;^.*td>$repo_id<.*$;<tr><td>== syncing ==</td><td>$(date '+%Y-%m-%d %H:%M')</td><td>$repo_id</td><td><a href='$base_url/$rpms_subdir/${repo_id}.repo'>${repo_id}.repo</a></td></tr>;" "$repo_state_file"

echo "Downloading packages ..."
echo "  download_dir: $download_dir/$rpms_subdir/$repo_id"
echo "  repodata_dir: $download_dir/$repodata_subdir/$repo_id/repodata"
if [ "$latest_all" == 'latest' ]; then 
  latest_flag='-n'
  echo "  (downloading only latest packages in this repository)"
else
  latest_flag=""
  echo "  (downloading ALL packages in this repository)"
fi
if reposync -c "$tmp_config_file" --repo "$repo_id" $latest_flag --delete -p "$download_dir/$rpms_subdir" --download-metadata --metadata-path "$download_dir/$repodata_subdir" --delete --remote-time; then
	sed -i "s;^.*td>$repo_id<.*$;<tr><td>OK</td><td>$(date '+%Y-%m-%d %H:%M')</td><td>$repo_id</td><td><a href='$base_url/$rpms_subdir/${repo_id}.repo'>${repo_id}.repo</a></td></tr>;" "$repo_state_file"
	echo "Download succeeded, removing temporary repo file $tmp_config_file"
	rm -f "$tmp_config_file"
	echo "Repository size summary:"
	echo "  download_dir: $download_dir/$rpms_subdir/$repo_id ($(du -sh "$download_dir/$rpms_subdir/$repo_id"|awk '{print $1}'))"
	echo "  repodata_dir: $download_dir/$repodata_subdir/$repo_id/repodata ($(du -sh "$download_dir/$repodata_subdir/$repo_id/repodata"|awk '{print $1}'))"
else
	sed -i "s;^.*td>$repo_id<.*$;<tr><td>SYNC ERROR</td><td>$(date '+%Y-%m-%d %H:%M')</td><td>$repo_id</td><td><a href='$base_url/$rpms_subdir/${repo_id}.repo'>${repo_id}.repo</a></td></tr>;" "$repo_state_file"
fi
echo "Generating .repo file and checking its presence on webserver..."
cat > "$download_dir/$rpms_subdir/$repo_id.repo" <<EOF
[$repo_id]
metadata_expire = 86400
enabled_metadata = 1
baseurl = $base_url/$rpms_subdir/$repo_id
ui_repoid_vars = basearch
name = reposync: $repo_id
gpgkey = file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
enabled = 1
gpgcheck = 1
EOF
if curl --fail -k --head "$base_url/$rpms_subdir/$repo_id.repo" >/dev/null 2>&1; then
  echo "OK, repo file exists at $base_url/$rpms_subdir/$repo_id.repo"
else
  echo "Failed to download repo file from $base_url/$rpms_subdir/$repo_id.repo"
fi
echo "DONE"
## =====
