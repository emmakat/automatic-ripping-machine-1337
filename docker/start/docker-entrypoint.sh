#!/bin/bash
#
# set up a user and switch to that user

set -euo pipefail

export USER=arm
export HOME="/home/${USER}"

# setup needed/expected dirs if not found
SUBDIRS="config media media/completed media/raw media/movies logs db music .MakeMKV"
for dir in $SUBDIRS ; do
  thisDir="${HOME}/${dir}"
  if [[ ! -d "${thisDir}" ]] ; then
    echo "creating dir ${thisDir}"
    mkdir -p -m 0777 "${thisDir}"
    chown -R "${USER}.${USER}" "${thisDir}"
  fi
done
# setup needed/expected mnt paths if not found
SUBDIRS="sr0 sr1 sr2 sr3 sr4"
for dir in $SUBDIRS ; do
  thisDir="/mnt/dev/${dir}"
  if [[ ! -d "${thisDir}" ]] ; then
    echo "creating dir ${thisDir}"
    mkdir -p -m 0777 "${thisDir}"
    chown -R "${USER}.${USER}" "${thisDir}"
  fi
done

if [[ ! -f "${HOME}/config/arm.yaml" ]] ; then
  echo "Creating example ARM config ${HOME}/config/arm.yaml"
  cp /opt/arm/docs/arm.yaml.sample "${HOME}/config/arm.yaml"
  chown "${USER}.${USER}" "${HOME}/config/arm.yaml"
fi
if [[ ! -f "${HOME}/config/apprise.yaml" ]] ; then
  echo "Creating example apprise config ${HOME}/config/apprise.yaml"
  cp /opt/arm/docs/apprise.yaml "${HOME}/config/apprise.yaml"
  chown "${USER}.${USER}" "${HOME}/config/apprise.yaml"
fi
if [[ ! -f "${HOME}/.abcde.conf" ]] ; then
  echo "Creating example abcde config ${HOME}/config/.abcde.conf"
  ln -fs /opt/arm/setup/.abcde.conf "${HOME}/.abcde.conf"
  ln -fs "${HOME}/.abcde.conf" "${HOME}/config"
  chown "${USER}.${USER}" "${HOME}/.abcde.conf"
fi
echo "setting makemkv app-Key"
if ! [[ -z "${MAKEMKV_APP_KEY}" ]] ; then
  echo "app_Key = \"${MAKEMKV_APP_KEY}\"" > "${HOME}/.MakeMKV/settings.conf"
fi

[[ -h /dev/cdrom ]] || ln -sv /dev/sr0 /dev/cdrom

chown -R "${USER}.${USER}"  /home/arm && \
chown -R "${USER}.${USER}"  /dev/sr0 && \
chown -R "${USER}.${USER}"  /dev/sr1 && \
chown -R "${USER}.${USER}"  /dev/sr2 && \
chown -R "${USER}.${USER}"  /dev/sr3 && \
chown -R "${USER}.${USER}"  /dev/sr4 && \
chmod -R 0777 /home/arm

if [[ "${RUN_AS_USER:-true}" == "true" ]] ; then
  exec /usr/sbin/gosu arm "$@"
else
  exec "$@"
fi

