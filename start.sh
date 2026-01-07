#!/bin/bash
set -euo pipefail

serverhome=/starrupture/server
data=/starrupture/data

TZ="${TZ:-UTC}"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
SKIP_UPDATE="${SKIP_UPDATE:-0}"
ENABLE_LOG="${ENABLE_LOG:-1}"
GAME_PORT="${GAME_PORT:-7777}"

echo "Setting timezone to ${TZ}"
echo "${TZ}" > /etc/timezone 2>&1 || true
ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime 2>&1 || true
dpkg-reconfigure -f noninteractive tzdata 2>&1 || true

if ! [[ "${PUID}" =~ ^[0-9]+$ ]] || ! [[ "${PGID}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: PUID and PGID must be numeric (got PUID='${PUID}', PGID='${PGID}')"
  exit 1
fi

if getent group steam >/dev/null; then
  groupmod -o -g "${PGID}" steam
else
  groupadd -o -g "${PGID}" steam
fi

if id steam >/dev/null 2>&1; then
  usermod -o -u "${PUID}" -g "${PGID}" steam
else
  useradd -o -u "${PUID}" -g "${PGID}" -ms /bin/bash steam
fi

mkdir -p "${serverhome}" "${data}"
chown -R "${PUID}:${PGID}" "${serverhome}" "${data}"

term_handler() {
  echo "Shutting down Server"
  PID="$(pgrep -f "^${serverhome}/StarRupture/Binaries/Win64/StarRuptureServerEOS-Win64-Shipping.exe" || true)"
  if [[ -n "${PID}" ]]; then
    kill -n 15 "${PID}" || true
    wait "${PID}" || true
  else
    echo "Could not find server PID; assuming it's already stopped."
  fi
  wineserver -k || true
  sleep 1
  exit 0
}
trap 'term_handler' SIGTERM SIGINT

export HOME=/home/steam
export WINEDEBUG=-all

echo
if [[ "${SKIP_UPDATE}" == "1" ]]; then
  echo "SKIP_UPDATE=1 -> skipping SteamCMD update"
else
  echo "Updating/installing StarRupture Dedicated Server files..."
  gosu steam:steam /usr/bin/steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir "${serverhome}" +login anonymous +app_update 3809400 validate +quit
fi

# Ensure the Saved path exists (this will be a mount to /starrupture/data via compose)
mkdir -p "${serverhome}/StarRupture/Saved"
chown -R "${PUID}:${PGID}" "${serverhome}/StarRupture/Saved"

echo "-> Starting StarRupture Dedicated Server"

rm -f /tmp/.X0-lock 2>/dev/null || true
Xvfb :0 -screen 0 1280x1024x24 -nolisten tcp &
export DISPLAY=:0.0

# Initialize / validate Wine prefix
WINEPREFIX="/home/steam/.wine"
export WINEPREFIX

prefix_ok() {
  [[ -d "${WINEPREFIX}" ]] &&
  [[ -d "${WINEPREFIX}/dosdevices" ]] &&
  [[ -f "${WINEPREFIX}/system.reg" ]] &&
  [[ -f "${WINEPREFIX}/user.reg" ]] &&
  [[ -f "${WINEPREFIX}/userdef.reg" ]] &&
  [[ -d "${WINEPREFIX}/drive_c/windows" ]]
}

if prefix_ok; then
  echo "Wine prefix looks healthy at ${WINEPREFIX} (skipping init)"
else
  echo "Wine prefix missing or looks broken; recreating at ${WINEPREFIX}"
  rm -rf "${WINEPREFIX}"
  mkdir -p "${WINEPREFIX}"
  chown -R "${PUID}:${PGID}" "${WINEPREFIX}" || true

  # Fast, non-GUI init
  timeout 30 gosu steam:steam wine64 wineboot -i || true
fi

args=()
[[ "${ENABLE_LOG}" == "1" ]] && args+=("-Log")
args+=("-port=${GAME_PORT}")

echo "   serverhome=${serverhome}"
echo "   data=${data}"
echo "   args: ${args[*]}"

gosu steam:steam wine64 \
  "${serverhome}/StarRupture/Binaries/Win64/StarRuptureServerEOS-Win64-Shipping.exe" \
  "${args[@]}" \
  2>&1 &

# Gets the PID of the last command
ServerPID=$!
wait $ServerPID
