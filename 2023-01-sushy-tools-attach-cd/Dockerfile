FROM registry.hub.docker.com/library/python:3.9-slim

ARG SUSHY_TOOLS_VERSION="0.21.1"
ARG DEBIAN_FRONTEND=noninteractive

ADD patch-v3.patch /tmp

RUN apt-get update && \
    apt-get install -y libvirt-dev gcc ssh patch && \
    apt-get clean && \
    pip3 install --no-cache-dir \
        sushy-tools==${SUSHY_TOOLS_VERSION} libvirt-python && apt-get remove -y gcc && apt -y autoremove && patch -p1 < /tmp/patch-v3.patch

CMD /usr/local/bin/sushy-emulator -i :: \
        --config /root/sushy/conf.py --debug
