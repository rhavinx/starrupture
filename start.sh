#!/bin/bash

appid=3809400

# Relative to $serverhome
binary=StarRupture/Binaries/Win64/StarRuptureServerEOS-Win64-Shipping.exe
pdb=StarRupture/Binaries/Win64/StarRuptureServerEOS-Win64-Shipping.pdb

OK='✅: \033[1;92m'        # bright green
INFO='➡️: \033[1;94m'      # bright blue
WARN='⚠️: \033[1;93m'      # bright yellow
ERR='❌: \033[1;91m' # bright red
HILITE='👉: \033[38;5;208m' # orange
NC='\033[0m' # Reset

TZ="${TZ:-UTC}"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
SKIP_UPDATE="${SKIP_UPDATE:-0}"
ENABLE_LOG="${ENABLE_LOG:-1}"
GAME_PORT="${GAME_PORT:-7777}"
REMOVE_PDB="${REMOVE_PDB:-1}"
ADMIN_PASSWORD="${ADMIN_PASSWORD}"
FORCE_ADMIN_CHANGE="${FORCE_ADMIN_CHANGE:-0}"
PLAYER_PASSWORD="${PLAYER_PASSWORD}"
FORCE_PLAYER_CHANGE="${FORCE_PLAYER_CHANGE:-0}"
REMOVE_SERVER_FILES="${REMOVE_SERVER_FILES:-0}"
BACKUP_SETTINGS="${BACKUP_SETTINGS:-1}"

if ! [[ "${PUID}" =~ ^[0-9]+$ ]] || ! [[ "${PGID}" =~ ^[0-9]+$ ]]; then
  echo -e "${ERR}PUID and PGID must be numeric (got PUID='${PUID}', PGID='${PGID}')${NC}"
  exit 1
fi

# This should update the PUID and GUID for the steam user if it is changed by the compose
if getent group steam >/dev/null; then
  groupmod -o -g "${PGID}" steam >/dev/null 2>&1
else
  groupadd -o -g "${PGID}" steam >/dev/null 2>&1
fi

if id steam >/dev/null 2>&1; then
  usermod -o -u "${PUID}" -g "${PGID}" steam >/dev/null 2>&1
else
  useradd -o -u "${PUID}" -g "${PGID}" -ms /bin/bash steam >/dev/null 2>&1
fi

# Update ownership of folders
chown -R steam:steam "${SERVERHOME}"
chown -R steam:steam "${GAMEDATA}"

chmod +x /backup_server_settings.sh
chmod +x /restore_server_settings.sh
chmod +x /remove_server_files.sh

settings=$(cat<<EOF

${HILITE}Please see the README for this container at: https://github.com/RhavinX/starrupture/blob/main/README.md${NC}

${WARN}!! IMPORTANT !!${NC}
${WARN}Internal paths have changed for this container. You will need to update your volume binds in your docker-compose.yml as follows:${NC}

volumes:
      - /path/to/server:${HILITE}/home/steam${NC}/starrupture/server
      - /path/to/data:${HILITE}/home/steam${NC}/starrupture/data
      - ${HILITE}/path/to/data/Saved{$NC}:${HILITE}/home/steam[$NC}/starrupture/server/StarRupture4/Saved ${INFO}# Optional: store saves inside your data folder, otherwise use a separate volume for saves${NC}

Container Settings:
-----------------
 TZ:                      ${INFO}${TZ}${NC}
 PUID:                    ${INFO}${PUID}${NC}
 PGID:                    ${INFO}${PGID}${NC}
 SKIP_UPDATE:             $(if [[ "${SKIP_UPDATE}" == "1" ]]; then echo -e "${WARN}1 WARNING: Server files will not update${NC}"; else echo -e "${INFO}0${NC}"; fi)
 REMOVE_PDB:              $(if [[ "${REMOVE_PDB}" == "0" ]]; then echo -e "${WARN}0 WARNING: PDB file is +2gb and is not necessary unless you need to debug the server binary.${NC}"; else echo -e "${INFO}1${NC}"; fi)
 REMOVE_SERVER_FILES:     $(if [[ "${REMOVE_SERVER_FILES}" == "1" ]]; then echo -e "${WARN}1${NC} ${HILITE}!! UNSET FOR NEXT LAUNCH !!${NC}"; else echo -e "${INFO}0${NC}"; fi)
 BACKUP_SETTINGS:         $(if [[ "${BACKUP_SETTINGS}" == "0" ]]; then echo -e "${WARN}0 WARNING: Server settings and saves will not be backed up on shutdown.${NC}"; else echo -e "${INFO}1${NC}"; fi)
 SERVERHOME:              ${INFO}${SERVERHOME}${NC}
 GAMEDATA:                ${INFO}${GAMEDATA}${NC}
 SAVEDGAMES:              ${INFO}${SAVEDGAMES}${NC}

Server Settings:
----------------
 ENABLE_LOG:              ${INFO}${ENABLE_LOG}${NC}
 GAME_PORT:               ${INFO}${GAME_PORT}${NC}
 ADMIN_PASSWORD:          $(if [[ -n "${ADMIN_PASSWORD}" ]]; then echo -e "${HILITE}SET${NC}"; else echo -e "${INFO}NOT SET${NC}"; fi) $(if [[ "${FORCE_ADMIN_CHANGE}" == "1" ]]; then echo -e "${WARN}FORCED_ADMIN_CHANGE: 1${NC}"; fi)
 PLAYER_PASSWORD:         $(if [[ -n "${PLAYER_PASSWORD}" ]]; then echo -e "${HILITE}SET${NC}"; else echo -e "${INFO}NOT SET${NC}"; fi) $(if [[ "${FORCE_PLAYER_CHANGE}" == "1" ]]; then echo -e "${WARN}FORCE_PLAYER_CHANGE: 1${NC}"; fi)

EOF
)
echo -e "${settings}"

echo "${TZ}" > /etc/timezone 2>&1
ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime 2>&1
dpkg-reconfigure -f noninteractive tzdata 2>&1

term_handler() {
	echo -e "${INFO}Shutting down Server${NC}"

	PID=$(pgrep -f "^${SERVERHOME}/${binary}")
	if [[ -z $PID ]]; then
		echo -e "${WARN}Could not find StarRupture pid. Assuming server is dead...${NC}"
	else
		kill -n 15 "$PID"
		wait "$PID"
	fi
	wineserver -k
	sleep 1
	if [[ "${BACKUP_SETTINGS}" == "1" ]]; then
		gosu steam:steam /bin/bash /backup_server_settings.sh
	fi
	exit
}

trap 'term_handler' SIGTERM

install_server() {
	echo -e "${INFO}-> Installing / updating StarRupture dedicated server files in ${SERVERHOME}${NC}"
	gosu steam:steam ./steamcmd.sh +@sSteamCmdForcePlatformType windows +force_install_dir ${SERVERHOME} +login anonymous +app_update ${appid} validate +quit
}

set_password_files() {
	local adminpassword="$1"
	local playerpassword="$2"
	local json=$(curl -s 'https://starrupture-utilities.com/passwords/' -X POST --data-raw "adminpassword=${adminpassword}&playerpassword=${playerpassword}")
	local adminpassword_encrypted=$(echo "${json}" | jq -r '.adminpassword')
	local playerpassword_encrypted=$(echo "${json}" | jq -r '.playerpassword')
	if [[ -n "${adminpassword_encrypted}" ]]; then
		jq -cn --arg password "${adminpassword_encrypted}" '$ARGS.named' > "${SERVERHOME}/Password.json"
		chown steam:steam "${SERVERHOME}/Password.json"
		echo -e "${OK}Admin: Password.json file created.${NC}";
	else echo -e "${WARN}Admin password is empty, not creating Password.json file.${NC}";
	fi
	if [[ -n "${playerpassword_encrypted}" ]]; then
		jq -cn --arg password "${playerpassword_encrypted}" '$ARGS.named' > "${SERVERHOME}/PlayerPassword.json"
		echo -e "${OK}Game: PlayerPassword.json file created.${NC}";
		chown steam:steam "${SERVERHOME}/PlayerPassword.json"
	else echo -e "${WARN}Player password is empty, not creating PlayerPassword.json file.${NC}";
	fi
}

firstrun=1
echo -e "${INFO}Starting StarRupture Dedicated Server...${NC}"

if [[ -f ${SERVERHOME}/DSSettings.txt ]]; then
	firstrun=0
fi

if [[ "${REMOVE_SERVER_FILES}" == "1" ]] && [[ $firstrun -eq 0 ]]; then # Will not execute if first run
	echo -e "${WARN}!{$NC}"
	echo -e "${WARN}!{$NC}"
	echo -e "${WARN}!{$NC}"
	echo -e "${WARN}Removing existing server files (REMOVE_SERVER_FILES is 1)...${NC}"
	echo -e "${WARN}!{$NC}"
	echo -e "${WARN}!{$NC}"
	echo -e "${WARN}!{$NC}"
	gosu steam:steam /bin/bash /backup_server_settings.sh
	/bin/bash /remove_server_files.sh
	gosu steam:steam /bin/bash /restore_server_settings.sh
fi

if [[ $firstrun -eq 1 ]]; then
	echo -e "${HILITE}First Run, copying DSSettings.txt for later editing.${NC}"
	cp /DSSettings.txt "${SERVERHOME}/DSSettings.txt"
	chown steam:steam "${SERVERHOME}/DSSettings.txt"

	# SteamCMD is being weird lately and will not install the app on first run.
	# This takes care of initial installation and should retry on failures until the server binary exists
	attempt=1
	until [[ -f "${SERVERHOME}/${binary}" ]]; do
        	echo -e "${HILITE}Attempt #${attempt} to install server files...${NC}"
	        install_server
	        (( attempt++ ))
	done

	# Create the password files
	if [[ -n "${ADMIN_PASSWORD}" ]] || [[ -n "${PLAYER_PASSWORD}" ]]; then
		echo -e "${INFO}Creating password files...${NC}"
		set_password_files "${ADMIN_PASSWORD}" "${PLAYER_PASSWORD}"
	else echo -e "${WARN}No admin or player password set, remember to manually set passwords using the in-game server manager!${NC}"
	fi

elif [[ "${SKIP_UPDATE}" == "0" ]] || [[ ! -f "${SERVERHOME}/${binary}" ]]; then # DSSettings.txt exists or the binary doesn't exist, so we can try update if not skipping, or install the server
		echo -e "${INFO}Updating server files (SKIP_UPDATE is 0)...${NC}"
        install_server
fi

if [[ "${REMOVE_PDB}" == "1" ]]; then # PDB debug symbol file is >2gb, let's recover that space
	if [[ -f "${SERVERHOME}/${pdb}" ]]; then
		echo -e "${INFO}Removing extremely large debug symbol file...${NC}"
		rm -f "${SERVERHOME}/${pdb}"
	fi
fi

# Grouping: (adminpassword set AND (force change set OR Password.json missing)) OR (playerpassword set AND (force change set OR PlayerPassword.json missing))
if ( [[ -n "${ADMIN_PASSWORD}" ]] && ([[ "${FORCE_ADMIN_CHANGE}" == "1" ]] || [[ ! -f "${SERVERHOME}/Password.json" ]]) ) || ( [[ -n "${PLAYER_PASSWORD}" ]] && ( [[ "${FORCE_PLAYER_CHANGE}" == "1" ]] || [[ ! -f "${SERVERHOME}/PlayerPassword.json" ]] ) ); then
	echo -e "${HILITE}Admin or Player password set, but Password.json or PlayerPassword.json file missing OR Force Change requested, setting passwords...${NC}"
	set_password_files "${ADMIN_PASSWORD}" "${PLAYER_PASSWORD}"
fi

echo -e "${INFO}Initializing Wine...${NC}"
if [[ -e /tmp/.X0-lock ]]; then
   rm -f /tmp/.X0-lock 2>&1
fi

gosu steam:steam wine winecfg
sleep 5
Xvfb :0 -screen 0 1280x1024x24 -nolisten tcp &
export DISPLAY=:0.0
export WINEDEBUG=-all

args=()
[[ "${ENABLE_LOG}" == "1" ]] && args+=("-Log")
args+=("-port=${GAME_PORT}")

echo -e "${INFO}Launching StarRupture Dedicated Server Binary${NC}"
gosu steam:steam wine "${SERVERHOME}/${binary}" "${args[@]}" 2>&1 &

# Gets the PID of the last command
ServerPID=$!
wait $ServerPID