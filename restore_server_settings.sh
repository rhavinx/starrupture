#!/bin/bash

# This is only called during server files wipe.

set -euo pipefail

latest_backup=$(ls -1dt "${SETTINGSBACKUP}"/*/ | head -n 1)

if [[ -z "$latest_backup" ]]; then
    echo "No backups found in ${SETTINGSBACKUP}"
    echo "Unable to restore server settings."
    exit 1
fi

echo "Restoring from backup: $latest_backup"

for restore in DSSettings.txt Password.json PlayerPassword.json; do
    if [[ -f "${latest_backup}/${restore}" ]]; then
        echo "Restoring ${restore}..."
        cp "${latest_backup}/${restore}" "${SERVERHOME}/"
    fi
done

if [[ -d "${latest_backup}/Saves" ]]; then
    echo "Restoring Saves..."
    mkdir -p "${SERVERHOME}/StarRupture/Saved"
    cp -r "${latest_backup}/Saves/"* "${SERVERHOME}/StarRupture/Saved/"
fi