#!/bin/bash
set -euo pipefail

OK='\033[1;92m'        # bright green
INFO='\033[1;94m'      # bright blue
WARN='\033[1;93m'      # bright yellow
ERR='\033[1;91m'       # bright red
HILITE='\033[38;5;208m' # orange
NC='\033[0m'

serverhome=/starrupture/server
data=/starrupture/data

TZ="${TZ:-UTC}"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
SKIP_UPDATE="${SKIP_UPDATE:-0}"
ENABLE_LOG="${ENABLE_LOG:-1}"
GAME_PORT="${GAME_PORT:-7777}"

echo -e "${INFO}Setting timezone to ${TZ}${NC}"
echo "${TZ}" > /etc/timezone 2>&1 || true
ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime 2>&1 || true
dpkg-reconfigure -f noninteractive tzdata 2>&1 || true

if ! [[ "${PUID}" =~ ^[0-9]+$ ]] || ! [[ "${PGID}" =~ ^[0-9]+$ ]]; then
  echo -e "${ERR}: PUID and PGID must be numeric (got PUID='${PUID}', PGID='${PGID}')${NC}"
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
  echo -e "${INFO}Shutting down Server${NC}"
  PID="$(pgrep -f "^${serverhome}/StarRupture/Binaries/Win64/StarRuptureServerEOS-Win64-Shipping.exe" || true)"
  if [[ -n "${PID}" ]]; then
    kill -n 15 "${PID}" || true
    wait "${PID}" || true
  else
    echo -e "${WARN} not find server PID; assuming it's already stopped.${NC}"
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
  echo -e "${OK}SKIP_UPDATE=1 -> skipping SteamCMD update${NC}"
else
  echo -e "${INFO}Updating/installing StarRupture Dedicated Server files...${NC}"
  gosu steam:steam /usr/bin/steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir "${serverhome}" +login anonymous +app_update 3809400 validate +quit
fi

# Ensure the Saved path exists (this will be a mount to /starrupture/data via compose)
mkdir -p "${serverhome}/StarRupture/Saved"
chown -R "${PUID}:${PGID}" "${serverhome}/StarRupture/Saved"

# Copy DSSettings.txt if it does not exist.
if [[ ! -f "${serverhome}/DSSettings.txt" ]]; then
  echo -e "${HILITE}DSSettings.txt into ${serverhome}.${NC}"
  echo -e "${HILITE}After the server startup completes, shut it down again & edit the DSSettings.txt in ${serverhome}.${NC}"
  cp /DSSettings.txt "${serverhome}/DSSettings.txt"
  chown "${PUID}:${PGID}" "${serverhome}/DSSettings.txt"
else
  echo -e "${HILITE}DSSettings.txt already exists in ${serverhome}, leaving it untouched.${NC}"
fi

echo -e "${INFO}-> Starting StarRupture Dedicated Server${NC}"

rm -f /tmp/.X0-lock 2>/dev/null || true
Xvfb :0 -screen 0 1280x1024x24 -nolisten tcp &
export DISPLAY=:0.0

# Initialize Wine prefix
WINEPREFIX="/home/steam/.wine"
export WINEPREFIX

echo -e "${INFO}Initializing Wine prefix...${NC}"
mkdir -p "${WINEPREFIX}"
chown -R "${PUID}:${PGID}" "${WINEPREFIX}"

# Fast, non-GUI init
timeout 10 gosu steam:steam wine64 wineboot -i || true

args=()
[[ "${ENABLE_LOG}" == "1" ]] && args+=("-Log")
args+=("-port=${GAME_PORT}")

echo -e "${INFO}   serverhome=${serverhome}${NC}"
echo -e "${INFO}   data=${data}${NC}"
echo -e "${INFO}   args: ${args[*]}${NC}"
echo
echo -e "${HILITE}The dedicated server takes a while to start up, please be patient...there will be more output once it starts."

gosu steam:steam wine64 \
  "${serverhome}/StarRupture/Binaries/Win64/StarRuptureServerEOS-Win64-Shipping.exe" \
  "${args[@]}" \
  2>&1 &

# Gets the PID of the last command
ServerPID=$!
wait $ServerPID
