# StarRupture Dedicated Server (Docker)

## Description
Docker container for hosting a dedicated server for [StarRupture](https://starrupture-game.com/).
Currently the game server requires an internet connection.

## 🚨 Important Changes 🚨
If you are an existing user of this container, the way the container works has been changed slightly, and the folder structure has been updated accordingly.
You might want to rename your existing "data" volume and start the container with a new data volume, down the container and then copy your existing files in to the new structure.
Please take note of the updates to `docker-compose.yml` so that you can update yours accordingly.

## Directory Structure
```
.
├── data                     # Volume bind mount
│   ├── Backup               # Timestamped snapshots of DSSettings.txt, password files and saves.
│   ├── Config               # Synced with server folder on container start / shutdown
│   ├── Logs                 # Synced with server folder on container start / shutdown
│   ├── SaveGames            # Synced with server folder on container start / shutdown
│   ├── DSSettings.txt       # Synced with server folder on container start / shutdown
│   ├── Password.json        # Synced with server folder on container start / shutdown
│   └── PlayerPassword.json  # Synced with server folder on container start / shutdown
└── server                   # Volume bind mount, populated via SteamCMD with server files.
    ├── Engine
    ├── StarRupture
    │   └── Saved            # Contents synced with data folder on container start & shutdown
    │       ├── Config
    │       ├── Logs    
    │       └── SaveGames
    ├── steamapps
    ├── DSSettings.txt       # Synced with data folder on container start / shutdown 
    ├── Password.json        # Synced with data folder on container start / shutdown 
    └── Playerpassword.json  # Synced with data folder on container start / shutdown 
```

## Quick start (Docker)
1. Create a `docker-compose.yml` file from the example below.
2. Start the container using `docker compose up -d` and then monitor the output using `docker compose logs -f`.
3. Forward ports on your router/firewall (see `GAME_PORT`).

## In-game setup
1. Launch StarRupture.
2. Go to **MANAGE SERVER**:
   - Enter the server IP:
     - **WAN/Public IP** for players connecting from the internet
     - You currently cannot use the LAN ip due to the way the server networking is configured. Hopefully the devs will fix this.
   - Set the admin password (or set it via `docker-compose.yml`, see below).
3. Click **New Game** and set a session name  
   - Note: Do not use spaces in the **Session Name**.
4. Click **Start Game**.
5. Press **ESC** back to the main menu → **Join Game**.
6. Enter the server IP again and the player password (if set).  
   - Note: the game does not support hostnames yet either.
7. You can disconnect from the game, down the container and edit DSSettings.txt in the data folder to set the server save file to auto start.

## Admin & player passwords (optional)
You can set admin and/or player passwords using environment variables in `docker-compose.yml`.

- On first run, provided the variables `ADMIN_PASSWORD` and/or `PLAYER_PASSWORD` are set, the container will create:
  - `Password.json` (admin)
  - `PlayerPassword.json` (players)
- The password variables are only used to *create these files* unless you force a change. You can remove the variables once your files exist.
- To change passwords for an existing setup:
  - Set `ADMIN_PASSWORD` and/or `PLAYER_PASSWORD`
  - Set the corresponding `FORCE_CHANGE_ADMIN=1` and/or `FORCE_CHANGE_PLAYER=1`, or delete the corresponding json files.
  - After the files are updated, remove the `ADMIN_PASSWORD` and `PLAYER_PASSWORD` variables, along with the `FORCE_CHANGE_*` variables.

This feature requires internet access (it calls AlienX’s password API at https://starrupture-utilities.com/).

## DSSettings.txt
This container includes `DSSettings.txt`. Read about it here:
[StarRupture Unofficial Wiki](https://starrupture.just4dns.co.uk/dedicated-server/configuration)

- On initial startup, the container copies a fresh `DSSettings.txt` into `/home/steam/starrupture/server`.
The file will then be copied back to the `data` volume folder on server shutdown.

You can also create the file yourself first in the `data` volume folder, this file will be copied to the container instead of the fresh copy.

The initial contents are as follows:
```json
{
  "SessionName": "MySaveGame",
  "SaveGameInterval": "300",
  "StartNewGame": "false",
  "LoadSavedGame": "false",
  "SaveGameName": "AutoSave0.sav"
}
```

Use the 'MANAGE GAME' option inside the game to create your first game:

  1. Enter your public IP address (The container logs will report your public IP just before launching the server). If the connection is successul, you will be prompted to set a password to use for the Manage Server function. If the connection graphic just spins, check that you are correctly forwarding the port on your router.
  2. Set a game password if desired using the yellow 'Change Password' button.
  3. Click "New Game", provide a session name (no spaces), and click the (now yellow) Start Game button. Wait until you get a popup message that says the session is running, then click the OK button. Previously there was a bug where sometimes this popup would not appear.
  4. Connect to your server via "Join Game" from the main game menu and use your public IP. Hostnames are not supported yet. Select a character, then join the game.
  5. Once you are in the game, you can disconnect from the server, then down the container. There should now be a saved session in your data volume.
  6. Edit the DSSettings.txt in the data folder and set it to load your game with the correct session name.
  7. Up your container again.

#### Updated DSSettings.txt
```json
{
  "SessionName": "SessionNameYouChose",
  "SaveGameInterval": "300",
  "StartNewGame": "false",
  "LoadSavedGame": "true",
  "SaveGameName": "AutoSave0.sav"
}
```

## Important! 🚨 (volume paths changed)
Internal container paths for volume mounts changed. Also the local mount for the saved files has changed.

If you were previously mounting paths like:
- `/starrupture/...`

They must now be:
- `/home/steam/starrupture/...`

So please update your `docker-compose.yml` accordingly.

### If SteamCMD gets stuck after updating
If you pull an updated image and SteamCMD loops downloading/verifying the server files, down the container, then:

**Option A (recommended):** temporary wipe/reinstall via env var  
- Set `REMOVE_SERVER_FILES=1` in the `docker-compose.yml` for **one** launch
- Then set it back to `0` (unless you enjoy reinstalling the server files every time)

Your settings files (`DSSettings.txt`, `Password.json`, `PlayerPassword.json`) and **saves** are backed up into your settings backup folder.

**Option B (manual):** manually delete the contents of the server volume.
In the `server` folder, delete everything. Existing settings will be copied from your data volume.
Start the container again.

If you lost the `*Password.json` password files:
- Recreate them via **MANAGE SERVER**, or
- Recreate them using the environment variables `ADMIN_PASSWORD`, `PLAYER_PASSWORD` + `FORCE_CHANGE_*` in `docker-compose.yml`.

## Docker Compose (docker-compose.yml)

### Environment variables
| Variable             | Description | Default |
| :------------------- | :---------- | :-----: |
| TZ                   | Timezone | "UTC" |
| PUID                 | Numeric user id | "1000" |
| PGID                 | Numeric group id | "1000" |
| SKIP_UPDATE          | Skip updating server files - the update check can take a while and may make container start up much slower. | "0" |
| ENABLE_LOG           | Enable server logging | "1" |
| GAME_PORT            | Game port (adjust port mapping if needed) | "7777" |
| REMOVE_PDB           | Remove large debug symbol file (`.pdb` > 2GB) | "1" |
| ADMIN_PASSWORD       | Admin/server manager password (first run, or when forced) | "" |
| PLAYER_PASSWORD      | Player join password (first run, or when forced) | "" |
| FORCE_CHANGE_ADMIN   | Force admin password update (`ADMIN_PASSWORD` required) | "0" |
| FORCE_CHANGE_PLAYER  | Force player password update (`PLAYER_PASSWORD` required) | "0" |
| REMOVE_SERVER_FILES  | Wipe server files to recover from update issues | "0" |
| BACKUP_SETTINGS      | Backup `DSSettings.txt`, `Password.json`, `PlayerPassword.json` and saved games on shutdown | "1" |

```yml
services:
  starrupture:
    image: rhavinx/starrupture:latest
    container_name: starrupture
    environment:
      TZ: "UTC"
      SKIP_UPDATE: "0"
      ENABLE_LOG: "1"
      GAME_PORT: "7777"
      # ADMIN_PASSWORD: ""
      # PLAYER_PASSWORD: ""
      # FORCE_CHANGE_ADMIN: "0"
      # FORCE_CHANGE_PLAYER: "0"
      # REMOVE_SERVER_FILES: "0"
      # BACKUP_SETTINGS: "1"
    volumes: # Internal Volume Paths have changed - prefixed with /home/steam
      - /path/to/server:/home/steam/starrupture/server
      - /path/to/data:/home/steam/starrupture/data
      # The saves bind mount has been removed. Save files are now copied to the data folder on server shutdown and transferred back on container start.
    ports:
      - "7777:7777/udp"
      - "7777:7777/tcp"
    restart: unless-stopped
```

## Changelog

* 17 Jan 2026:
  - Refactor the container structure.
  - Settings and saves now live in the data folder and will be transferred to the correct locations within the container on startup and synced back on server shutdown.
  - Change wine64 call to wine as it is no longer required due to the release of Wine 11 stable.
  - Changed DSSettings.txt for better first time use and added info to README.

* 10 Jan 2026:
  - Changed base container from official SteamCMD to a custom image
  - Added support for creating/changing Password.json and PlayerPassword.json via AlienX’s API
  - Added option to remove server files if SteamCMD fails to update
  - Added server settings backup on shutdown (enabled by default)
  - Improved script output
