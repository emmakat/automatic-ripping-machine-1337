###########################################################
# setup default directories and configs
FROM shitwolfymakes/arm-dependencies AS base

# override at runtime to match user that ARM runs as local user
ENV RUN_AS_USER=true
ENV UID=1000
ENV GID=1000

WORKDIR /opt/arm

RUN \
    mkdir -m 0777 -p /home/arm /home/arm/config /mnt/dev/sr0 /mnt/dev/sr1 /mnt/dev/sr2 /mnt/dev/sr3 && \
    echo "/dev/sr0  /mnt/dev/sr0  udf,iso9660  users,noauto,exec,utf8,ro  0  0" >> /etc/fstab && \
    echo "/dev/sr1  /mnt/dev/sr1  udf,iso9660  users,noauto,exec,utf8,ro  0  0" >> /etc/fstab && \
    echo "/dev/sr2  /mnt/dev/sr2  udf,iso9660  users,noauto,exec,utf8,ro  0  0" >> /etc/fstab && \
    echo "/dev/sr3  /mnt/dev/sr3  udf,iso9660  users,noauto,exec,utf8,ro  0  0" >> /etc/fstab

# copy ARM source last, helps with Docker build caching
COPY . /opt/arm/

EXPOSE 8080

VOLUME /home/arm/Music
VOLUME /home/arm/logs
VOLUME /home/arm/media
VOLUME /etc/arm/config

WORKDIR /home/arm

ENTRYPOINT ["/opt/arm/scripts/docker/docker-entrypoint.sh"]
CMD ["python3", "/opt/arm/arm/runui.py"]

###########################################################
# setup default directories and configs
FROM base as automatic-ripping-machine

LABEL org.opencontainers.image.source=https://github.com/1337-server/automatic-ripping-machine
LABEL org.opencontainers.image.license=MIT
