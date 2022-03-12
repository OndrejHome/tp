#!/bin/bash
template_file='/root/template.repo'
download_dir=${download_dir:-/repos}
rpms_subdir='rpms'
repodata_subdir='repodata'
base_url='http://192.168.5.31'
repo_state_file="$download_dir/repo-state.html"
## ===== initial variables checks
if [ "$#" -lt '2' ]; then
  echo "./$0 repo-id http://repo.url/rhel-release/something [download_directory/]"
  exit 1
fi

if [ ! -f "$template_file" ]; then
  echo "'$template_file' is not a file!"
  exit 1
fi

if [ ! -d "$download_dir" ]; then
  echo "'$download_dir' is not a directory!"
  exit 1
fi

## ===== entitlement check
entitlement_cert_file=$(grep sslclientcert "$template_file" |cut -d= -f 2|tr -d ' ')
if [ ! -f "$entitlement_cert_file" ]; then
  echo "Entitlement certificate file is missing, replacing with first available one"
  # get the ID of first entitlement key
  new_entitlement_id=$(echo /etc/pki/entitlement/*-key.pem|cut -d' ' -f1|sed 's#/etc/pki/entitlement/\([0-9]\+\)-key.pem#\1#')
  # replace entitlement ID in template with new one
  sed -i "s#/etc/pki/entitlement/[0-9]\+#/etc/pki/entitlement/${new_entitlement_id}#" "$template_file"
fi

# mark repository as 'repocheck'
if grep -q "td>$1<" "$repo_state_file"; then
  sed -i "s;^.*td>$1<.*$;<tr><td>== repocheck ==</td><td>$(date '+%Y-%m-%d %H:%M')</td><td>$1</td><td><a href='$base_url/$rpms_subdir/${1}.repo'>${1}.repo</a></td></tr>;" "$repo_state_file"
else
  # if there is no line with repository, then create it in first table on page
  awk -i inplace -v "date=$(date '+%Y-%m-%d %H:%M')" -v "repourl=$base_url/$rpms_subdir/$1.repo" -v "reponame=$1" '{print} /<tbody>/ && !x {printf "<tr><td>== repocheck ==</td><td>%s</td><td>%s</td><td><a href=\"%s\">%s.repo</a></td></tr>",date,reponame,repourl,reponame; x++}' "$repo_state_file"
fi

# test if we are able to retrieve repository using the cert we have
key_file="${entitlement_cert_file//\.pem/-key.pem}"
curl --fail -k --cert "$entitlement_cert_file" --key "$key_file" --head "$2/repodata/repomd.xml" >/dev/null 2>&1
repo_acess_check="$?"
if [ "$repo_acess_check" = "0" ]; then
	echo "We can access repository data, proceeding with download"
  	sed -i "s;^.*td>$1<.*$;<tr><td>OK repo access</td><td>$(date '+%Y-%m-%d %H:%M')</td><td>$1</td><td><a href='$base_url/$rpms_subdir/${1}.repo'>${1}.repo</a></td></tr>;" "$repo_state_file"
else
	echo "We cannot get repository metadata with this ($entitlement_cert_file) certificate. giving up - exit code $repo_acess_check"
  	sed -i "s;^.*td>$1<.*$;<tr><td>ERROR no repo access</td><td>$(date '+%Y-%m-%d %H:%M')</td><td>$1</td><td><a href='$base_url/$rpms_subdir/${1}.repo'>${1}.repo</a></td></tr>;" "$repo_state_file"
	exit 2
fi
## =====

tmp_config_file=$(mktemp --suffix=.repo)
sed "s#REPONAME#$1#g; s#REPOURL#$2#g;" "$template_file" > "$tmp_config_file"
echo "Created temporary config '$tmp_config_file'"

## =====
echo "Creating repository directories and metadata symlinks..."
# 1/3
if [ ! -d "$download_dir/$rpms_subdir/$1" ]; then
	mkdir "$download_dir/$rpms_subdir/$1"
fi
# 2/3
if [ ! -d "$download_dir/$repodata_subdir/$1" ]; then
	mkdir "$download_dir/$repodata_subdir/$1"
fi
# 3/3
if [ ! -L "$download_dir/$rpms_subdir/$1/repodata" ]; then
	ln -s "../../$repodata_subdir/$1/repodata" "$download_dir/$rpms_subdir/$1/repodata"
fi

sed -i "s;^.*td>$1<.*$;<tr><td>== syncing ==</td><td>$(date '+%Y-%m-%d %H:%M')</td><td>$1</td><td><a href='$base_url/$rpms_subdir/${1}.repo'>${1}.repo</a></td></tr>;" "$repo_state_file"

echo "Downloading packages ..."
echo "  download_dir: $download_dir/$rpms_subdir/$1"
echo "  repodata_dir: $download_dir/$repodata_subdir/$1/repodata"
if reposync -c "$tmp_config_file" --repo "$1" -n --delete -p "$download_dir/$rpms_subdir" --download-metadata --metadata-path "$download_dir/$repodata_subdir" --delete --remote-time; then
	sed -i "s;^.*td>$1<.*$;<tr><td>OK</td><td>$(date '+%Y-%m-%d %H:%M')</td><td>$1</td><td><a href='$base_url/$rpms_subdir/${1}.repo'>${1}.repo</a></td></tr>;" "$repo_state_file"
	echo "Download succeeded, removing temporary repo file $tmp_config_file"
	rm -f "$tmp_config_file"
	echo "Repository size summary:"
	echo "  download_dir: $download_dir/$rpms_subdir/$1 ($(du -sh "$download_dir/$rpms_subdir/$1"|awk '{print $1}'))"
	echo "  repodata_dir: $download_dir/$repodata_subdir/$1/repodata ($(du -sh "$download_dir/$repodata_subdir/$1/repodata"|awk '{print $1}'))"
else
	sed -i "s;^.*td>$1<.*$;<tr><td>SYNC ERROR</td><td>$(date '+%Y-%m-%d %H:%M')</td><td>$1</td><td><a href='$base_url/$rpms_subdir/${1}.repo'>${1}.repo</a></td></tr>;" "$repo_state_file"
fi
echo "Generating .repo file and checking its presence on webserver..."
cat > "$download_dir/$rpms_subdir/$1.repo" <<EOF
[$1]
metadata_expire = 86400
enabled_metadata = 1
baseurl = $base_url/$rpms_subdir/$1
ui_repoid_vars = basearch
name = reposync: $1
gpgkey = file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
enabled = 1
gpgcheck = 1
EOF
if curl --fail -k --head "$base_url/$rpms_subdir/$1.repo" >/dev/null 2>&1; then
  echo "OK, repo file exists at $base_url/$rpms_subdir/$1.repo"
else
  echo "Failed to download repo file from $base_url/$rpms_subdir/$1.repo"
fi
echo "DONE"
## =====
