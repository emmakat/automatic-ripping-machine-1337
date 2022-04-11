###########################################################
# base image, used for build stages and final images
FROM 1337server/arm-dependencies:latest as base
# override at runtime to match user that ARM runs as local user
ENV RUN_AS_USER=false
ENV UID=1000
ENV GID=1000
# override at runtime to change makemkv key
ENV MAKEMKV_APP_KEY=""

# local apt/deb proxy for builds
ARG APT_PROXY=""
RUN if [ -n "${APT_PROXY}" ] ; then \
  printf 'Acquire::http::Proxy "%s";' "${APT_PROXY}" \
  > /etc/apt/apt.conf.d/30proxy ; fi

WORKDIR /opt/arm
## Create a user group
RUN  \
    groupadd -g 1001 arm && \
    useradd -r -s /bin/bash -g cdrom -G arm -u 1001 arm && \
    chown -R arm:arm /opt/arm
# Default directories and configs
COPY ./docs/arm.yaml.sample /opt/arm/arm.yaml
COPY ./docs/apprise.yaml /opt/arm/apprise.yaml
RUN \
  echo "/dev/sr0  /mnt/dev/sr0  udf,iso9660  users,noauto,exec,utf8,ro  0  0" >> /etc/fstab  && \
  echo "/dev/sr1  /mnt/dev/sr1  udf,iso9660  users,noauto,exec,utf8,ro  0  0" >> /etc/fstab  && \
  echo "/dev/sr2  /mnt/dev/sr2  udf,iso9660  users,noauto,exec,utf8,ro  0  0" >> /etc/fstab  && \
  echo "/dev/sr3  /mnt/dev/sr3  udf,iso9660  users,noauto,exec,utf8,ro  0  0" >> /etc/fstab  && \
  echo "/dev/sr4  /mnt/dev/sr4  udf,iso9660  users,noauto,exec,utf8,ro  0  0" >> /etc/fstab


# copy ARM source last, helps with Docker build caching
COPY . /opt/arm/

# These shouldnt be needed as docker-entrypoint.sh should do it
RUN \
  ln -sf /home/arm/config/arm.yaml /opt/arm/arm.yaml && \
  ln -sf /home/arm/config/apprise.yaml /opt/arm/apprise.yaml && \
  ln -sf /home/arm/config/.abcde.conf /opt/arm/setup/.abcde.conf \
  ln -sf "/opt/arm/setup/.abcde.conf" "/root"


# Disable SSH
RUN rm -rf /etc/service/sshd /etc/my_init.d/00_regen_ssh_host_keys.sh

# Create our startup scripts
RUN mkdir -p /etc/my_init.d
COPY ./docker/start/start_aaudev.sh /etc/my_init.d/start_udev.sh
COPY ./docker/start/start_armui.sh /etc/my_init.d/start_armui.sh
#COPY docker/start/start_ripper.sh /etc/my_init.d/start_ripper.sh
COPY ./docker/start/docker-entrypoint.sh /etc/my_init.d/docker-entrypoint.sh

# We need to use a modified udev
COPY ./docker/udev /etc/init.d/udev
# Copy the docker version file
COPY ./docker/VERSION /opt/arm/
RUN chmod +x /etc/my_init.d/*.sh

# Our docker udev rule
RUN ln -sv /opt/arm/setup/51-automedia-docker.rules /lib/udev/rules.d/

EXPOSE 8080
#VOLUME /home/arm
VOLUME /home/arm/music
VOLUME /home/arm/logs
VOLUME /home/arm/media
VOLUME /home/arm/config
WORKDIR /home/arm


CMD ["/sbin/my_init"]

LABEL org.opencontainers.image.source=https://github.com/1337-server/automatic-ripping-machine
LABEL org.opencontainers.image.revision="2.6.1"
LABEL org.opencontainers.image.created="2022-04-10"
LABEL org.opencontainers.image.license=MIT
