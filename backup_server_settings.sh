#!/bin/bash

set -euo pipefail

DATE=$(date +"%Y%m%d-%H%M%S")
BACKUPDIR=${SETTINGSBACKUP}/${DATE}

if [ ! -d ${BACKUPDIR} ]; then
    mkdir -p ${BACKUPDIR}/Saves
fi

for keep in DSSettings.txt Password.json PlayerPassword.json; do
    if [ -f ${SERVERHOME}/${keep} ]; then
        echo "Backing up ${keep}..."
        cp ${SERVERHOME}/${keep} ${BACKUPDIR}
    fi
done

if [ -d ${SERVERHOME}/StarRupture/Saved ]; then
    echo "Backing up Saves..."
    cp -r ${SERVERHOME}/StarRupture/Saved/* ${BACKUPDIR}/Saves/
fi