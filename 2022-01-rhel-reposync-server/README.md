## Simple reposync server for RHEL rpms
Goal of script here is to provide minimal infrastructure for downloading RPMs from RHEL repos and generate simple '.repo' file that can be easily consumed by local services. Typically this will run on machine that has both access to Internet and to local network on which machines will consume the repositories.

Script accepts 2 argumentes:
- 1st custom name of RPM repository
- 2nd URL to RH CDN for directory to download

Before syncing the RPM repository script will check if it can access the repository on CDN and exit if it fails - this might be normal when there are multiple "entitlement certificates" on system, script will always select first available. If other certificate is desirable, you can edit the `template.repo` file to specify it manually. NOTE: on RHEL these certificates gets rotated over time.

Downloaded repository contain latest only packages - you can edit file and remove `-n` to download all packages.
RPMs and repository metadata are stored in 2 different repositories and are symlinked together - motivation for this is to allow placing metadata on separate disk from RPMs if desired. (this makes sense for VDO where RPMs can be deduplicated among different repositories, while repodata are mostly different between repositories and not worth deduplicating)

SIDE NOTE: Motivation for creating this script was lack of simple tooling that can do RPM repository sync and provide easy way to use '.repo' files on various test systems. Satellite compared to this was overkill that requires a ton of resources.

### Installation
- make sure your RHEL system is registered and have subscription atached to it
- install `yum-utils` package
- get all files from this directory on your system
  - `sync_rhel_rpms-latest.sh` - main sync script with configuration
  - `repo-state.html` - webpage with table showing sync status and links to '.repo' files
  - `sortable.js` - (optional) javascript to enable sorting within webpage tables
  - `template.repo` - writable file that will be used when syncing repositories
- install webserver on local machine and start it (further examples will assume that webserver can be reached via http://192.168.5.31/ URL)
- decide to which directories the script will download RPM repositories and edit `sync_rhel_rpms-latest.sh` script to reflect that
  - `download_dir` - based directory for downloads (inside web root) - example `/repos`
  - `base_url` - URL to 'download_dir` - example `http://192.168.5.31`
  - `repo_state_file` - path to webpage showing sync states and links for '.repo' files - example `/repos/repo-state.html`
  - `rpms_subdir` - subdirectory for RPM repositories - example `rpms` -> `/repos/rpms` will contain directories with RPM repositories
  - `repodata_subdir` - subdirectory for RPM repositories metadata - example `repodata` -> `/repos/repodata` will contain directories with RPM repository metadata
  - `template_file` - path to `template.repo` file, this file must be writable to script - example `/root/template.repo`
- check that you can see the `repo-state.html` file at webserver location - example `http://192.168.5.31/repo-state.html`

### Usage
- to get URL for downloading/syncing repo try command
~~~
# subscription manager repos
...
+----------------------------------------------------------+
    Available Repositories in /etc/yum.repos.d/redhat.repo
+----------------------------------------------------------+
...
Repo ID:   some-rhel-8-rpms
Repo Name: RHEL RPMs for product xyz (x86_64) RHEL8
Repo URL:  https://cdn.redhat.com/content/...
Enabled:   0
...
~~~
- run the sync of repository with information you got from previous command
~~~
# sync_rhel_rpms-latest.sh my-repo-name https://cdn.redhat.com/content/...
~~~
- once sync finishes the `my-repo-name.repo` will be created, this will be listed on webpage and can be downloaded by other systems for use
~~~
# cd /etc/yum.repos.d/
# curl -O http://192.168.5.31/rpms/my-repo-name.repo
# yum repolist
...
repo id                         repo name
my-repo-name                    reposync: my-repo-name
~~~
