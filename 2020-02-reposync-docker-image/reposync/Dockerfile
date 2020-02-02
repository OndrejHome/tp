FROM centos:7.7.1908
LABEL maintainer="ondrej-xa2iel8u@famera.cz"
RUN yum install -y yum-utils createrepo && yum clean all && rm -f /etc/yum.repos.d/*repo && rm -rf /var/cache/yum/

ENV REPO_NAME base
ENV REPO_FILE base.repo 
ADD sync.sh /root
VOLUME /repos
VOLUME /data
ENTRYPOINT /bin/bash /root/sync.sh "${REPO_FILE}" "${REPO_NAME}"
