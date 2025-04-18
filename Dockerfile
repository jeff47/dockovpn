# Modified this version to compile OpenVPN with XOR

# Update this to point to the current version of openvpn (must be in the Tunnelblick repo)
ARG openvpn_version=openvpn-2.6.14

# Smallest base image, using alpine with glibc
#FROM alpine:3.14.1
FROM alpine:latest AS build

ARG openvpn_version

LABEL maintainer="Jeffrey Rice <jeff@jeffrice.net>"

RUN apk update && \
        apk add --update \
          autoconf \
          automake \
          build-base \
          libcap-ng-dev \
          linux-headers \
          openssl-dev \
          libnl3-dev

# OpenVPN with XOR patches from Tunnelblick
COPY ./Tunnelblick/third_party/sources/openvpn/$openvpn_version/ /usr/src

RUN cd /usr/src \
  && tar xf $openvpn_version.tar.gz  \
  && cd /usr/src/$openvpn_version \
  && patch -p1 < ../patches/02-tunnelblick-openvpn_xorpatch-a.diff \
  && patch -p1 < ../patches/03-tunnelblick-openvpn_xorpatch-b.diff \
  && patch -p1 < ../patches/04-tunnelblick-openvpn_xorpatch-c.diff \
  && patch -p1 < ../patches/05-tunnelblick-openvpn_xorpatch-d.diff \
  && patch -p1 < ../patches/06-tunnelblick-openvpn_xorpatch-e.diff \
  && patch -p1 < ../patches/10-route-gateway-dhcp.diff

RUN cd /usr/src/$openvpn_version && \
        ./configure \
          --enable-static=yes \
          --enable-shared \
          --disable-debug \
          --disable-plugin-auth-pam \
          --disable-lzo \
          --disable-lz4 \
          --with-openssl-engine && \
        make 

# Final image
FROM alpine:latest
ARG openvpn_version

# System settings. User normally shouldn't change these parameters
ENV APP_NAME=Dockovpn
ENV APP_INSTALL_PATH=/opt/${APP_NAME}
ENV APP_PERSIST_DIR=/opt/${APP_NAME}_data

# Configuration settings with default values
ENV NET_ADAPTER eth0
ENV HOST_ADDR ""
ENV HOST_TUN_PORT 1194
ENV HOST_CONF_PORT 80
ENV HOST_TUN_PROTOCOL udp
ENV CRL_DAYS 3650

WORKDIR ${APP_INSTALL_PATH}

COPY scripts .
COPY config ./config
COPY VERSION ./config

COPY --from=build /usr/src/$openvpn_version/src/openvpn/openvpn /usr/sbin/

RUN apk update && apk add --no-cache easy-rsa bash netcat-openbsd libnl3 zip curl dumb-init libcap-ng iptables && \
    ln -s /usr/share/easy-rsa/easyrsa /usr/bin/easyrsa && \
    mkdir -p ${APP_PERSIST_DIR} && \
    cd ${APP_PERSIST_DIR} && \
    easyrsa init-pki && \
    easyrsa gen-dh && \
    # DH parameters of size 2048 created at /usr/share/easy-rsa/pki/dh.pem
    # Copy DH file 
    mkdir -p /etc/openvpn && \
    cp pki/dh.pem /etc/openvpn && \
    # Copy FROM ./scripts/server/conf TO /etc/openvpn/server.conf in DockerFile
    cd ${APP_INSTALL_PATH} && \
    cp config/server.conf /etc/openvpn/server.conf


EXPOSE 1194/${HOST_TUN_PROTOCOL}
EXPOSE 8080/tcp

VOLUME [ "/opt/Dockovpn_data" ]

ENTRYPOINT [ "dumb-init", "./start.sh"]
CMD [ "" ]
