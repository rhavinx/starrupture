#!/bin/bash

OK='\033[1;92m'        # bright green
INFO='\033[1;94m'      # bright blue
WARN='\033[1;93m'      # bright yellow
ERR='\033[1;91m'       # bright red
HILITE='\033[38;5;208m' # orange
NC='\033[0m'

serverhome=/starrupture/server
data=/starrupture/data
appid=3809400

# Relative to $serverhome
# SteamDB Patch list shows the binaries are now this, but in reality it's still the previous files. Not sure why.
#binary=/StarRupture/Binaries/Win64/StarRuptureServerEOS.exe
#pdb=/StarRupture/Binaries/Win64/StarRuptureServerEOS.pdb
binary=/StarRupture/Binaries/Win64/StarRuptureServerEOS-Win64-Shipping.exe
pdb=/StarRupture/Binaries/Win64/StarRuptureServerEOS-Win64-Shipping.pdb

TZ="${TZ:-UTC}"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
SKIP_UPDATE="${SKIP_UPDATE:-0}"
ENABLE_LOG="${ENABLE_LOG:-1}"
GAME_PORT="${GAME_PORT:-7777}"
REMOVE_PDB="${REMOVE_PDB:-1}"

if ! [[ "${PUID}" =~ ^[0-9]+$ ]] || ! [[ "${PGID}" =~ ^[0-9]+$ ]]; then
  echo -e "${ERR}PUID and PGID must be numeric (got PUID='${PUID}', PGID='${PGID}')${NC}"
  exit 1
fi

echo -e "${INFO}Setting timezone to ${TZ}${NC}"
echo "${TZ}" > /etc/timezone 2>&1
ln -snf /usr/share/zoneinfo/"${TZ}" /etc/localtime 2>&1
dpkg-reconfigure -f noninteractive tzdata 2>&1


term_handler() {
	echo -e "${INFO}Shutting down Server${NC}"

	PID=$(pgrep -f "^${serverhome}${binary}")
	if [[ -z $PID ]]; then
		echo -e "${WARN}Could not find StarRupture pid. Assuming server is dead...${NC}"
	else
		kill -n 15 "$PID"
		wait "$PID"
	fi
	wineserver -k
	sleep 1
	exit
}

trap 'term_handler' SIGTERM

install_server() {
	echo -e "${INFO}-> Installing / updating StarRupture dedicated server files in ${serverhome}${NC}"
	gosu steam:steam /usr/bin/steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir "${serverhome}" +login anonymous +app_update "${appid}" validate +quit
}

chown -R "${PUID}:${PGID}" "${serverhome}" "${data}"

if [[ ! -f "${serverhome}/DSSettings.txt" ]]; then
	echo -e "${HILITE}-> This appears to be a first run, so copying DSSettings.txt for later editing.${NC}"
	cp /DSSettings.txt "${serverhome}"/DSSettings.txt
	chown "${PUID}:${PGID}" "${serverhome}/DSSettings.txt"

	# SteamCMD is being weird lately and will not install the app on first run.
	# This takes care of initial installation and should retry on failures until the server binary exists at least
	attempt=1
	until [ -f ${serverhome}${binary} ]; do
        	echo -e "${HILITE}:: Attempt #${attempt} to install server files...${NC}"
	        install_server
	        (( attempt++ ))
	done
elif [[ "${SKIP_UPDATE}" == "0" ]]; then # DSSettings.txt exists, so we can try update the server, if allowed to.
        install_server
fi

if [[ "${REMOVE_PDB}" == "1" ]]; then # PDB debug symbol file is >2gb, let's recover that space
	if [ -f "${serverhome}${pdb}" ]; then
		echo -e "${INFO}Removing extremely large debug symbol file...${NC}"
		rm -f "${serverhome}${pdb}"
	fi
fi

echo -e "${OK}-> Starting StarRupture Dedicated Server${NC}"
if [ -e /tmp/.X0-lock ]; then
   rm -f /tmp/.X0-lock 2>&1
fi

gosu steam:steam wine64 winecfg
sleep 5
Xvfb :0 -screen 0 1280x1024x24 -nolisten tcp &
export DISPLAY=:0.0
export WINEDEBUG=-all

args=()
[[ "${ENABLE_LOG}" == "1" ]] && args+=("-Log")
args+=("-port=${GAME_PORT}")

echo -e "${HILITE}-> Launching StarRupture Dedicated Server Binary${NC}"
gosu steam:steam wine64 "${serverhome}${binary}" "${args[@]}" 2>&1 &

# Gets the PID of the last command
ServerPID=$!
wait $ServerPID
