# StarRupture Dedicated Server (Docker)

## Description
Docker container for hosting a dedicated server for [StarRupture](https://starrupture-game.com/).
Currently the game server requires an internet connection.

The container has been updated to mitigate a vulnerability in the server manager.
Accessing the in-game server manager is no longer possible. You will need to create or autoload your save games via `DSSettings.txt`. See [Quick Start](#quick-start-docker) below.

See [https://wiki.starrupture-utilities.com/en/dedicated-server/Vulnerability-Announcement](https://wiki.starrupture-utilities.com/en/dedicated-server/Vulnerability-Announcement)

## ⚠️ DISABLE TCP ON YOUR ROUTER FORWARD RULE FOR THE GAME PORT (default 7777). It must be UDP only ⚠️
You can use AlienX's [port checker](https://starrupture-utilities.com/port_check/) to confirm that your container is safe.

## Container data life cycle
Initial container start -> "data" volume is empty, new files are created in live "server" volume.

:Loop
Container shutdown -> Live data is copied to the "data" volume, backup is also created if BACKUP_SETTINGS is 1
Container start (subsequent launches) -> Files in "data" volume folder is copied to live "server" volume (overwriting existing).
Goto Loop

If you modify "data" files (Specifically the files mentioned in the Directory Structure diagram below) in the "server" volume, they will be overwritten the next time the server starts.

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

## <a name="quick-start-docker">Quick Start (Docker)</a>
1. Create a `docker-compose.yml` file from the example below.
2. Start the container using `docker compose up -d` and then monitor the output using `docker compose logs -f`.
3. Forward ports on your router/firewall (see `GAME_PORT`). Forward UDP only.
4. The initial `DSSettings.txt` is set up to create a new game. If you wish to change the Savegame name from the container default of "MySaveGame", then down the container and modify the new `DSSettings.txt` and bring the container up again.

## In-game setup
See [https://wiki.starrupture-utilities.com/en/dedicated-server/configuration](https://wiki.starrupture-utilities.com/en/dedicated-server/configuration)

1. Launch the StarRupture game client.
2. Join your server with your WAN IP (Your WAN ip should be reported in the container logs, assuming api.ipify.org is not blocked by your network level ad blocking system if you have one, like adguard or pihole)
3. Press ESC and click the Save button in the menu. This will notify the server to write the save file.
4. Disconnect from the server.
5. Down the container, then modify `DSSettings.txt` located in your data volume and change:
FROM:
```
"StartNewGame": "true",
"LoadSavedGame": "false"
```

TO:
```
"StartNewGame": "false",
"LoadSavedGame": "true"
```
6. Bring up the container and play your game.

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

This feature requires internet access - it calls AlienX’s password API at [https://starrupture-utilities.com/passwords/](https://starrupture-utilities.com/passwords/).
You can also manually create these files via the above link if you prefer.

## DSSettings.txt
This container includes `DSSettings.txt`. Read about it here:
[StarRupture Unofficial Wiki](https://starrupture.just4dns.co.uk/dedicated-server/configuration)

- On initial startup, the container copies a fresh `DSSettings.txt` into `/home/steam/starrupture/server`.
The file will then be copied back to the `data` volume folder on server shutdown.

You can also create the file yourself first in the `data` volume folder, this file will be copied to the container instead of the fresh copy.

The only way to create a new game now is via the `DSSettings.txt`. See the [Quick Start](#quick-start-docker).

The initial contents are as follows:
```json
{
  "SessionName": "MySaveGame",
  "SaveGameInterval": "300",
  "StartNewGame": "true",
  "LoadSavedGame": "false",
  "SaveGameName": "AutoSave0.sav"
}
```

#### DSSettings.txt for an existing savegame
```json
{
  "SessionName": "SessionNameYouChose",
  "SaveGameInterval": "300",
  "StartNewGame": "false",
  "LoadSavedGame": "true",
  "SaveGameName": "AutoSave0.sav"
}
```

### If SteamCMD gets stuck after updating
If you pull an updated image and SteamCMD loops downloading/verifying the server files, down the container, then:

**Option A (recommended):** temporary wipe/reinstall via env var  
- Set `REMOVE_SERVER_FILES=1` in the `docker-compose.yml` for **one** launch
- Then set it back to `0` for the next launch (unless you enjoy reinstalling the server files every time)

Your settings files (`DSSettings.txt`, `Password.json`, `PlayerPassword.json`) and **saves** are backed up into your settings backup folder.

**Option B (manual):** manually delete the contents of the server volume.
In the `server` folder, delete everything. Existing settings will be copied from your data volume.
Start the container again.

If you lost the `*Password.json` password files:
- Recreate them using the environment variables `ADMIN_PASSWORD`, `PLAYER_PASSWORD` + `FORCE_CHANGE_*` in `docker-compose.yml`, or use [https://starrupture-utilities.com/passwords/](https://starrupture-utilities.com/passwords/)

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
| BACKUP_SETTINGS      | Backup settings and saved games on shutdown | "1" |

```yml
services:
  starrupture:
    image: rhavinx/starrupture:latest
    #image: ghcr.io/rhavinx/starrupture:latest # Alternate location
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
    volumes:
      - /path/to/server:/home/steam/starrupture/server
      - /path/to/data:/home/steam/starrupture/data
    ports:
      - "7777:7777/udp"
      # - "7777:7777/tcp" # Removed to mitigate vulnerability
    restart: unless-stopped
```

## Changelog
* 14 Feb 2026:
  - Remove old warnings from readme and start.sh

* 8 Feb 2026:
  - Changes to mitigate: https://wiki.starrupture-utilities.com/en/dedicated-server/Vulnerability-Announcement
  - The in-game server manager is now disabled. All configuration must be done via DSSettings.txt.
  
* 19 Jan 2026:
  - Fixed issue with settings backup.
  - Fixed issue with server updating via steamcmd. 🤦‍♂️
  + Fix Saved folder ownership in case it changes to root.

* 18 Jan 2026:
  - Change ownership of backup directory.
  - Re-arrange image sources, using teejo75/steamcmd-wine as base.
  - Automate image build and publish to both docker and github (ghcr.io).
  - Image will update automatically on the 1st of every month to account for security updates.
  - Sorry about all the major changes that have messed with paths and such. The paths and container structure should remain stable for the foreseeable future.

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