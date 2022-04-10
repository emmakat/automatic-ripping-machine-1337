###########################################################
# base image, used for build stages and final images
#FROM ubuntu:20.04 as base
FROM phusion/baseimage:focal-1.2.0 as base
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

RUN mkdir /opt/arm
WORKDIR /opt/arm

COPY ./scripts/add-ppa.sh /root/add-ppa.sh
# setup Python virtualenv and gnupg/wget for add-ppa.sh
RUN \
  apt update -y && \
  DEBIAN_FRONTEND=noninteractive apt upgrade -y && \
  DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    gnupg \
    gosu \
    python3 \
    python3-venv \
    udev \
    wget \
    build-essential \
    nano \
    vim \
    lsdvd \
    && \
  DEBIAN_FRONTEND=noninteractive apt clean -y && \
  rm -rf /var/lib/apt/lists/*


###########################################################
# build libdvd in a separate stage, pulls in tons of deps
FROM base as libdvd


RUN \
  bash /root/add-ppa.sh ppa:mc3man/focal6 && \
  apt update -y && \
  DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends libdvd-pkg && \
  DEBIAN_FRONTEND=noninteractive dpkg-reconfigure libdvd-pkg && \
  DEBIAN_FRONTEND=noninteractive apt clean -y && \
  rm -rf /var/lib/apt/lists/*

###########################################################
# build pip reqs for ripper in separate stage
FROM base as dep-ripper
RUN \
  apt update -y && \
  DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    build-essential \
    libcurl4-openssl-dev \
    libssl-dev \
    python3 \
    python3-dev \
    python3-pyudev \
    python3-wheel \
    udev \
    libudev-dev \
    python3-pip \
    && \
  pip3 install --upgrade pip wheel setuptools \
  && \
  pip3 install pyudev

###########################################################
# install deps for ripper
FROM base as pip-ripper
RUN \
  bash /root/add-ppa.sh ppa:heyarje/makemkv-beta && \
  bash /root/add-ppa.sh ppa:stebbins/handbrake-releases && \
  apt update -y && \
  DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    abcde \
    eyed3 \
    atomicparsley \
    cdparanoia \
    eject \
    ffmpeg \
    flac \
    glyrc \
    default-jre-headless \
    handbrake-cli \
    libavcodec-extra \
    makemkv-bin \
    makemkv-oss \
    udev \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    libudev-dev \
    python3-wheel \
    python-psutil \
    python3-pyudev \
    && \
    pip3 install wheel \
    && \
    pip3 install --upgrade pip wheel setuptools \
    && \
    pip3 install --upgrade psutil \
    && \
    pip3 install pyudev \
    && \
  DEBIAN_FRONTEND=noninteractive apt clean -y && \
  rm -rf /var/lib/apt/lists/*

# copy just the .deb from libdvd build stage
COPY --from=libdvd /usr/src/libdvd-pkg/libdvdcss2_*.deb /opt/arm

# installing with --ignore-depends to avoid all it's deps
# leaves apt in a broken state so do package install last
RUN DEBIAN_FRONTEND=noninteractive dpkg -i --ignore-depends=libdvd-pkg /opt/arm/libdvdcss2_*.deb

# Copy both sets of requirements.txt and install them
COPY ./docker/requirements/requirements.ripper.txt /requirements.ripper.txt
COPY ./docker/requirements/requirements.ui.txt /requirements.ui.txt
RUN    \
  pip3 install \
    --ignore-installed \
    --prefer-binary \
    -r /requirements.ui.txt \
  && \
  pip3 install \
    --ignore-installed \
    --prefer-binary \
    -r /requirements.ripper.txt

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
# Create a user group
RUN addgroup arm
RUN useradd -r -s /bin/bash -g cdrom -G "${GID}" -u "${UID}" arm
RUN chown -R arm:arm /opt/arm
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
COPY docker/start/start_aaudev.sh /etc/my_init.d/start_udev.sh
COPY docker/start/start_armui.sh /etc/my_init.d/start_armui.sh
#COPY docker/start/start_ripper.sh /etc/my_init.d/start_ripper.sh
COPY docker/start/docker-entrypoint.sh /etc/my_init.d/docker-entrypoint.sh

# We need to use a modified udev
COPY docker/udev /etc/init.d/udev
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
