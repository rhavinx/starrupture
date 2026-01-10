#!/bin/bash

for restore in DSSettings.txt Password.json PlayerPassword.json; do
    if [ -f ${SETTINGSBACKUP}/${restore} ]; then
        echo "Restoring ${restore} to ${SERVERHOME}..."
        cp ${SETTINGSBACKUP}/${restore} ${SERVERHOME}
    fi
done