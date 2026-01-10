#!/bin/bash

if [ ! -d ${SETTINGSBACKUP} ]; then
    mkdir -p ${SETTINGSBACKUP}
fi

for keep in DSSettings.txt Password.json PlayerPassword.json; do
    if [ -f ${SERVERHOME}/${keep} ]; then
        echo "Backing up ${keep}..."
        cp ${SERVERHOME}/${keep} ${SETTINGSBACKUP}
    fi
done
