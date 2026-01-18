#!/bin/bash

APPID=3809400

# Relative to $SERVERHOME
BINARY=StarRupture/Binaries/Win64/StarRuptureServerEOS-Win64-Shipping.exe
PDB=StarRupture/Binaries/Win64/StarRuptureServerEOS-Win64-Shipping.pdb

OK='✅: \033[1;92m'        # bright green
INFO='➡️: \033[1;94m'      # bright blue
WARN='⚠️: \033[1;93m'      # bright yellow
ERR='❌: \033[1;91m' # bright red
HILITE='👉: \033[38;5;208m' # orange
HILITENOE='\033[38;5;208m' # orange
NC='\033[0m' # Reset

TZ="${TZ:-UTC}"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
SKIP_UPDATE="${SKIP_UPDATE:-0}"
ENABLE_LOG="${ENABLE_LOG:-1}"
GAME_PORT="${GAME_PORT:-7777}"
REMOVE_PDB="${REMOVE_PDB:-1}"
FORCE_ADMIN_CHANGE="${FORCE_ADMIN_CHANGE:-0}"
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

settings=$(cat<<EOF

${HILITE}Please see the README for this container at: https://github.com/RhavinX/starrupture/blob/main/README.md${NC}

${WARN}!! IMPORTANT !!${NC}
${WARN}Internal paths have changed for this container. You will need to update your volume binds in your docker-compose.yml as follows:${NC}

volumes:
      - /path/to/server:${HILITENOE}/home/steam${NC}/starrupture/server
      - /path/to/data:${HILITENOE}/home/steam${NC}/starrupture/data
	  ${WARN}# Bind mount for saves is no longer necessary as saves are copied to data folder automatically.${NC}

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

### FUNCTIONS ###

term_handler() {
	echo -e "${INFO}Shutting down Server${NC}"

	PID=$(pgrep -f "${SERVERHOME}/${BINARY}")
	if [[ -z $PID ]]; then
		echo -e "${WARN}Could not find StarRupture pid. Assuming server is dead...${NC}"
	else
		kill -n 15 $PID
		wait $PID
	fi
	wineserver -k
	sleep 1
	copy_files_to_data
	if [[ "${BACKUP_SETTINGS}" == "1" ]]; then
		snapshot_server_files
	fi
	echo -e "${INFO}Shutdown complete.${NC}"
	exit
}

trap 'term_handler' SIGTERM

install_server() {
	echo -e "${INFO}-> Installing / updating StarRupture dedicated server files in ${SERVERHOME}${NC}"
	gosu steam:steam ./steamcmd.sh +@sSteamCmdForcePlatformType windows +force_install_dir ${SERVERHOME} +login anonymous +app_update ${APPID} validate +quit
}

set_password_files() {
	local adminpassword="$1"
	local playerpassword="$2"
	local json=$(curl -s 'https://starrupture-utilities.com/passwords/' -X POST --data-raw "adminpassword=${adminpassword}&playerpassword=${playerpassword}")
	local adminpassword_encrypted=$(echo "${json}" | jq -r '.adminpassword')
	local playerpassword_encrypted=$(echo "${json}" | jq -r '.playerpassword')
	if [[ -n "${adminpassword_encrypted}" ]]; then
		jq -cn --arg password "${adminpassword_encrypted}" '$ARGS.named' > "${GAMEDATA}/Password.json"
		chown steam:steam "${GAMEDATA}/Password.json"
		echo -e "${OK}Admin: Password.json file created.${NC}";
	else echo -e "${WARN}Admin password is empty, not creating Password.json file.${NC}";
	fi
	if [[ -n "${playerpassword_encrypted}" ]]; then
		jq -cn --arg password "${playerpassword_encrypted}" '$ARGS.named' > "${GAMEDATA}/PlayerPassword.json"
		echo -e "${OK}Game: PlayerPassword.json file created.${NC}";
		chown steam:steam "${GAMEDATA}/PlayerPassword.json"
	else echo -e "${WARN}Player password is empty, not creating PlayerPassword.json file.${NC}";
	fi
}

copy_files_to_data() {
	echo -e "${INFO}Updating files in data folder...${NC}"
	for dir in Config Logs SaveGames; do
		if [[ -d "${SERVERHOME}/StarRupture/Saved/${dir}" ]]; then
			mkdir -p "${GAMEDATA}/${dir}"
			echo -e "${INFO}Copying ${dir}...${NC}"
			cp -a "${SERVERHOME}/StarRupture/Saved/${dir}" "${GAMEDATA}"
		fi
	done
	if [[ -f "${SERVERHOME}/DSSettings.txt" ]]; then
		echo -e "${INFO}Copying DSSettings.txt...${NC}"
		cp -a "${SERVERHOME}/DSSettings.txt" "${GAMEDATA}/DSSettings.txt"
	fi
	if [[ -f "${SERVERHOME}/Password.json" ]]; then
		echo -e "${INFO}Copying Password.json...${NC}"
		cp -a "${SERVERHOME}/Password.json" "${GAMEDATA}/Password.json"
	fi
	if [[ -f "${SERVERHOME}/PlayerPassword.json" ]]; then
		echo -e "${INFO}Copying PlayerPassword.json...${NC}"
		cp -a "${SERVERHOME}/PlayerPassword.json" "${GAMEDATA}/PlayerPassword.json"
	fi
}

copy_files_to_server() {
	echo -e "${INFO}Restoring files from data folder...${NC}"
	for dir in Config Logs SaveGames; do
		if [[ -d "${GAMEDATA}/${dir}" ]]; then
			mkdir -p "${SERVERHOME}/StarRupture/Saved/${dir}"
			echo -e "${INFO}Restoring ${dir}...${NC}"
			cp -a "${GAMEDATA}/${dir}" "${SERVERHOME}/StarRupture/Saved"
		fi
	done
	if [[ -f "${GAMEDATA}/DSSettings.txt" ]]; then
		echo -e "${INFO}Restoring DSSettings.txt...${NC}"
		cp -a "${GAMEDATA}/DSSettings.txt" "${SERVERHOME}/DSSettings.txt"
	fi
	if [[ -f "${GAMEDATA}/Password.json" ]]; then
		echo -e "${INFO}Restoring Password.json...${NC}"
		cp -a "${GAMEDATA}/Password.json" "${SERVERHOME}/Password.json"
	fi
	if [[ -f "${GAMEDATA}/PlayerPassword.json" ]]; then
		echo -e "${INFO}Restoring PlayerPassword.json...${NC}"
		cp -a "${GAMEDATA}/PlayerPassword.json" "${SERVERHOME}/PlayerPassword.json"
	fi
}

snapshot_server_files() {
	local DATE=$(date +"%Y%m%d-%H%M%S")
    local BACKUPDIR=${BACKUP}/${DATE}
	echo -e "${INFO}Creating snapshot of current server files in ${BACKUPDIR}...${NC}"
	if [[ ! -d "${BACKUPDIR}" ]]; then
		mkdir -p "${BACKUPDIR}"
	fi
	for dir in Config Logs SaveGames; do
		if [[ -d "${SERVERHOME}/StarRupture/Saved/${dir}" ]]; then
			mkdir -p "${$BACKUPDIR}/${dir}"
			echo -e "${INFO}Copying ${dir}...${NC}"
			cp -a "${SERVERHOME}/StarRupture/Saved/${dir}/*" "${BACKUPDIR}/${dir}"
		fi
	done

	if [[ -f "${SERVERHOME}/Password.json" ]]; then
		echo -e "${INFO}Copying Password.json...${NC}"
		cp -a "${SERVERHOME}/Password.json" "${BACKUPDIR}/Password.json"
	fi
	if [[ -f "${SERVERHOME}/PlayerPassword.json" ]]; then
		echo -e "${INFO}Copying PlayerPassword.json...${NC}"
		cp -a "${SERVERHOME}/PlayerPassword.json" "${BACKUPDIR}/PlayerPassword.json"
	fi
	chown -R steam:steam "${BACKUPDIR}"
}

remove_server_files() {
	echo -e "${INFO}Removing server files from ${SERVERHOME}...${NC}"
	if [[ -d ${SERVERHOME}/StarRupture ]]; then
		rm -rf ${SERVERHOME}/*
		echo -e "${OK}Server files removed.${NC}"
	else
		echo -e "${ERR}Did not remove server files. Please manually empty the directory.${NC}"
	fi
}

### MAIN ###

firstrun=1
echo -e "${INFO}Starting StarRupture Dedicated Server...${NC}"

if [[ -f "${SERVERHOME}/DSSettings.txt" ]]; then
	firstrun=0
fi

if [[ "${REMOVE_SERVER_FILES}" == "1" ]] && [[ $firstrun -eq 0 ]]; then # Will not execute if first run
	echo -e "${WARN}!{$NC}"
	echo -e "${WARN}Removing existing server files (REMOVE_SERVER_FILES is 1)...${NC}"
	echo -e "${WARN}!{$NC}"
	snapshot_server_files
	remove_server_files
fi

if [[ $firstrun -eq 1 ]]; then
	if [[ -e "${GAMEDATA}/DSSettings.txt" ]]; then
	  echo -e "${INFO}First run detected, found DSSettings.txt in data folder, copying to server...${NC}"
	  cp "${GAMEDATA}/DSSettings.txt" "${SERVERHOME}/DSSettings.txt"
	else 
		echo -e "${HILITE}First run detected, copying fresh DSSettings.txt for later editing.${NC}"
		cp /DSSettings.txt "${SERVERHOME}/DSSettings.txt"
	fi
	echo -e "${INFO}Remember to down the server and adjust DSSettings.txt after creating your game!${NC}"
	chown steam:steam "${SERVERHOME}/DSSettings.txt"
fi

if [[ "${SKIP_UPDATE}" == "0" ]] || [[ ! -f "${SERVERHOME}/${BINARY}" ]]; then # Only install / update if SKIP_UPDATE is 0 or binary is missing
		echo -e "${INFO}Updating or installing server files...${NC}"
        attempt=1
		until [[ -f "${SERVERHOME}/${BINARY}" ]]; do
				echo -e "${HILITE}Attempt #${attempt} to install/update server files...${NC}"
				install_server
				(( attempt++ ))
		done
fi

if [[ "${REMOVE_PDB}" == "1" ]]; then # PDB debug symbol file is >2gb, let's recover that space
	if [[ -f "${SERVERHOME}/${PDB}" ]]; then
		echo -e "${INFO}Removing extremely large debug symbol file...${NC}"
		rm -f "${SERVERHOME}/${PDB}"
	fi
fi

# Grouping: (adminpassword set AND (force change set OR Password.json missing)) OR (playerpassword set AND (force change set OR PlayerPassword.json missing))
if ( [[ -n "${ADMIN_PASSWORD}" ]] && ([[ "${FORCE_ADMIN_CHANGE}" == "1" ]] || [[ ! -f "${GAMEDATA}/Password.json" ]]) ) || ( [[ -n "${PLAYER_PASSWORD}" ]] && ( [[ "${FORCE_PLAYER_CHANGE}" == "1" ]] || [[ ! -f "${GAMEDATA}/PlayerPassword.json" ]] ) ); then
	echo -e "${HILITE}Admin or Player password set, but Password.json or PlayerPassword.json file missing OR Force Change requested, setting passwords...${NC}"
	set_password_files "${ADMIN_PASSWORD}" "${PLAYER_PASSWORD}"
fi

copy_files_to_server

echo -e "${INFO}Server Public IP Address:${NC} ${HILITE}$(curl -s https://api.ipify.org)${NC}"

echo -e "${WARN}Ensure you are forwarding port ${GAME_PORT}/UDP on your router/firewall!${NC}"

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
gosu steam:steam wine "${SERVERHOME}/${BINARY}" "${args[@]}" 2>&1 &
# Gets the PID of the last command
ServerPID=$!
wait $ServerPID