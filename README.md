# StarRupture Dedicated Server (Docker)

## Description
Docker container for hosting a dedicated server for [StarRupture](https://starrupture-game.com/).

## Quick start (Docker)
1. Create a `docker-compose.yml` file from the example below.
2. Start the container using `docker compose up -d` and then monitor the output using `docker compose logs -f`.
3. Forward ports on your router/firewall if hosting for players outside your LAN (see `GAME_PORT`).

## In-game setup
1. Launch StarRupture.
2. Go to **MANAGE SERVER**:
   - Enter the server IP:
     - **WAN/Public IP** for players connecting from the internet
     - **LAN IP** for players on your local network
   - Set the admin password (or set it via `docker-compose.yml`, see below).
3. Click **NEW GAME** and set a session name  
   - Note: the game can be picky about spaces in the **Session Name**.
4. Click **START GAME**.
5. Press **ESC** back to the main menu → **JOIN GAME**.
6. Enter the server IP again and the player password (if set).  
   - Note: the game does not support hostnames yet.

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

- On startup, the container copies `DSSettings.txt` into `/home/steam/starrupture/server` **only if it does not already exist**.

## Important! 🚨 (volume paths changed)
Internal container paths for volume mounts changed.

If you were previously mounting paths like:
- `/starrupture/...`

They must now be:
- `/home/steam/starrupture/...`

So update your `docker-compose.yml` accordingly.

### If SteamCMD gets stuck after updating
If you pull an updated image and SteamCMD loops downloading/verifying the server files, down the container, then:

**Option A (recommended):** temporary wipe/reinstall via env var  
- Set `REMOVE_SERVER_FILES=1` in the `docker-compose.yml` for *one* launch
- Then set it back to `0` (unless you enjoy reinstalling the server files every time)

Your settings files (`DSSettings.txt`, `Password.json`, `PlayerPassword.json`) are backed up into your data folder and restored after the wipe.

**Option B (manual):** delete server files except settings  
In the `server` folder, delete everything **except**:
- `DSSettings.txt`
- `Password.json`
- `PlayerPassword.json`

Then start the container again.

If you deleted the `Password*.json` password files:
- Recreate them via **MANAGE SERVER**, or
- Recreate them using the environment variables `ADMIN_PASSWORD`, `PLAYER_PASSWORD` + `FORCE_CHANGE_*` in `docker-compose.yml`.

## Docker Compose (docker-compose.yml)

### Environment variables
| Variable             | Description | Default |
| :------------------- | :---------- | :-----: |
| TZ                   | Timezone | "UTC" |
| PUID                 | Numeric user id | "1000" |
| PGID                 | Numeric group id | "1000" |
| SKIP_UPDATE          | Skip updating server files | "0" |
| ENABLE_LOG           | Enable server logging | "1" |
| GAME_PORT            | Game port (adjust port mapping if needed) | "7777" |
| REMOVE_PDB           | Remove large debug symbol file (`.pdb` > 2GB) | "1" |
| ADMIN_PASSWORD       | Admin/server manager password (first run, or when forced) | "" |
| PLAYER_PASSWORD      | Player join password (first run, or when forced) | "" |
| FORCE_CHANGE_ADMIN   | Force admin password update (`ADMIN_PASSWORD` required) | "0" |
| FORCE_CHANGE_PLAYER  | Force player password update (`PLAYER_PASSWORD` required) | "0" |
| REMOVE_SERVER_FILES  | Wipe server files to recover from update issues | "0" |
| BACKUP_SETTINGS      | Backup `DSSettings.txt`, `Password.json`, `PlayerPassword.json` on shutdown | "1" |

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
    volumes:
      - /path/to/server:/home/steam/starrupture/server
      - /path/to/data:/home/steam/starrupture/data
      # Optional: store saves inside your data folder:
      - /path/to/data:/home/steam/starrupture/server/StarRupture/Saved
    ports:
      - "7777:7777/udp"
      - "7777:7777/tcp"
    restart: unless-stopped
```

## Directory Structure
```
.
├── data
│   ├── Config
│   ├── Logs
│   ├── server-settings-backup   # Backups of DSSettings.txt and password files
│   └── SaveGames                # Saves (when using the optional Saved volume mapping)
└── server
    ├── Engine
    ├── StarRupture
    └── steamapps
```
## Changelog

* 17 Jan 2026:
  - Adjust backup script to copy backups to timestamped directory so that previous files don't get overwritten.

* 10 Jan 2026:
  - Changed base container from official SteamCMD to a custom image
  - Added support for creating/changing Password.json and PlayerPassword.json via AlienX’s API
  - Added option to remove server files if SteamCMD fails to update
  - Added server settings backup on shutdown (enabled by default)
  - Improved script output